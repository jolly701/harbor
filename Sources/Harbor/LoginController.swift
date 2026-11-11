import AppKit
import Foundation

@MainActor
final class LoginController: ObservableObject {
    static let shared = LoginController()

    @Published private(set) var isWaiting = false
    @Published private(set) var deviceCode = ""
    @Published private(set) var verificationURL: URL?

    private var process: Process?
    private var buffer = ""
    private var cancelled = false

    private init() {}

    func start() {
        guard !isWaiting else { return }
        guard FileManager.default.isExecutableFile(atPath: HarborPaths.bunExecutable.path) else {
            markFailed()
            return
        }
        cancelled = false
        buffer = ""
        deviceCode = ""
        verificationURL = nil
        isWaiting = true

        let process = Process()
        process.executableURL = HarborPaths.bunExecutable
        process.arguments = [HarborPaths.serverEntrypoint.path, "auth"]
        process.currentDirectoryURL = HarborPaths.serverRoot
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.consume(text)
            }
        }
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                self?.finish(exitCode: process.terminationStatus)
            }
        }
        do {
            try process.run()
            self.process = process
        } catch {
            isWaiting = false
            ServerController.shared.refresh()
            markFailed()
        }
    }

    func openVerificationPage() {
        guard let verificationURL else { return }
        NSWorkspace.shared.open(verificationURL)
    }

    func copyDeviceCode() {
        guard !deviceCode.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(deviceCode, forType: .string)
    }

    func cancel() {
        cancelled = true
        process?.terminate()
        process = nil
        isWaiting = false
        deviceCode = ""
        verificationURL = nil
    }

    private func consume(_ text: String) {
        buffer += text.replacingOccurrences(
            of: #"\u{001B}\[[0-9;]*m"#,
            with: "",
            options: .regularExpression
        )
        guard let match = buffer.range(of: #"code "([^"]+)" in (\S+)"#, options: .regularExpression) else {
            return
        }
        let snippet = String(buffer[match])
        let parts = snippet
            .replacingOccurrences(of: "code \"", with: "")
            .split(separator: "\"", maxSplits: 1)
            .map(String.init)
        guard parts.count == 2 else { return }
        let code = parts[0]
        let urlText = parts[1].replacingOccurrences(of: " in ", with: "")
        if deviceCode != code {
            deviceCode = code
            verificationURL = URL(string: urlText)
            if let verificationURL {
                NSWorkspace.shared.open(verificationURL)
            }
        }
    }

    private func finish(exitCode: Int32) {
        process = nil
        isWaiting = false
        if cancelled {
            cancelled = false
            return
        }
        ServerController.shared.refresh()
        if exitCode != 0 || !HarborPaths.hasToken {
            markFailed()
        }
    }

    private func markFailed() {
        ServerController.shared.showStatus("登录失败")
    }
}
