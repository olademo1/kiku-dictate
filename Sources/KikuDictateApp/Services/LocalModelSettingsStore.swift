import Foundation

final class LocalModelSettingsStore {
    private let key = "kiku_dictate_local_model_settings"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> LocalModelSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(LocalModelSettings.self, from: data)
        else {
            return .default
        }

        if !settings.isReady {
            let defaultSettings = LocalModelSettings.default
            if defaultSettings.isReady {
                return defaultSettings
            }
        }

        return settings
    }

    func save(_ settings: LocalModelSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
