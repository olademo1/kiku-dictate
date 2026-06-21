import Foundation

final class GlobalUsageSettingsStore {
    private let key = "dataiku_chirp_global_usage_settings"
    private let installationIdKey = "dataiku_chirp_installation_id"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> GlobalUsageSettings {
        let installationId = loadInstallationId()
        guard let data = defaults.data(forKey: key),
              var settings = try? JSONDecoder().decode(GlobalUsageSettings.self, from: data)
        else {
            return GlobalUsageSettings.defaultSettings(installationId: installationId)
        }

        if settings.installationId.isEmpty {
            settings.installationId = installationId
        }
        return settings
    }

    func save(_ settings: GlobalUsageSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }

    private func loadInstallationId() -> String {
        if let stored = defaults.string(forKey: installationIdKey), !stored.isEmpty {
            return stored
        }

        let generated = UUID().uuidString
        defaults.set(generated, forKey: installationIdKey)
        return generated
    }
}
