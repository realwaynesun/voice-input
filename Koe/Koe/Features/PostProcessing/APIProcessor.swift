import Foundation

final class APIProcessor: TextProcessor {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func process(_ text: String, language: String?) async throws -> String {
        var request = URLRequest(
            url: URL(string: "https://api.openai.com/v1/chat/completions")!
        )
        request.httpMethod = "POST"
        request.setValue(
            "Bearer \(apiKey)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let langHint = language.map { " (detected language: \($0))" } ?? ""
        let systemPrompt = """
            Clean up this dictated text\(langHint). \
            Remove filler words (um, uh, like, you know, \u{90a3}\u{4e2a}, \
            \u{5c31}\u{662f}, \u{3048}\u{30fc}\u{3068}). \
            Fix grammar and punctuation. \
            Remove self-corrections (keep only the final intended version). \
            Preserve the original meaning and language. \
            Output ONLY the cleaned text, nothing else.
            """

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text],
            ],
            "temperature": 0.1,
            "max_tokens": 2048,
        ]

        request.httpBody = try JSONSerialization.data(
            withJSONObject: body
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw PostProcessingError.apiFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String

        guard let result = content else {
            throw PostProcessingError.invalidResponse
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum PostProcessingError: Error, LocalizedError {
    case apiFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .apiFailed: "Post-processing API call failed"
        case .invalidResponse: "Invalid API response"
        }
    }
}
