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

    func transcribe(audio: [Float], language: String?) async throws -> TranscriptionResult {
        guard let whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        let start = Date()
        let promptTokens = encodePrompt(Self.multilingualPrompt)
        let options = buildOptions(language: language, promptTokens: promptTokens)
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

    private static let multilingualPrompt =
        "这个project要refactor，この部分はまだ完成していない。请用TypeScript来implement。"

    private func encodePrompt(_ text: String) -> [Int]? {
        whisperKit?.tokenizer?.encode(text: text).map { Int($0) }
    }

    private func buildOptions(language: String?, promptTokens: [Int]?) -> DecodingOptions {
        DecodingOptions(
            task: .transcribe,
            language: language,
            detectLanguage: language == nil,
            promptTokens: promptTokens,
            suppressBlank: true,
            compressionRatioThreshold: 2.4,
            noSpeechThreshold: 0.6,
            chunkingStrategy: .vad
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
