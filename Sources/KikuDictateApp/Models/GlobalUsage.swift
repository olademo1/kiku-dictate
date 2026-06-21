import Foundation

enum DataikuTeam: String, CaseIterable, Codable, Identifiable {
    case engineering = "Engineering"
    case product = "Product"
    case goToMarket = "Go-to-Market"
    case customer = "Customer"
    case marketing = "Marketing"
    case finance = "Finance"
    case people = "People"
    case legal = "Legal"
    case itSecurity = "IT/Security"
    case operations = "Operations"
    case strategy = "Strategy"
    case other = "Other"

    var id: String { rawValue }
}

enum GlobalUsageConfiguration {
    static var endpointURLString: String {
        Bundle.main.object(forInfoDictionaryKey: "DataikuChirpUsageEndpoint") as? String ?? ""
    }

    static var teamKey: String {
        Bundle.main.object(forInfoDictionaryKey: "DataikuChirpUsageTeamKey") as? String ?? ""
    }

    static var endpointURL: URL? {
        guard !endpointURLString.isEmpty, let url = URL(string: endpointURLString) else {
            return nil
        }
        return url.scheme?.lowercased() == "https" ? url : nil
    }

    static var isConfigured: Bool {
        endpointURL != nil && !teamKey.isEmpty
    }
}

struct GlobalUsageSettings: Codable, Equatable {
    var enabled: Bool
    var team: DataikuTeam
    var installationId: String
    var lastSyncedAt: Date?

    var isConfigured: Bool {
        GlobalUsageConfiguration.isConfigured
    }

    static func defaultSettings(installationId: String) -> GlobalUsageSettings {
        GlobalUsageSettings(
            enabled: false,
            team: .other,
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
    let teamName: String
    let appVersion: String
    let modelName: String
    let sessions: Int
    let totalWords: Int
    let totalTranscriptionMinutes: Double
    let totalTypingHoursSaved: Double
    let totalVendorCostAvoidedUSD: Double
    let reportedAt: Date
}
