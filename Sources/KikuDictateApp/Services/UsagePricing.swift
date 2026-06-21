import Foundation

enum UsagePricing {
    static let note = "Estimates only. Audio and transcript text are not retained. Savings assume 40 WPM typing and $0.006/min avoided transcription spend."

    private static let typingWordsPerMinute: Double = 40
    private static let correctionOverheadRatio: Double = 0.20
    private static let avoidedVendorUSDPerMinute: Double = 0.006

    static func estimatedTypingSecondsSaved(wordCount: Int, dictationSeconds: TimeInterval) -> TimeInterval {
        let typingSeconds = (Double(max(wordCount, 0)) / typingWordsPerMinute) * 60.0
        let correctionSeconds = typingSeconds * correctionOverheadRatio
        return max(typingSeconds - dictationSeconds - correctionSeconds, 0)
    }

    static func estimatedVendorCostAvoided(transcriptionSeconds: TimeInterval) -> Double {
        let minutes = max(transcriptionSeconds, 0) / 60.0
        return minutes * avoidedVendorUSDPerMinute
    }
}

