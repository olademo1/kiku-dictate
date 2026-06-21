import Foundation

final class HotkeyStore {
    private let key = "kiku_dictate_hotkey"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> Hotkey {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(Hotkey.self, from: data)
        else {
            return .default
        }

        return value
    }

    func save(_ hotkey: Hotkey) {
        guard let data = try? JSONEncoder().encode(hotkey) else { return }
        defaults.set(data, forKey: key)
    }
}
