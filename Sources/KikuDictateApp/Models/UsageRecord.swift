import Foundation

struct UsageRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let transcriptionSeconds: TimeInterval
    let wordCount: Int
    let estimatedTypingSecondsSaved: TimeInterval
    let estimatedVendorCostAvoidedUSD: Double

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        transcriptionSeconds: TimeInterval,
        wordCount: Int,
        estimatedTypingSecondsSaved: TimeInterval,
        estimatedVendorCostAvoidedUSD: Double
    ) {
        self.id = id
        self.createdAt = createdAt
        self.transcriptionSeconds = transcriptionSeconds
        self.wordCount = wordCount
        self.estimatedTypingSecondsSaved = estimatedTypingSecondsSaved
        self.estimatedVendorCostAvoidedUSD = estimatedVendorCostAvoidedUSD
    }
}

struct UsageSummary: Equatable {
    let sessions: Int
    let todayWords: Int
    let monthWords: Int
    let totalWords: Int
    let totalTranscriptionMinutes: Double
    let totalTypingHoursSaved: Double
    let totalVendorCostAvoidedUSD: Double
    let lastRecordingWords: Int

    static let empty = UsageSummary(
        sessions: 0,
        todayWords: 0,
        monthWords: 0,
        totalWords: 0,
        totalTranscriptionMinutes: 0,
        totalTypingHoursSaved: 0,
        totalVendorCostAvoidedUSD: 0,
        lastRecordingWords: 0
    )

    static func from(records: [UsageRecord], now: Date = Date(), calendar: Calendar = .current) -> UsageSummary {
        guard !records.isEmpty else { return .empty }

        let today = records.filter { calendar.isDate($0.createdAt, inSameDayAs: now) }
        let month = records.filter {
            let a = calendar.dateComponents([.year, .month], from: $0.createdAt)
            let b = calendar.dateComponents([.year, .month], from: now)
            return a.year == b.year && a.month == b.month
        }

        let totalSeconds = records.reduce(0) { $0 + $1.transcriptionSeconds }
        let totalSaved = records.reduce(0) { $0 + $1.estimatedTypingSecondsSaved }
        let totalAvoidedCost = records.reduce(0) { $0 + $1.estimatedVendorCostAvoidedUSD }
        let latest = records.max(by: { $0.createdAt < $1.createdAt })

        return UsageSummary(
            sessions: records.count,
            todayWords: today.reduce(0) { $0 + $1.wordCount },
            monthWords: month.reduce(0) { $0 + $1.wordCount },
            totalWords: records.reduce(0) { $0 + $1.wordCount },
            totalTranscriptionMinutes: totalSeconds / 60.0,
            totalTypingHoursSaved: totalSaved / 3600.0,
            totalVendorCostAvoidedUSD: totalAvoidedCost,
            lastRecordingWords: latest?.wordCount ?? 0
        )
    }
}

