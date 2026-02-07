import Foundation
import WhisperKit

actor WhisperKitEngine: TranscriptionEngine {
    private var whisperKit: WhisperKit?
    private let modelSize: WhisperModelSize

    init(modelSize: WhisperModelSize = .small) {
        self.modelSize = modelSize
    }

    func loadModel() async throws {
        let modelDir = ModelManager.modelsDirectory
        let modelPath = modelDir
            .appendingPathComponent("whisperkit-\(modelSize.rawValue)")

        if FileManager.default.fileExists(atPath: modelPath.path) {
            whisperKit = try await WhisperKit(
                modelFolder: modelPath.path,
                verbose: false
            )
        } else {
            whisperKit = try await WhisperKit(
                model: "openai_whisper-\(modelSize.rawValue)",
                verbose: false
            )
        }
    }

    func transcribe(audio: [Float]) async throws -> TranscriptionResult {
        guard let whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        let start = Date()
        let options = DecodingOptions(
            task: .transcribe,
            language: nil,
            detectLanguage: true
        )
        let results = try await whisperKit.transcribe(
            audioArray: audio,
            decodeOptions: options
        )

        let text = results
            .compactMap(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let language = results.first?.language

        return TranscriptionResult(
            text: text,
            language: language,
            duration: Date().timeIntervalSince(start)
        )
    }
}

enum TranscriptionError: Error, LocalizedError {
    case modelNotLoaded
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: "Whisper model not loaded"
        case .emptyAudio: "No audio data to transcribe"
        }
    }
}
