import Foundation

struct UsageStats: Codable {
    var totalDictationSeconds: Double
    var totalWords: Int
    var totalSessions: Int
    var lastSessionDate: Date?

    init() {
        self.totalDictationSeconds = 0
        self.totalWords = 0
        self.totalSessions = 0
    }

    var averageWPM: Int {
        guard totalDictationSeconds > 0 else { return 0 }
        let minutes = totalDictationSeconds / 60.0
        return Int(Double(totalWords) / minutes)
    }

    var estimatedTimeSavedSeconds: Double {
        let avgTypingWPM = 40.0
        let typingMinutes = Double(totalWords) / avgTypingWPM
        return max(0, (typingMinutes * 60) - totalDictationSeconds)
    }

    mutating func record(duration: TimeInterval, wordCount: Int) {
        totalDictationSeconds += duration
        totalWords += wordCount
        totalSessions += 1
        lastSessionDate = Date()
    }
}
