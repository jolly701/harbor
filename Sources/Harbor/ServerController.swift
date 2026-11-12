import AppKit
import Foundation

@MainActor
final class ServerController: ObservableObject {
    static let shared = ServerController()

    @Published private(set) var mode: HarborMode = .loggedOut
    @Published private(set) var statusLine = L10n.loggedOut
    @Published private(set) var isLoggedIn = false
    @Published private(set) var account: GitHubAccount?
    @Published private(set) var port: Int?
    @Published private(set) var isStarting = false
    @Published private(set) var copilotUsage: CopilotUsage?
    @Published private(set) var usageLastUpdated: Date?
    @Published private(set) var usageError: String?
    @Published private(set) var isRefreshingUsage = false

    private var serverProcess: Process?
    private var serverLifetimePipe: Pipe?
    private var preservedFailure: FailureNotice?
    private var accountToken: String?
    private var isLoadingAccount = false
    private var nextAccountAttempt = Date.distantPast
    private var nextUsageAttempt = Date.distantPast
    private var usagePort: Int?
    private var usageRequestID = UUID()
    private var timer: Timer?

    private init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    var canStart: Bool {
        isLoggedIn && mode == .stopped && !isStarting
    }

    var serviceBaseURL: String? {
        port.map(HarborPort.serviceBaseURL(port:))
    }

    var openAIBaseURL: String? {
        port.map(HarborPort.openAIBaseURL(port:))
    }

    var canRefreshUsage: Bool {
        mode == .running && port != nil
    }

    var canStop: Bool {
        serverProcess?.isRunning == true
    }

    var hasFailure: Bool {
        preservedFailure != nil
    }

    func noteLoginFailed() {
        preservedFailure = .login
        statusLine = L10n.loginFailed
    }

    func noteStartFailed(_ message: String) {
        preservedFailure = .start(message)
        statusLine = message
    }

    func refresh() {
        let loggedIn = HarborPaths.hasToken
        isLoggedIn = loggedIn
        if loggedIn {
            loadAccountIfNeeded()
        } else {
            account = nil
            accountToken = nil
        }
        let ownsServer = serverProcess?.isRunning == true
        if ownsServer, let port, !HarborPort.listenerPIDs(port: port).isEmpty {
            mode = .running
            isStarting = false
            preservedFailure = nil
            statusLine = port == HarborPort.preferred
                ? L10n.running
                : L10n.runningFallback(preferred: HarborPort.preferred, port: port)
        } else if ownsServer || isStarting {
            mode = .stopped
            statusLine = L10n.starting
        } else if !loggedIn {
            mode = .loggedOut
            if preservedFailure == .login {
                statusLine = L10n.loginFailed
            } else {
                preservedFailure = nil
                statusLine = L10n.loggedOut
            }
        } else {
            port = nil
            mode = .stopped
            if case .start(let message) = preservedFailure {
                statusLine = message
            } else {
                preservedFailure = nil
                statusLine = L10n.loggedInStopped
            }
        }
        if mode == .running {
            refreshUsageIfNeeded()
        } else {
            clearUsage()
        }
    }

    func refreshUsage() {
        guard canRefreshUsage, let port, !isRefreshingUsage else { return }
        nextUsageAttempt = Date().addingTimeInterval(300)
        loadUsage(port: port)
    }

    private func refreshUsageIfNeeded() {
        guard let port else { return }
        if usagePort != port {
            clearUsage()
            usagePort = port
        }
        guard !isRefreshingUsage, Date() >= nextUsageAttempt else { return }
        nextUsageAttempt = Date().addingTimeInterval(300)
        loadUsage(port: port)
    }

    private func loadUsage(port: Int) {
        let requestID = UUID()
        usageRequestID = requestID
        usagePort = port
        isRefreshingUsage = true
        usageError = nil
        Task {
            do {
                let result = try await CopilotUsage.fetch(port: port)
                guard usageRequestID == requestID, mode == .running, self.port == port else { return }
                copilotUsage = result
                usageLastUpdated = Date()
                usageError = nil
            } catch {
                guard usageRequestID == requestID, mode == .running, self.port == port else { return }
                usageError = L10n.usageUnavailable
            }
            guard usageRequestID == requestID else { return }
            isRefreshingUsage = false
        }
    }

    private func clearUsage() {
        guard copilotUsage != nil || usageLastUpdated != nil || usageError != nil || isRefreshingUsage || usagePort != nil else {
            return
        }
        usageRequestID = UUID()
        copilotUsage = nil
        usageLastUpdated = nil
        usageError = nil
        isRefreshingUsage = false
        usagePort = nil
        nextUsageAttempt = .distantPast
    }

    private func loadAccountIfNeeded() {
        guard let token = HarborPaths.readToken() else { return }
        if token == accountToken || isLoadingAccount || Date() < nextAccountAttempt { return }
        isLoadingAccount = true
        Task {
            let loaded = await GitHubAccount.load(token: token)
            isLoadingAccount = false
            guard HarborPaths.readToken() == token else { return }
            if let loaded {
                accountToken = token
                account = loaded
                nextAccountAttempt = .distantPast
            } else {
                nextAccountAttempt = Date().addingTimeInterval(30)
            }
        }
    }

    func start() {
        guard canStart else { return }
        guard FileManager.default.isExecutableFile(atPath: HarborPaths.bunExecutable.path) else {
            noteStartFailed(L10n.startFailed)
            return
        }
        guard let selectedPort = HarborPort.availablePort() else {
            noteStartFailed(L10n.startFailedNoPort)
            return
        }
        isStarting = true
        preservedFailure = nil
        port = selectedPort
        statusLine = L10n.starting
        let lifetime = Pipe()
        let output = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [
            "-e",
            Self.supervisorScript,
            "--",
            HarborPaths.bunExecutable.path,
            HarborPaths.serverEntrypoint.path,
            "start",
            "--port",
            String(selectedPort)
        ]
        process.currentDirectoryURL = HarborPaths.serverRoot
        var environment = ProcessInfo.processInfo.environment
        environment.removeValue(forKey: "ELECTRON_RUN_AS_NODE")
        process.environment = environment
        process.standardInput = lifetime.fileHandleForReading
        process.standardOutput = output
        process.standardError = output
        output.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                guard let self, self.serverProcess === process else { return }
                self.serverProcess = nil
                self.serverLifetimePipe = nil
                self.isStarting = false
                self.port = nil
                if process.terminationStatus != 0 {
                    self.noteStartFailed(L10n.startFailed(code: process.terminationStatus))
                }
                self.refresh()
            }
        }
        do {
            try process.run()
            try lifetime.fileHandleForReading.close()
            serverProcess = process
            serverLifetimePipe = lifetime
        } catch {
            serverLifetimePipe = nil
            isStarting = false
            port = nil
            noteStartFailed(L10n.startFailed)
            refresh()
        }
    }

    func stop() {
        let process = serverProcess
        serverProcess = nil
        serverLifetimePipe = nil
        port = nil
        if process?.isRunning == true {
            process?.terminate()
        }
        isStarting = false
        clearUsage()
        statusLine = ""
        refresh()
    }

    private static let supervisorScript = """
    use strict;
    use POSIX qw(:sys_wait_h);

    my $child = fork();
    die "fork failed\\n" unless defined $child;
    if ($child == 0) {
      open STDIN, "<", "/dev/null" or die "stdin: $!\\n";
      setpgrp(0, 0);
      exec @ARGV or die "exec failed: $!\\n";
    }

    sub stop_child {
      return unless $child && kill(0, $child);
      kill "TERM", -$child;
      my $deadline = time + 1;
      while (time < $deadline) {
        my $kid = waitpid($child, WNOHANG);
        return if $kid == $child;
        select undef, undef, undef, 0.1;
      }
      kill "KILL", -$child;
      waitpid($child, 0);
    }

    $SIG{TERM} = $SIG{INT} = $SIG{HUP} = sub { stop_child(); exit 0; };

    my $rin = "";
    vec($rin, fileno(STDIN), 1) = 1;
    while (1) {
      my $kid = waitpid($child, WNOHANG);
      if ($kid == $child) {
        exit($? >> 8);
      }
      my $ready = select(my $rout = $rin, undef, undef, 0.2);
      next if !$ready;
      my $buf;
      my $got = sysread(STDIN, $buf, 1);
      if (!defined $got || $got == 0) {
        stop_child();
        exit 0;
      }
    }
    """

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

private enum FailureNotice: Equatable {
    case login
    case start(String)
}
