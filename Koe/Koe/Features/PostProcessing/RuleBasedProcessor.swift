import Foundation

struct RuleBasedProcessor: TextProcessor {
    struct Rule {
        let pattern: String
        let replacement: String
        let isRegex: Bool
    }

    private let rules: [Rule] = [
        // English fillers
        Rule(pattern: #"\b(um|uh|erm|hmm)\b[,.]?\s*"#, replacement: "", isRegex: true),
        Rule(pattern: #"\byou know[,.]?\s*"#, replacement: "", isRegex: true),
        Rule(pattern: #"\bI mean[,.]?\s*"#, replacement: "", isRegex: true),
        Rule(pattern: #"\bso basically[,.]?\s*"#, replacement: "", isRegex: true),
        Rule(pattern: #"\bactually[,.]?\s+"#, replacement: "", isRegex: true),
        Rule(pattern: #"\blike[,.]?\s+(?=\w)"#, replacement: "", isRegex: true),
        Rule(pattern: #"\bright[,.]?\s+(?=so|and|but)"#, replacement: "", isRegex: true),
        Rule(pattern: #"\bsort of[,.]?\s*"#, replacement: "", isRegex: true),
        Rule(pattern: #"\bkind of[,.]?\s*"#, replacement: "", isRegex: true),
        Rule(pattern: #"\bbasically[,.]?\s*"#, replacement: "", isRegex: true),
        Rule(pattern: #"\bliterally[,.]?\s*"#, replacement: "", isRegex: true),
        Rule(pattern: #"\byeah so[,.]?\s*"#, replacement: "", isRegex: true),

        // Chinese fillers
        Rule(pattern: "那个[，,]?\\s*", replacement: "", isRegex: true),
        Rule(pattern: "就是说?[，,]?\\s*", replacement: "", isRegex: true),
        Rule(pattern: "然后[，,]?\\s*", replacement: "", isRegex: true),
        Rule(pattern: "嗯+[，,]?\\s*", replacement: "", isRegex: true),
        Rule(pattern: "啊[，,]?\\s*", replacement: "", isRegex: true),
        Rule(pattern: "这个[，,]?\\s*", replacement: "", isRegex: true),
        Rule(pattern: "怎么说呢[，,]?\\s*", replacement: "", isRegex: true),

        // Chinese character repetition (对对对→对)
        Rule(pattern: "([\\u{4e00}-\\u{9fff}])\\1{2,}", replacement: "$1", isRegex: true),

        // Japanese fillers
        Rule(pattern: "えーと[、,]?\\s*", replacement: "", isRegex: true),
        Rule(pattern: "あのー?[、,]?\\s*", replacement: "", isRegex: true),
        Rule(pattern: "まあ[、,]?\\s*", replacement: "", isRegex: true),
        Rule(pattern: "その[、,]?\\s*", replacement: "", isRegex: true),
        Rule(pattern: "なんか[、,]?\\s*", replacement: "", isRegex: true),

        // Repeated words
        Rule(pattern: #"\b(\w+)\s+\1\b"#, replacement: "$1", isRegex: true),

        // Collapse multiple spaces
        Rule(pattern: #"\s{2,}"#, replacement: " ", isRegex: true),
    ]

    private let customReplacements: [(String, String)]

    init(customReplacements: [(String, String)] = []) {
        self.customReplacements = customReplacements
    }

    func process(_ text: String, language: String?) async throws -> String {
        var result = text

        for rule in rules {
            if rule.isRegex {
                result = result.replacingOccurrences(
                    of: rule.pattern,
                    with: rule.replacement,
                    options: [.regularExpression, .caseInsensitive]
                )
            } else {
                result = result.replacingOccurrences(
                    of: rule.pattern,
                    with: rule.replacement
                )
            }
        }

        for (trigger, replacement) in customReplacements {
            result = result.replacingOccurrences(of: trigger, with: replacement)
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
