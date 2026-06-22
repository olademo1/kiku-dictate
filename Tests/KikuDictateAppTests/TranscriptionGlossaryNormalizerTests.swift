import XCTest
@testable import KikuDictateApp

final class TranscriptionGlossaryNormalizerTests: XCTestCase {
    func testNormalizesDataikuVariants() {
        let input = "Data IQ is remote. Dereika, Didaiku, and Daydaiku should all match."

        XCTAssertEqual(
            TranscriptionGlossaryNormalizer.normalize(input),
            "Dataiku is remote. Dataiku, Dataiku, and Dataiku should all match."
        )
    }

    func testNormalizesDataikerVariants() {
        let input = "Data Iker, Data Eicher, and Idita Eicher are the same word."

        XCTAssertEqual(
            TranscriptionGlossaryNormalizer.normalize(input),
            "Dataiker, Dataiker, and Dataiker are the same word."
        )
    }

    func testKeepsEmbeddedWordsUnchanged() {
        let input = "MyData IQ and Data IQify should not be changed, but data iq should."

        XCTAssertEqual(
            TranscriptionGlossaryNormalizer.normalize(input),
            "MyData IQ and Data IQify should not be changed, but Dataiku should."
        )
    }
}
