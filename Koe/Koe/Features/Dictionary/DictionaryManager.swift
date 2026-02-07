import Foundation

struct DictionaryManager {
    private let entries: [(trigger: String, replacement: String)]

    init(entries: [DictionaryEntry]) {
        self.entries = entries
            .filter(\.isEnabled)
            .map { (trigger: $0.trigger, replacement: $0.replacement) }
    }

    func apply(to text: String) -> String {
        var result = text
        for entry in entries {
            result = result.replacingOccurrences(
                of: entry.trigger,
                with: entry.replacement
            )
        }
        return result
    }
}
