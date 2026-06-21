import Foundation

struct GlobalUsageSettings: Codable, Equatable {
    var enabled: Bool
    var endpointURLString: String
    var teamKey: String
    var installationId: String
    var lastSyncedAt: Date?

    var hasEndpoint: Bool {
        let value = endpointURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, let url = URL(string: value) else { return false }
        return url.scheme?.lowercased() == "https"
    }

    var isConfigured: Bool {
        hasEndpoint && !teamKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func defaultSettings(installationId: String) -> GlobalUsageSettings {
        GlobalUsageSettings(
            enabled: false,
            endpointURLString: "",
            teamKey: "",
            installationId: installationId,
            lastSyncedAt: nil
        )
    }
}

struct GlobalUsageSnapshot: Codable, Equatable {
    let activeInstallations: Int
    let totalSessions: Int
    let totalWords: Int
    let totalTranscriptionMinutes: Double
    let totalTypingHoursSaved: Double
    let totalVendorCostAvoidedUSD: Double
    let updatedAt: Date?

    static let empty = GlobalUsageSnapshot(
        activeInstallations: 0,
        totalSessions: 0,
        totalWords: 0,
        totalTranscriptionMinutes: 0,
        totalTypingHoursSaved: 0,
        totalVendorCostAvoidedUSD: 0,
        updatedAt: nil
    )
}

struct GlobalUsageReport: Codable, Equatable {
    let teamKey: String
    let installationId: String
    let appVersion: String
    let modelName: String
    let sessions: Int
    let totalWords: Int
    let totalTranscriptionMinutes: Double
    let totalTypingHoursSaved: Double
    let totalVendorCostAvoidedUSD: Double
    let reportedAt: Date
}
