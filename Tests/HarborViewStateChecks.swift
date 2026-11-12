import Foundation

@main
struct HarborViewStateChecks {
    static func main() {
        let fallback = makeState(mode: .running, port: 4142)
        check(fallback.statusTitle, L10n.running, "running title")
        check(fallback.statusDetail, L10n.portSwitched(preferred: 4141, port: 4142), "fallback port")

        let reauth = makeState(mode: .running, port: 4142, isWaiting: true, deviceCode: "ABCD-EFGH")
        check(reauth.statusTitle, L10n.waitingAuthorization, "authorization title")
        check(reauth.statusDetail, "\(L10n.running) · \(L10n.portSwitched(preferred: 4141, port: 4142))", "running during authorization")

        let defaultPort = makeState(mode: .running, port: 4141, isWaiting: true, deviceCode: "ABCD-EFGH")
        check(defaultPort.statusDetail, L10n.running, "running during authorization without fallback")
        check(makeState(mode: .loggedOut, isWaiting: true).statusTitle, L10n.gettingDeviceCode, "waiting for device code")
        check(makeState(mode: .stopped, isStarting: true).statusTitle, L10n.starting, "starting")
        check(makeState(mode: .stopped, hasFailure: true, statusLine: "failure detail").statusTitle, "failure detail", "failure")
        checkPremiumUsage()
        print("Harbor view state checks passed")
    }

    private static func checkPremiumUsage() {
        func usage(_ json: String) -> CopilotUsage {
            try! JSONDecoder().decode(CopilotUsage.self, from: Data(json.utf8))
        }
        let populated = usage("""
        {"quota_snapshots":{"premium_interactions":{"entitlement":10000,"remaining":2727}}}
        """)
        guard let fraction = populated.premiumUsedFraction, abs(fraction - 0.7273) < 0.000001 else {
            fputs("FAIL: premium usage fraction\n", stderr)
            exit(1)
        }
        let noQuota = usage("{\"quota_snapshots\":{}}")
        let zeroQuota = usage("{\"quota_snapshots\":{\"premium_interactions\":{\"entitlement\":0,\"remaining\":0}}}")
        guard noQuota.premiumUsedFraction == nil, zeroQuota.premiumUsedFraction == nil else {
            fputs("FAIL: unavailable premium usage\n", stderr)
            exit(1)
        }
    }

    private static func check(_ actual: String?, _ expected: String?, _ label: String) {
        guard actual == expected else {
            fputs("FAIL: \(label): expected \(String(describing: expected)), got \(String(describing: actual))\n", stderr)
            exit(1)
        }
    }

    private static func makeState(
        mode: HarborMode,
        port: Int? = nil,
        isWaiting: Bool = false,
        deviceCode: String = "",
        isStarting: Bool = false,
        hasFailure: Bool = false,
        statusLine: String = ""
    ) -> HarborViewState {
        HarborViewState(
            mode: mode, isLoggedIn: mode != .loggedOut, isStarting: isStarting,
            hasFailure: hasFailure, statusLine: statusLine, account: nil, port: port,
            serviceURL: nil, openAIURL: nil, canStart: false, canStop: false,
            isWaiting: isWaiting, deviceCode: deviceCode,
            canOpenVerification: false
        )
    }
}
