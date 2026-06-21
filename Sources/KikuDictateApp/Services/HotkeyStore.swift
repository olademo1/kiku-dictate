import Carbon
import Foundation

final class HotkeyStore {
    private let key = "kiku_dictate_hotkey"
    private let migratedOpenAIShortcutKey = "kiku_dictate_migrated_openai_shortcut"
    private let legacyOptionSpace = Hotkey(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey))
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(allowSingleKey: Bool = false) -> Hotkey {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(Hotkey.self, from: data)
        else {
            return .default
        }

        guard value.isValidGlobalShortcut(allowSingleKey: allowSingleKey) else {
            save(.default)
            return .default
        }

        if value == legacyOptionSpace && !defaults.bool(forKey: migratedOpenAIShortcutKey) {
            defaults.set(true, forKey: migratedOpenAIShortcutKey)
            save(.default)
            return .default
        }

        defaults.set(true, forKey: migratedOpenAIShortcutKey)
        return value
    }

    func save(_ hotkey: Hotkey) {
        guard let data = try? JSONEncoder().encode(hotkey) else { return }
        defaults.set(data, forKey: key)
    }
}
