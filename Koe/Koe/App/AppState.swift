import SwiftUI
import Combine

@Observable
final class AppState {
    enum RecordingState {
        case idle
        case recording
        case transcribing
        case processing
    }

    var recordingState: RecordingState = .idle
    var lastTranscription: String = ""
    var recordingDuration: TimeInterval = 0
    var audioLevel: Float = 0

    var transcriptionBackend: TranscriptionBackend = .local
    var postProcessingTier: PostProcessingTier = .ruleBased
    var modelSize: WhisperModelSize = .small
    var openAIKey: String = ""

    var menuBarIcon: String {
        switch recordingState {
        case .idle: "dot.radiowaves.left.and.right"
        case .recording: "dot.radiowaves.up.forward"
        case .transcribing: "waveform"
        case .processing: "text.badge.checkmark"
        }
    }

    var isRecording: Bool {
        recordingState == .recording
    }
}

enum TranscriptionBackend: String, CaseIterable, Identifiable {
    case local = "Local (WhisperKit)"
    case api = "OpenAI API"

    var id: String { rawValue }
}

enum PostProcessingTier: String, CaseIterable, Identifiable {
    case none = "None"
    case ruleBased = "Rule-based"
    case api = "AI (GPT-4o-mini)"

    var id: String { rawValue }
}

enum WhisperModelSize: String, CaseIterable, Identifiable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case largeV3 = "large-v3"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tiny: "Tiny (~75 MB)"
        case .base: "Base (~142 MB)"
        case .small: "Small (~466 MB)"
        case .medium: "Medium (~1.5 GB)"
        case .largeV3: "Large v3 (~3 GB)"
        }
    }
}
