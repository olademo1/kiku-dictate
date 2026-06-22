import Foundation

final class TranscriptionReplacementStore {
    private let key = "dataiku_chirp_transcription_replacements"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [TranscriptionReplacementRule] {
        guard let data = defaults.data(forKey: key) else {
            return TranscriptionReplacementRule.defaultRules
        }

        guard let rules = try? JSONDecoder().decode([TranscriptionReplacementRule].self, from: data) else {
            return TranscriptionReplacementRule.defaultRules
        }

        return rules
    }

    func save(_ rules: [TranscriptionReplacementRule]) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        defaults.set(data, forKey: key)
    }

    func reset() -> [TranscriptionReplacementRule] {
        let rules = TranscriptionReplacementRule.defaultRules
        save(rules)
        return rules
    }
}
