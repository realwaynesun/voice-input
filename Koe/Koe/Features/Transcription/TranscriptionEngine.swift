import Foundation

protocol TranscriptionEngine {
    func transcribe(audio: [Float], language: String?) async throws -> TranscriptionResult
}

struct TranscriptionResult: Sendable {
    let text: String
    let language: String?
    let duration: TimeInterval
}
