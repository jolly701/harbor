import Foundation

enum L10n {
    static var openHarbor: String { text("openHarbor") }
    static var quitHarbor: String { text("quitHarbor") }
    static var unableToLaunch: String { text("unableToLaunch") }
    static var start: String { text("start") }
    static var stop: String { text("stop") }
    static var signIn: String { text("signIn") }
    static var signInAgain: String { text("signInAgain") }
    static var copilotUsage: String { text("copilotUsage") }
    static var premiumRequests: String { text("premiumRequests") }
    static var chatQuota: String { text("chatQuota") }
    static var completionsQuota: String { text("completionsQuota") }
    static var usagePlanUnknown: String { text("usagePlanUnknown") }
    static var usageNoData: String { text("usageNoData") }
    static var usageUnavailable: String { text("usageUnavailable") }
    static var usageRefreshFailed: String { text("usageRefreshFailed") }
    static var loadingUsage: String { text("loadingUsage") }
    static var refreshUsage: String { text("refreshUsage") }
    static func usageUpdated(_ time: String) -> String {
        format("usageUpdated", time)
    }
    static var copy: String { text("copy") }
    static var copied: String { text("copied") }
    static var cancel: String { text("cancel") }
    static var cancelSignIn: String { text("cancelSignIn") }
    static var port: String { text("port") }
    static var serviceURL: String { text("serviceURL") }
    static var serviceURLs: String { text("serviceURLs") }
    static var localAIProxy: String { text("localAIProxy") }
    static var copyServiceURL: String { text("copyServiceURL") }
    static var copyOpenAIURL: String { text("copyOpenAIURL") }
    static var loadingAccount: String { text("loadingAccount") }
    static var enterDeviceCode: String { text("enterDeviceCode") }
    static var gettingDeviceCode: String { text("gettingDeviceCode") }
    static var waitingAuthorization: String { text("waitingAuthorization") }
    static var openGitHub: String { text("openGitHub") }
    static var windowStaysInMenuBar: String { text("windowStaysInMenuBar") }
    static var ccSwitchHint: String { text("ccSwitchHint") }
    static var loggedOut: String { text("loggedOut") }
    static var loginFailed: String { text("loginFailed") }
    static var loggedInStopped: String { text("loggedInStopped") }
    static var starting: String { text("starting") }
    static var running: String { text("running") }
    static var startFailed: String { text("startFailed") }
    static var startFailedNoPort: String { text("startFailedNoPort") }

    static func portMenu(_ port: Int) -> String {
        format("portMenu", String(port))
    }

    static func runningFallback(preferred: Int, port: Int) -> String {
        format("runningFallback", String(preferred), String(port))
    }

    static func portSwitched(preferred: Int, port: Int) -> String {
        format("portSwitched", String(preferred), String(port))
    }

    static func usagePlan(_ plan: String) -> String {
        format("usagePlan", plan)
    }

    static func usageResets(_ date: String) -> String {
        format("usageResets", date)
    }

    static func usageRemaining(_ percent: String) -> String {
        format("usageRemaining", percent)
    }

    static func statusBarUsage(_ percent: String) -> String {
        format("statusBarUsage", percent)
    }

    static func startFailed(code: Int32) -> String {
        format("startFailedCode", String(code))
    }

    private static func text(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }

    private static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale.current, arguments: arguments)
    }
}
