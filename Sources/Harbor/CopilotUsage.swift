import Foundation

struct CopilotUsage: Decodable, Equatable {
    let plan: String?
    let resetDate: String?
    let quotaSnapshots: QuotaSnapshots?

    enum CodingKeys: String, CodingKey {
        case plan = "copilot_plan"
        case resetDate = "quota_reset_date"
        case quotaSnapshots = "quota_snapshots"
    }

    var displayPlan: String? {
        guard let plan = plan?.trimmingCharacters(in: .whitespacesAndNewlines), !plan.isEmpty else {
            return nil
        }
        return plan.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var formattedResetDate: String? {
        guard let resetDate, !resetDate.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        let date = fractional.date(from: resetDate) ?? standard.date(from: resetDate)
        guard let date else { return resetDate }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var metrics: [CopilotQuotaMetric] {
        guard let quotaSnapshots else { return [] }
        return [
            premiumMetric,
            CopilotQuotaMetric.make(id: "chat", title: L10n.chatQuota,
                                    snapshot: quotaSnapshots.chat),
            CopilotQuotaMetric.make(id: "completions", title: L10n.completionsQuota,
                                    snapshot: quotaSnapshots.completions)
        ].compactMap { $0 }
    }

    var premiumUsedFraction: Double? {
        premiumMetric?.usedFraction
    }

    private var premiumMetric: CopilotQuotaMetric? {
        CopilotQuotaMetric.make(id: "premium_interactions", title: L10n.premiumRequests,
                                snapshot: quotaSnapshots?.premiumInteractions)
    }

    static func fetch(port: Int) async throws -> CopilotUsage {
        guard let url = HarborPort.usageEndpoint(port: port) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(CopilotUsage.self, from: data)
    }
}

struct QuotaSnapshots: Decodable, Equatable {
    let premiumInteractions: QuotaSnapshot?
    let chat: QuotaSnapshot?
    let completions: QuotaSnapshot?

    enum CodingKeys: String, CodingKey {
        case premiumInteractions = "premium_interactions"
        case chat
        case completions
    }
}

struct QuotaSnapshot: Decodable, Equatable {
    let entitlement: Double?
    let remaining: Double?
    let percentRemaining: Double?

    enum CodingKeys: String, CodingKey {
        case entitlement
        case remaining
        case percentRemaining = "percent_remaining"
    }
}

struct CopilotQuotaMetric: Equatable, Identifiable {
    let id: String
    let title: String
    let used: Double
    let entitlement: Double
    let remainingPercent: Double

    var usedFraction: Double {
        guard entitlement > 0 else { return 0 }
        return min(max(used / entitlement, 0), 1)
    }

    var usedText: String {
        used.formatted(.number.precision(.fractionLength(0...1)))
    }

    var entitlementText: String {
        entitlement.formatted(.number.precision(.fractionLength(0...1)))
    }

    var remainingPercentText: String {
        remainingPercent.formatted(.number.precision(.fractionLength(0...0)))
    }

    static func make(id: String, title: String, snapshot: QuotaSnapshot?) -> CopilotQuotaMetric? {
        guard let snapshot,
              let entitlement = snapshot.entitlement,
              let remaining = snapshot.remaining,
              entitlement > 0 else {
            return nil
        }
        let used = min(max(entitlement - remaining, 0), entitlement)
        let remainingPercent = snapshot.percentRemaining ?? (remaining / entitlement * 100)
        return CopilotQuotaMetric(
            id: id,
            title: title,
            used: used,
            entitlement: entitlement,
            remainingPercent: min(max(remainingPercent, 0), 100)
        )
    }
}
