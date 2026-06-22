import Foundation

enum TranscriptionGlossaryNormalizer {
    static func normalize(
        _ text: String,
        using rules: [TranscriptionReplacementRule] = TranscriptionReplacementRule.defaultRules
    ) -> String {
        rules.reduce(text) { current, rule in
            replacePhrase(rule.cleanedTrigger, with: rule.cleanedReplacement, in: current, isEnabled: rule.isUsable)
        }
    }

    private static func replacePhrase(
        _ trigger: String,
        with replacement: String,
        in text: String,
        isEnabled: Bool
    ) -> String {
        guard isEnabled, let phrasePattern = pattern(for: trigger) else {
            return text
        }

        let pattern = #"(?i)(?<![A-Za-z0-9])"# + phrasePattern + #"(?![A-Za-z0-9])"#

        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: NSRegularExpression.escapedTemplate(for: replacement)
        )
    }

    private static func pattern(for trigger: String) -> String? {
        let words = trigger
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split { $0.isWhitespace || $0.isNewline }

        guard !words.isEmpty else { return nil }

        return words
            .map { NSRegularExpression.escapedPattern(for: String($0)) }
            .joined(separator: #"\s+"#)
    }
}
