import AppKit
import Foundation

@MainActor
final class ServerController: ObservableObject {
    static let shared = ServerController()

    @Published private(set) var mode: HarborMode = .loggedOut
    @Published private(set) var statusLine = "未登录"
    @Published private(set) var isStarting = false

    private var serverProcess: Process?
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
        mode == .stopped && !isStarting
    }

    var canStop: Bool {
        mode == .running
    }

    func showStatus(_ line: String) {
        statusLine = line
    }

    func refresh() {
        let loggedIn = HarborPaths.hasToken
        let listening = Self.portIsOpen()
        if !loggedIn {
            mode = .loggedOut
            if statusLine != "登录失败" {
                statusLine = "未登录"
            }
        } else if listening {
            mode = .running
            statusLine = "运行中 · 127.0.0.1:4141"
        } else {
            mode = .stopped
            if statusLine != "启动失败" {
                statusLine = "已登录，服务未运行"
            }
        }
    }

    func start() {
        guard canStart else { return }
        guard FileManager.default.isExecutableFile(atPath: HarborPaths.bunExecutable.path) else {
            showStatus("启动失败")
            return
        }
        isStarting = true
        let process = Process()
        process.executableURL = HarborPaths.bunExecutable
        process.arguments = [HarborPaths.serverEntrypoint.path, "start"]
        process.currentDirectoryURL = HarborPaths.serverRoot
        var environment = ProcessInfo.processInfo.environment
        environment.removeValue(forKey: "ELECTRON_RUN_AS_NODE")
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.serverProcess = nil
                self?.isStarting = false
                self?.refresh()
            }
        }
        do {
            try process.run()
            serverProcess = process
        } catch {
            isStarting = false
            showStatus("启动失败")
        }
    }

    func stop() {
        serverProcess?.terminate()
        serverProcess = nil
        if let pid = Self.listenerPID() {
            kill(pid, SIGTERM)
        }
        isStarting = false
        refresh()
    }

    private static func portIsOpen() -> Bool {
        listenerPID() != nil
    }

    private static func listenerPID() -> pid_t? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-nP", "-t", "-iTCP:4141", "-sTCP:LISTEN"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        return text.split(whereSeparator: \.isWhitespace).compactMap { pid_t($0) }.first
    }
}
