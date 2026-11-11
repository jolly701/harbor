import AppKit
import SwiftUI

final class HarborAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        ServerController.shared.stop()
        LoginController.shared.cancel()
    }
}

@main
struct HarborApp: App {
    @NSApplicationDelegateAdaptor(HarborAppDelegate.self) private var appDelegate
    @ObservedObject private var server = ServerController.shared
    @ObservedObject private var login = LoginController.shared

    var body: some Scene {
        MenuBarExtra {
            if login.isWaiting {
                loginMenu
            } else {
                idleMenu
            }
        } label: {
            HarborMark(mode: server.mode)
        }
        .menuBarExtraStyle(.menu)
    }

    private var idleMenu: some View {
        Group {
            Text("Harbor")
                .disabled(true)
            Text(server.statusLine)
            Divider()
            Button("启动") { server.start() }
                .disabled(!server.canStart || login.isWaiting)
            Button("停止") { server.stop() }
                .disabled(!server.canStop)
            Divider()
            Button("登录") { login.start() }
                .disabled(login.isWaiting)
            Button("用量") { NSWorkspace.shared.open(HarborPaths.usagePage) }
                .disabled(server.mode != .running)
            Divider()
            Button("退出 Harbor") {
                server.stop()
                NSApp.terminate(nil)
            }
        }
    }

    private var loginMenu: some View {
        Group {
            Text("在浏览器中输入设备码")
            Button(login.deviceCode.isEmpty ? "正在获取设备码…" : login.deviceCode) {
                login.copyDeviceCode()
            }
            .disabled(login.deviceCode.isEmpty)
            Button("打开 GitHub 授权页") { login.openVerificationPage() }
                .disabled(login.verificationURL == nil)
            Text("等待授权…")
            Button("取消") { login.cancel() }
        }
    }
}
