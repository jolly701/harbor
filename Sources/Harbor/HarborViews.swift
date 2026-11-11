import AppKit
import SwiftUI

struct HarborViewState {
    let mode: HarborMode
    let isLoggedIn: Bool
    let isStarting: Bool
    let hasFailure: Bool
    let statusLine: String
    let account: GitHubAccount?
    let port: Int?
    let serviceURL: String?
    let openAIURL: String?
    let canStart: Bool
    let canStop: Bool
    let canOpenUsage: Bool
    let isWaiting: Bool
    let deviceCode: String
    let canOpenVerification: Bool

    var statusTitle: String {
        if isWaiting { return deviceCode.isEmpty ? L10n.gettingDeviceCode : L10n.waitingAuthorization }
        if hasFailure { return statusLine }
        if isStarting { return L10n.starting }
        switch mode {
        case .running: return L10n.running
        case .stopped: return L10n.loggedInStopped
        case .loggedOut: return L10n.loggedOut
        }
    }

    var statusDetail: String? {
        guard mode == .running, let port else { return nil }
        guard port != HarborPort.preferred else { return isWaiting ? L10n.running : nil }
        let detail = L10n.portSwitched(preferred: HarborPort.preferred, port: port)
        return isWaiting ? "\(L10n.running) · \(detail)" : detail
    }

    var statusColor: Color {
        if isWaiting || isStarting { return .orange }
        if hasFailure { return .red }
        return mode == .running ? .green : .secondary
    }

    var statusSymbol: String {
        if isWaiting { return "key" }
        if isStarting { return "hourglass" }
        if hasFailure { return "exclamationmark.circle" }
        if mode == .running { return "antenna.radiowaves.left.and.right" }
        return isLoggedIn ? "pause.circle" : "person.crop.circle"
    }
}

struct HarborActions {
    let start: () -> Void
    let stop: () -> Void
    let signIn: () -> Void
    let cancelSignIn: () -> Void
    let openVerification: () -> Void
    let openUsage: () -> Void
    let copy: (String) -> Void
    let openWindow: () -> Void
    let quit: () -> Void
}

private enum HarborStyle {
    static let accent = Color.indigo
    static let border = Color.primary.opacity(0.09)
    static let surface = Color(nsColor: .controlBackgroundColor)
}

private struct HarborButtonStyle: ButtonStyle {
    var primary = false
    var quiet = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, quiet ? 5 : 10)
            .padding(.vertical, 7)
            .foregroundStyle(primary ? Color.white : Color.primary)
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .fill(primary ? HarborStyle.accent : (quiet ? .clear : Color.primary.opacity(0.06)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(quiet || primary ? .clear : HarborStyle.border)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.45)
    }
}

struct HarborContentView: View {
    let state: HarborViewState
    let actions: HarborActions
    let compact: Bool

    @State private var copiedValue: String?
    @State private var copyGeneration = UUID()

    var body: some View {
        Group {
            if compact {
                popoverContent
            } else {
                windowContent
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var windowContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    windowHeader
                        .padding(.bottom, 23)
                    statusCard
                    endpointSection
                    authorizationSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
            Divider()
                .padding(.horizontal, 24)
            HStack(alignment: .center, spacing: 8) {
                secondaryActions
                Spacer(minLength: 8)
                Text(L10n.windowStaysInMenuBar)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 150, alignment: .trailing)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                brandIcon(size: 25)
                Text("Harbor")
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 8)
                if let account = state.account {
                    Text(account.secondary ?? "@\(account.login)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.bottom, 14)
            statusCard
            endpointSection
            authorizationSection
            if !state.isWaiting && state.isLoggedIn {
                HStack(spacing: 4) { secondaryActions }
                    .padding(.top, 12)
            }
            Divider().padding(.top, 10).padding(.bottom, 7)
            HStack {
                Button(action: actions.openWindow) {
                    Label(L10n.openHarbor, systemImage: "macwindow")
                }
                .buttonStyle(HarborButtonStyle(quiet: true))
                Spacer(minLength: 4)
                Button(action: actions.quit) {
                    Label(L10n.quitHarbor, systemImage: "power")
                }
                .buttonStyle(HarborButtonStyle(quiet: true))
            }
        }
        .padding(14)
        .frame(width: 330)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var windowHeader: some View {
        HStack(spacing: 11) {
            brandIcon(size: 37)
            VStack(alignment: .leading, spacing: 1) {
                Text("Harbor")
                    .font(.system(size: 18, weight: .semibold))
                Text(L10n.localAIProxy)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            accountHeader
        }
    }

    private func brandIcon(size: CGFloat) -> some View {
        Group {
            if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().interpolation(.high)
            } else {
                Image(systemName: "sparkle")
                    .resizable().scaledToFit().padding(size * 0.23)
                    .foregroundStyle(.white)
                    .background(.black, in: RoundedRectangle(cornerRadius: size * 0.22))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var accountHeader: some View {
        HStack(spacing: 8) {
            Group {
                if let avatar = state.account?.avatarURL {
                    AsyncImage(url: avatar) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable().scaledToFit().foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable().scaledToFit().foregroundStyle(.secondary)
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(state.account?.primary ?? (state.isLoggedIn ? L10n.loadingAccount : L10n.loggedOut))
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                if let secondary = state.account?.secondary {
                    Text(secondary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: 145, alignment: .leading)
        }
    }

    private var statusCard: some View {
        HStack(spacing: compact ? 9 : 13) {
            Image(systemName: state.statusSymbol)
                .font(.system(size: compact ? 15 : 17, weight: .medium))
                .foregroundStyle(HarborStyle.accent)
                .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)
                .background(HarborStyle.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Circle().fill(state.statusColor).frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                    Text(state.statusTitle)
                        .font(.system(size: compact ? 12 : 13, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let detail = state.statusDetail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            statusAction
        }
        .padding(compact ? 11 : 15)
        .background(HarborStyle.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(HarborStyle.border))
    }

    @ViewBuilder
    private var statusAction: some View {
        if !state.isWaiting {
            if state.canStop {
                Button(L10n.stop, action: actions.stop)
                    .buttonStyle(HarborButtonStyle())
            } else if state.canStart {
                Button(L10n.start, action: actions.start)
                    .buttonStyle(HarborButtonStyle(primary: true))
            } else if !state.isLoggedIn {
                Button(L10n.signIn, action: actions.signIn)
                    .buttonStyle(HarborButtonStyle(primary: true))
            }
        }
    }

    @ViewBuilder
    private var endpointSection: some View {
        if state.mode == .running, let port = state.port,
           let base = state.serviceURL, let openAI = state.openAIURL {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(L10n.serviceURLs)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Text(L10n.portMenu(port))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    copyButton(value: String(port), label: L10n.port, quiet: true)
                }
                VStack(spacing: 0) {
                    endpointRow(title: L10n.serviceURL, value: base)
                    Divider()
                    endpointRow(title: "OpenAI / Codex", value: openAI)
                }
                .background(HarborStyle.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(HarborStyle.border))
                if !compact && !state.isWaiting {
                    Text(L10n.ccSwitchHint)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, compact ? 15 : 22)
        }
    }

    private func endpointRow(title: String, value: String) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(value)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            copyButton(value: value, label: title)
        }
        .padding(compact ? 9 : 11)
    }

    private func copyButton(value: String, label: String, quiet: Bool = false) -> some View {
        Button {
            actions.copy(value)
            let generation = UUID()
            copyGeneration = generation
            copiedValue = value
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if copyGeneration == generation { copiedValue = nil }
            }
        } label: {
            if quiet {
                Text(copiedValue == value ? L10n.copied : L10n.copy)
            } else {
                Label(copiedValue == value ? L10n.copied : L10n.copy,
                      systemImage: copiedValue == value ? "checkmark" : "doc.on.doc")
            }
        }
        .buttonStyle(HarborButtonStyle(quiet: quiet))
        .accessibilityLabel("\(copiedValue == value ? L10n.copied : L10n.copy) \(label)")
    }

    @ViewBuilder
    private var authorizationSection: some View {
        if state.isWaiting {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.enterDeviceCode)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                HStack {
                    Text(state.deviceCode.isEmpty ? L10n.gettingDeviceCode : state.deviceCode)
                        .font(.system(size: state.deviceCode.isEmpty ? 11 : 15,
                                      weight: .semibold, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer(minLength: 8)
                    copyButton(value: state.deviceCode, label: L10n.enterDeviceCode)
                        .disabled(state.deviceCode.isEmpty)
                }
                HStack(spacing: 5) {
                    Button(L10n.openGitHub, action: actions.openVerification)
                        .buttonStyle(HarborButtonStyle())
                        .disabled(!state.canOpenVerification)
                    Button(L10n.cancel, action: actions.cancelSignIn)
                        .buttonStyle(HarborButtonStyle(quiet: true))
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HarborStyle.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(HarborStyle.border))
            .padding(.top, compact ? 12 : 20)
        }
    }

    @ViewBuilder
    private var secondaryActions: some View {
        if !state.isWaiting && state.isLoggedIn {
            Button(L10n.signInAgain, action: actions.signIn)
                .buttonStyle(HarborButtonStyle(quiet: true))
            if state.canOpenUsage {
                Button(action: actions.openUsage) {
                    Label(L10n.usage, systemImage: "arrow.up.right.square")
                }
                .buttonStyle(HarborButtonStyle(quiet: true))
            }
        }
    }
}
