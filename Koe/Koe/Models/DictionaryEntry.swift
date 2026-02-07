import Foundation

struct DictionaryEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var trigger: String
    var replacement: String
    var isEnabled: Bool
    var createdAt: Date

    init(trigger: String, replacement: String) {
        self.id = UUID()
        self.trigger = trigger
        self.replacement = replacement
        self.isEnabled = true
        self.createdAt = Date()
    }
}
