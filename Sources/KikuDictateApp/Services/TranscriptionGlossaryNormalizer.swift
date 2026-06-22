import Foundation

enum TranscriptionGlossaryNormalizer {
    private static let rules: [(pattern: String, replacement: String)] = [
        (#"Data\s+IQ"#, "Dataiku"),
        (#"Dereika"#, "Dataiku"),
        (#"Didaiku"#, "Dataiku"),
        (#"Daydaiku"#, "Dataiku"),
        (#"Data\s+Iker"#, "Dataiker"),
        (#"Data\s+Eicher"#, "Dataiker"),
        (#"Idita\s+Eicher"#, "Dataiker")
    ]

    static func normalize(_ text: String) -> String {
        rules.reduce(text) { current, rule in
            replacePhrase(rule.pattern, with: rule.replacement, in: current)
        }
    }

    private static func replacePhrase(_ phrasePattern: String, with replacement: String, in text: String) -> String {
        let pattern = #"(?i)(?<![A-Za-z0-9])"# + phrasePattern + #"(?![A-Za-z0-9])"#

        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: replacement
        )
    }
}
