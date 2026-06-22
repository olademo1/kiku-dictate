import Foundation

struct TranscriptionReplacementRule: Codable, Identifiable, Equatable {
    var id: UUID
    var trigger: String
    var replacement: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        trigger: String,
        replacement: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.trigger = trigger
        self.replacement = replacement
        self.isEnabled = isEnabled
    }

    var cleanedTrigger: String {
        trigger.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanedReplacement: String {
        replacement.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isUsable: Bool {
        isEnabled && !cleanedTrigger.isEmpty && !cleanedReplacement.isEmpty
    }

    static let defaultRules: [TranscriptionReplacementRule] = [
        .init(trigger: "Data IQ", replacement: "Dataiku"),
        .init(trigger: "Data Aiku", replacement: "Dataiku"),
        .init(trigger: "Dereika", replacement: "Dataiku"),
        .init(trigger: "Didaiku", replacement: "Dataiku"),
        .init(trigger: "Daydaiku", replacement: "Dataiku"),
        .init(trigger: "Data Iker", replacement: "Dataiker"),
        .init(trigger: "Data Aiker", replacement: "Dataiker"),
        .init(trigger: "Data Eicher", replacement: "Dataiker"),
        .init(trigger: "Idita Eicher", replacement: "Dataiker"),
        .init(trigger: "Adida Aiker", replacement: "a Dataiker")
    ]
}
