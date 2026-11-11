import AppKit
import SwiftUI
import Darwin

@MainActor
final class HarborAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let reopenNotification = Notification.Name("local.harbor.app.reopen")
    private var windowController: NSWindowController?
    private var statusItem: NSStatusItem?
    private var lockFD: Int32 = -1
    private var isPrimaryInstance = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        do {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Harbor", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            lockFD = open(directory.appendingPathComponent("instance.lock").path,
                          O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, S_IRUSR | S_IWUSR)
            guard lockFD >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            guard flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
                let error = errno
                close(lockFD)
                lockFD = -1
                if error == EWOULDBLOCK || error == EAGAIN {
                    DistributedNotificationCenter.default().postNotificationName(
                        Self.reopenNotification, object: nil, userInfo: nil, deliverImmediately: true
                    )
                    NSApp.terminate(nil)
                    return
                }
                throw POSIXError(POSIXErrorCode(rawValue: error) ?? .EIO)
            }
            isPrimaryInstance = true
            DistributedNotificationCenter.default().addObserver(
                self, selector: #selector(reopenFromAnotherInstance(_:)),
                name: Self.reopenNotification, object: nil
            )
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = L10n.unableToLaunch
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard isPrimaryInstance else { return }
        NSApp.setActivationPolicy(.accessory)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let icon = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png")
                .flatMap { NSImage(contentsOf: $0) }
            icon?.size = NSSize(width: 22, height: 22)
            icon?.isTemplate = true
            button.image = icon
            button.toolTip = "Harbor"
            button.setAccessibilityLabel("Harbor")
        }
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        item.menu = menu
        statusItem = item
        showWindow()
    }

    @objc private func reopenFromAnotherInstance(_ notification: Notification) {
        showWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func showWindow() {
        if windowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Harbor"
            window.contentView = NSHostingView(rootView: HarborDashboard())
            window.setContentSize(NSSize(width: 460, height: 520))
            window.isReleasedWhenClosed = false
            window.center()
            windowController = NSWindowController(window: window)
        }
        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard isPrimaryInstance else { return }
        ServerController.shared.stop()
        LoginController.shared.cancel()
        DistributedNotificationCenter.default().removeObserver(self)
        if lockFD >= 0 { close(lockFD) }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let server = ServerController.shared
        let login = LoginController.shared
        addItem(L10n.openHarbor, action: #selector(openWindow), to: menu)
        addItem(server.statusLine, action: nil, to: menu)
        if let account = server.account {
            addItem(account.menuTitle, action: nil, to: menu)
        }
        if server.mode == .running, let port = server.port,
           let base = server.serviceBaseURL, let openAI = server.openAIBaseURL {
            addItem(L10n.portMenu(port), action: nil, to: menu)
            addItem(base, action: nil, to: menu)
            addItem(openAI, action: nil, to: menu)
            addItem(L10n.copyServiceURL, action: #selector(copyServiceBase), to: menu)
            addItem(L10n.copyOpenAIURL, action: #selector(copyOpenAIBase), to: menu)
        }
        menu.addItem(.separator())
        if login.isWaiting {
            addItem(login.deviceCode.isEmpty ? L10n.gettingDeviceCode : login.deviceCode,
                    action: #selector(copyDeviceCode), enabled: !login.deviceCode.isEmpty, to: menu)
            addItem(L10n.openGitHub, action: #selector(openVerificationPage),
                    enabled: login.verificationURL != nil, to: menu)
            addItem(L10n.cancelSignIn, action: #selector(cancelLogin), to: menu)
        } else {
            addItem(L10n.start, action: #selector(startServer), enabled: server.canStart, to: menu)
            addItem(L10n.stop, action: #selector(stopServer), enabled: server.canStop, to: menu)
            menu.addItem(.separator())
            addItem(server.isLoggedIn ? L10n.signInAgain : L10n.signIn, action: #selector(startLogin), to: menu)
            addItem(L10n.usage, action: #selector(openUsage), enabled: server.usageURL != nil, to: menu)
        }
        menu.addItem(.separator())
        addItem(L10n.quitHarbor, action: #selector(quit), to: menu)
    }

    private func addItem(_ title: String, action: Selector?, enabled: Bool = true, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = action != nil && enabled
        menu.addItem(item)
    }

    @objc private func openWindow() { showWindow() }
    @objc private func startServer() { ServerController.shared.start() }
    @objc private func stopServer() { ServerController.shared.stop() }
    @objc private func startLogin() { LoginController.shared.start() }
    @objc private func cancelLogin() { LoginController.shared.cancel() }
    @objc private func copyDeviceCode() { LoginController.shared.copyDeviceCode() }
    @objc private func openVerificationPage() { LoginController.shared.openVerificationPage() }
    @objc private func openUsage() {
        guard let url = ServerController.shared.usageURL else { return }
        NSWorkspace.shared.open(url)
    }
    @objc private func copyServiceBase() {
        guard let url = ServerController.shared.serviceBaseURL else { return }
        ServerController.shared.copy(url)
    }
    @objc private func copyOpenAIBase() {
        guard let url = ServerController.shared.openAIBaseURL else { return }
        ServerController.shared.copy(url)
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

@main
struct HarborApp: App {
    @NSApplicationDelegateAdaptor(HarborAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

private struct HarborDashboard: View {
    @ObservedObject private var server = ServerController.shared
    @ObservedObject private var login = LoginController.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Harbor")
                .font(.largeTitle.bold())
            if let account = server.account {
                HStack(spacing: 12) {
                    if let avatarURL = account.avatarURL {
                        AsyncImage(url: avatarURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.secondary.opacity(0.25)
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.primary)
                            .font(.title3.bold())
                        if let secondary = account.secondary {
                            Text(secondary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else if server.isLoggedIn {
                Text(L10n.loadingAccount)
                    .foregroundStyle(.secondary)
            }
            Text(server.statusLine)
                .font(.headline)
            if server.mode == .running, let port = server.port,
               let base = server.serviceBaseURL, let openAI = server.openAIBaseURL {
                VStack(alignment: .leading, spacing: 10) {
                    endpointRow(L10n.port, "\(port)")
                    endpointRow(L10n.serviceURL, base)
                    endpointRow("OpenAI / Codex", openAI)
                    Text(L10n.ccSwitchHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if login.isWaiting {
                Text(L10n.enterDeviceCode)
                HStack {
                    Button(login.deviceCode.isEmpty ? L10n.gettingDeviceCode : login.deviceCode) {
                        login.copyDeviceCode()
                    }
                    .disabled(login.deviceCode.isEmpty)
                    Button(L10n.openGitHub) { login.openVerificationPage() }
                        .disabled(login.verificationURL == nil)
                    Button(L10n.cancel) { login.cancel() }
                }
            } else {
                HStack {
                    Button(L10n.start) { server.start() }
                        .disabled(!server.canStart)
                    Button(L10n.stop) { server.stop() }
                        .disabled(!server.canStop)
                    Button(server.isLoggedIn ? L10n.signInAgain : L10n.signIn) { login.start() }
                    Button(L10n.usage) {
                        if let url = server.usageURL {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .disabled(server.usageURL == nil)
                }
            }
            Spacer()
            Text(L10n.windowStaysInMenuBar)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func endpointRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Text(value)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 8)
                Button(L10n.copy) { server.copy(value) }
            }
        }
    }
}
