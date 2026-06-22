import XCTest
@testable import KikuDictateApp

final class TranscriptionGlossaryNormalizerTests: XCTestCase {
    func testNormalizesDataikuVariants() {
        let input = "Data IQ is remote. Data Aiku, Dereika, Didaiku, and Daydaiku should all match."

        XCTAssertEqual(
            TranscriptionGlossaryNormalizer.normalize(input),
            "Dataiku is remote. Dataiku, Dataiku, Dataiku, and Dataiku should all match."
        )
    }

    func testNormalizesDataikerVariants() {
        let input = "Data Iker, Data Aiker, Data Eicher, Idita Eicher, and Adida Aiker are related phrases."

        XCTAssertEqual(
            TranscriptionGlossaryNormalizer.normalize(input),
            "Dataiker, Dataiker, Dataiker, Dataiker, and a Dataiker are related phrases."
        )
    }

    func testKeepsEmbeddedWordsUnchanged() {
        let input = "MyData IQ and Data IQify should not be changed, but data iq should."

        XCTAssertEqual(
            TranscriptionGlossaryNormalizer.normalize(input),
            "MyData IQ and Data IQify should not be changed, but Dataiku should."
        )
    }

    func testAppliesUserProvidedRulesWithoutRegexInterpretation() {
        let rules = [
            TranscriptionReplacementRule(trigger: "magic.pulse", replacement: "Magic Pulse"),
            TranscriptionReplacementRule(trigger: "a+b", replacement: "A plus B")
        ]

        XCTAssertEqual(
            TranscriptionGlossaryNormalizer.normalize("magic.pulse and a+b work, but magicXpulse does not.", using: rules),
            "Magic Pulse and A plus B work, but magicXpulse does not."
        )
    }

    func testIgnoresDisabledOrIncompleteRules() {
        let rules = [
            TranscriptionReplacementRule(trigger: "Data IQ", replacement: "Dataiku", isEnabled: false),
            TranscriptionReplacementRule(trigger: "", replacement: "Dataiku"),
            TranscriptionReplacementRule(trigger: "Dereika", replacement: "")
        ]

        XCTAssertEqual(
            TranscriptionGlossaryNormalizer.normalize("Data IQ and Dereika", using: rules),
            "Data IQ and Dereika"
        )
    }
}
