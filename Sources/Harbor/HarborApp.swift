import AppKit
import SwiftUI
import Darwin

@MainActor
final class HarborAppDelegate: NSObject, NSApplicationDelegate {
    private static let reopenNotification = Notification.Name("local.harbor.app.reopen")
    private var windowController: NSWindowController?
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
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
            button.target = self
            button.action = #selector(togglePopover)
        }
        let hostingController = NSHostingController(rootView: HarborContainer(
            compact: true,
            openWindow: { [weak self] in self?.showWindow() },
            quit: { NSApp.terminate(nil) }
        ))
        hostingController.sizingOptions = [.preferredContentSize, .intrinsicContentSize]
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = hostingController
        self.popover = popover
        statusItem = item
        showWindow()
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func reopenFromAnotherInstance(_ notification: Notification) {
        showWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func showWindow() {
        popover?.performClose(nil)
        if windowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Harbor"
            window.contentView = NSHostingView(rootView: HarborContainer(
                compact: false,
                openWindow: { [weak self] in self?.showWindow() },
                quit: { NSApp.terminate(nil) }
            ))
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

}

@main
struct HarborApp: App {
    @NSApplicationDelegateAdaptor(HarborAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
private struct HarborContainer: View {
    @ObservedObject private var server = ServerController.shared
    @ObservedObject private var login = LoginController.shared

    let compact: Bool
    let openWindow: () -> Void
    let quit: () -> Void

    var body: some View {
        let state = HarborViewState(
            mode: server.mode, isLoggedIn: server.isLoggedIn, isStarting: server.isStarting,
            hasFailure: server.hasFailure, statusLine: server.statusLine, account: server.account,
            port: server.port, serviceURL: server.serviceBaseURL, openAIURL: server.openAIBaseURL,
            canStart: server.canStart, canStop: server.canStop, canOpenUsage: server.usageURL != nil,
            isWaiting: login.isWaiting, deviceCode: login.deviceCode,
            canOpenVerification: login.verificationURL != nil
        )
        let actions = HarborActions(
            start: { server.start() }, stop: { server.stop() }, signIn: { login.start() },
            cancelSignIn: { login.cancel() }, openVerification: { login.openVerificationPage() },
            openUsage: { if let url = server.usageURL { NSWorkspace.shared.open(url) } },
            copy: { server.copy($0) }, openWindow: openWindow, quit: quit
        )
        HarborContentView(state: state, actions: actions, compact: compact)
    }
}
