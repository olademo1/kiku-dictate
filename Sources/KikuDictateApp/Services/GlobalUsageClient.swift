import Foundation

enum GlobalUsageClientError: LocalizedError {
    case disabled
    case notConfigured
    case invalidResponse
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "Team stats sharing is off."
        case .notConfigured:
            return "Add a web app URL and team key first."
        case .invalidResponse:
            return "The global usage endpoint returned an unexpected response."
        case .serverMessage(let message):
            return message
        }
    }
}

final class GlobalUsageClient {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func sync(
        settings: GlobalUsageSettings,
        summary: UsageSummary,
        modelName: String,
        appVersion: String
    ) async throws -> GlobalUsageSnapshot {
        guard settings.enabled else { throw GlobalUsageClientError.disabled }
        let url = try endpointURL(from: settings)
        let report = GlobalUsageReport(
            teamKey: settings.teamKey.trimmingCharacters(in: .whitespacesAndNewlines),
            installationId: settings.installationId,
            appVersion: appVersion,
            modelName: modelName,
            sessions: summary.sessions,
            totalWords: summary.totalWords,
            totalTranscriptionMinutes: summary.totalTranscriptionMinutes,
            totalTypingHoursSaved: summary.totalTypingHoursSaved,
            totalVendorCostAvoidedUSD: summary.totalVendorCostAvoidedUSD,
            reportedAt: Date()
        )

        var request = URLRequest(url: url, timeoutInterval: 12)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(report)

        return try await send(request)
    }

    func fetch(settings: GlobalUsageSettings) async throws -> GlobalUsageSnapshot {
        let baseURL = try endpointURL(from: settings)
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw GlobalUsageClientError.notConfigured
        }

        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "format", value: "json"))
        items.append(URLQueryItem(name: "teamKey", value: settings.teamKey.trimmingCharacters(in: .whitespacesAndNewlines)))
        components.queryItems = items

        guard let url = components.url else {
            throw GlobalUsageClientError.notConfigured
        }

        return try await send(URLRequest(url: url, timeoutInterval: 12))
    }

    private func endpointURL(from settings: GlobalUsageSettings) throws -> URL {
        let value = settings.endpointURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard settings.isConfigured, let url = URL(string: value) else {
            throw GlobalUsageClientError.notConfigured
        }
        return url
    }

    private func send(_ request: URLRequest) async throws -> GlobalUsageSnapshot {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GlobalUsageClientError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            if let message = try? decoder.decode(GlobalUsageErrorEnvelope.self, from: data).error {
                throw GlobalUsageClientError.serverMessage(message)
            }
            throw GlobalUsageClientError.invalidResponse
        }

        let envelope = try decoder.decode(GlobalUsageEnvelope.self, from: data)
        if let error = envelope.error {
            throw GlobalUsageClientError.serverMessage(error)
        }
        guard envelope.ok != false else {
            throw GlobalUsageClientError.invalidResponse
        }
        guard let stats = envelope.stats else {
            throw GlobalUsageClientError.invalidResponse
        }
        return stats
    }
}

private struct GlobalUsageEnvelope: Decodable {
    let ok: Bool?
    let stats: GlobalUsageSnapshot?
    let error: String?
}

private struct GlobalUsageErrorEnvelope: Decodable {
    let error: String?
}
