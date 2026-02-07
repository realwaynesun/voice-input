import Foundation

struct TranscriptionRecord: Codable, Identifiable, Hashable {
    let id: UUID
    var text: String
    var rawText: String
    var language: String?
    var duration: TimeInterval
    var wordCount: Int
    var backend: String
    var createdAt: Date

    init(
        text: String,
        rawText: String,
        language: String? = nil,
        duration: TimeInterval,
        backend: String
    ) {
        self.id = UUID()
        self.text = text
        self.rawText = rawText
        self.language = language
        self.duration = duration
        self.wordCount = text.split(separator: " ").count
        self.backend = backend
        self.createdAt = Date()
    }
}
