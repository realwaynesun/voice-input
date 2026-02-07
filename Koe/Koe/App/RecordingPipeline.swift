import SwiftUI
import Combine
import Foundation

@MainActor
final class RecordingPipeline: ObservableObject {
    private let appState: AppState
    private let audioRecorder = AudioRecorder()
    private let hotkeyManager = HotkeyManager()
    private let overlay = RecordingOverlayController()
    private var whisperEngine: WhisperKitEngine?
    private var cancellables = Set<AnyCancellable>()
    private var durationTimer: Timer?

    private var transcriptionTask: Task<Void, Never>?
    private var activeSessionID: UUID?

    @Published var overlayAudioLevel: Float = 0
    @Published var overlayDuration: TimeInterval = 0

    private var dataStore: DataStore?

    init(appState: AppState) {
        self.appState = appState
        setupHotkey()
        setupAudioLevelMonitor()
    }

    func setDataStore(_ store: DataStore) {
        self.dataStore = store
    }

    func loadEngine() async {
        log("loadEngine() starting (model=\(appState.modelSize.rawValue))")

        let engine = WhisperKitEngine(modelSize: appState.modelSize)
        do {
            try await engine.loadModel()
            whisperEngine = engine
            log("loadEngine() done")
        } catch {
            log("ERROR: loadEngine() failed: \(error)")
            print("Failed to load WhisperKit model: \(error)")
        }
    }

    func requestStopRecording() {
        guard appState.recordingState == .recording,
              let sessionID = activeSessionID
        else { return }

        transcriptionTask?.cancel()
        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            await self.stopRecording(sessionID: sessionID)
        }
    }

    func cancelCurrentWork() {
        log("cancelCurrentWork()")

        activeSessionID = nil

        transcriptionTask?.cancel()
        transcriptionTask = nil

        durationTimer?.invalidate()
        durationTimer = nil

        overlay.dismiss()

        Task {
            _ = await audioRecorder.stopRecording()
        }

        appState.recordingState = .idle
    }

    private func setupHotkey() {
        hotkeyManager.onRecordStart = { [weak self] in
            Task { @MainActor in self?.startRecording() }
        }
        hotkeyManager.onRecordStop = { [weak self] in
            Task { @MainActor in self?.requestStopRecording() }
        }
        hotkeyManager.start()
    }

    private func setupAudioLevelMonitor() {
        Task {
            let publisher = await audioRecorder.audioLevelPublisher
            publisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] level in
                    self?.overlayAudioLevel = level
                    self?.appState.audioLevel = level
                }
                .store(in: &cancellables)
        }
    }

    private func startRecording() {
        guard appState.recordingState == .idle else {
            log("startRecording() ignored; state=\(appState.recordingState)")
            return
        }

        transcriptionTask?.cancel()
        transcriptionTask = nil

        let sessionID = UUID()
        activeSessionID = sessionID
        log("startRecording() session=\(sessionID)")

        SoundFeedback.playStart()
        appState.recordingState = .recording
        overlayDuration = 0

        overlay.show(
            audioLevel: Binding(
                get: { [weak self] in self?.overlayAudioLevel ?? 0 },
                set: { [weak self] in self?.overlayAudioLevel = $0 }
            ),
            duration: Binding(
                get: { [weak self] in self?.overlayDuration ?? 0 },
                set: { [weak self] in self?.overlayDuration = $0 }
            )
        )

        durationTimer = Timer.scheduledTimer(
            withTimeInterval: 0.1,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.overlayDuration += 0.1
            }
        }

        Task {
            let mic = await PermissionChecker.checkMicrophone()
            guard mic == .granted else {
                log("Microphone permission not granted: \(mic)")
                SoundFeedback.playError()
                overlay.dismiss()
                durationTimer?.invalidate()
                durationTimer = nil
                appState.recordingState = .idle
                activeSessionID = nil
                return
            }

            do {
                try await audioRecorder.startRecording()
                log("audioRecorder.startRecording() ok")
            } catch {
                log("ERROR: audioRecorder.startRecording() failed: \(error)")
                SoundFeedback.playError()
                overlay.dismiss()
                durationTimer?.invalidate()
                durationTimer = nil
                appState.recordingState = .idle
                activeSessionID = nil
            }
        }
    }

    private func stopRecording(sessionID: UUID) async {
        guard isSessionActive(sessionID) else {
            log("stopRecording() ignored; session inactive")
            return
        }

        defer {
            if activeSessionID == sessionID {
                activeSessionID = nil
            }
            transcriptionTask = nil
        }

        durationTimer?.invalidate()
        durationTimer = nil
        overlay.dismiss()
        SoundFeedback.playStop()

        let result = await audioRecorder.stopRecording()
        log("stopRecording(): samples=\(result.audio.count) duration=\(result.duration)")

        guard isSessionActive(sessionID) else {
            log("stopRecording(): session cancelled after stop; discarding")
            return
        }

        guard result.audio.count > 8000 else {
            log("stopRecording(): audio too short; returning to idle")
            appState.recordingState = .idle
            return
        }

        appState.recordingState = .transcribing
        appState.recordingDuration = result.duration

        do {
            let backend = appState.transcriptionBackend
            let modelSize = appState.modelSize
            let apiKey = appState.openAIKey
            let language = appState.preferredLanguage.whisperCode
            let localEngine = whisperEngine

            log(
                "transcribe(start): backend=\(backend.rawValue) model=\(modelSize.rawValue) samples=\(result.audio.count)"
            )

            let transcription = try await withTimeout(stage: "Transcribe", seconds: 180) {
                switch backend {
                case .local:
                    guard let localEngine else {
                        throw TranscriptionError.modelNotLoaded
                    }
                    return try await localEngine.transcribe(audio: result.audio, language: language)
                case .api:
                    let engine = APIEngine(apiKey: apiKey)
                    return try await engine.transcribe(audio: result.audio, language: language)
                }
            }

            log(
                "transcribe(done): textChars=\(transcription.text.count) lang=\(transcription.language ?? "-") dur=\(transcription.duration)s"
            )

            guard isSessionActive(sessionID) else {
                log("stopRecording(): session cancelled after transcribe; discarding")
                return
            }

            appState.recordingState = .processing

            let tier = appState.postProcessingTier
            let replacements = dataStore?.enabledReplacements ?? []

            let processed = try await withTimeout(stage: "PostProcess", seconds: 60) {
                switch tier {
                case .none:
                    return transcription.text
                case .ruleBased:
                    let processor = RuleBasedProcessor(
                        customReplacements: replacements
                    )
                    return try await processor.process(
                        transcription.text,
                        language: transcription.language
                    )
                case .api:
                    let ruleProcessor = RuleBasedProcessor(
                        customReplacements: replacements
                    )
                    let cleaned = try await ruleProcessor.process(
                        transcription.text,
                        language: transcription.language
                    )
                    let apiProcessor = APIProcessor(apiKey: apiKey)
                    return try await apiProcessor.process(
                        cleaned,
                        language: transcription.language
                    )
                }
            }

            guard isSessionActive(sessionID) else {
                log("stopRecording(): session cancelled after postProcess; discarding")
                return
            }

            ClipboardManager.copy(processed)
            appState.lastTranscription = processed
            saveRecord(
                text: processed,
                rawText: transcription.text,
                language: transcription.language,
                duration: result.duration
            )

            appState.recordingState = .idle
        } catch {
            if isSessionActive(sessionID) {
                SoundFeedback.playError()
                log("ERROR: stopRecording() pipeline error: \(error)")
                print("Pipeline error: \(error)")
                appState.recordingState = .idle
            } else {
                log("stopRecording(): error after cancel: \(error)")
            }
        }
    }

    private func isSessionActive(_ sessionID: UUID) -> Bool {
        activeSessionID == sessionID && !Task.isCancelled
    }

    private enum PipelineTimeoutError: LocalizedError {
        case timedOut(stage: String, seconds: TimeInterval)

        var errorDescription: String? {
            switch self {
            case let .timedOut(stage, seconds):
                return "\(stage) timed out after \(Int(seconds))s"
            }
        }
    }

    private func withTimeout<T: Sendable>(
        stage: String,
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(
                    nanoseconds: UInt64(seconds * 1_000_000_000)
                )
                throw PipelineTimeoutError.timedOut(
                    stage: stage,
                    seconds: seconds
                )
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func saveRecord(
        text: String,
        rawText: String,
        language: String?,
        duration: TimeInterval
    ) {
        guard let store = dataStore else { return }
        let record = TranscriptionRecord(
            text: text,
            rawText: rawText,
            language: language,
            duration: duration,
            backend: appState.transcriptionBackend.rawValue
        )
        store.addRecord(record)
        store.updateStats(
            duration: duration,
            wordCount: record.wordCount
        )
    }

    private func log(_ msg: String) {
        let line = "[\(Date())] [RecordingPipeline] \(msg)\n"

        // Prefer /tmp for convenience; fall back to a sandbox-safe temp dir.
        let tmpURL = URL(fileURLWithPath: "/tmp/koe-debug.log")
        if append(line, to: tmpURL) { return }

        let fallbackURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("koe-debug.log")
        _ = append(line, to: fallbackURL)
    }

    private func append(_ line: String, to url: URL) -> Bool {
        do {
            let data = Data(line.utf8)
            if FileManager.default.fileExists(atPath: url.path) {
                let fh = try FileHandle(forWritingTo: url)
                defer { try? fh.close() }
                fh.seekToEndOfFile()
                fh.write(data)
            } else {
                try data.write(to: url, options: .atomic)
            }
            return true
        } catch {
            return false
        }
    }

    deinit {
        hotkeyManager.stop()
        durationTimer?.invalidate()
        transcriptionTask?.cancel()
    }
}
