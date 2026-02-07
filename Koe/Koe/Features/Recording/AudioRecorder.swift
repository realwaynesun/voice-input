@preconcurrency import AVFoundation
import Combine

actor AudioRecorder {
    private var engine: AVAudioEngine?
    private var buffer: [Float] = []
    private var startTime: Date?
    private let levelSubject = PassthroughSubject<Float, Never>()

    var audioLevelPublisher: AnyPublisher<Float, Never> {
        levelSubject.eraseToAnyPublisher()
    }

    func startRecording() throws {
        buffer = []
        let engine = AVAudioEngine()
        self.engine = engine

        let inputNode = engine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)

        guard hwFormat.sampleRate > 0 else {
            throw RecordingError.noInputDevice
        }

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        guard let converter = AVAudioConverter(
            from: hwFormat,
            to: targetFormat
        ) else {
            throw RecordingError.formatConversionFailed
        }

        inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: hwFormat
        ) { [weak self] pcmBuffer, _ in
            guard let self else { return }
            Task { await self.processBuffer(pcmBuffer, converter: converter) }
        }

        try engine.start()
        startTime = Date()
    }

    func stopRecording() -> RecordingResult {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil

        let duration = startTime.map { Date().timeIntervalSince($0) } ?? 0
        let audio = buffer
        buffer = []
        startTime = nil

        return RecordingResult(audio: audio, duration: duration)
    }

    private func processBuffer(
        _ pcmBuffer: AVAudioPCMBuffer,
        converter: AVAudioConverter
    ) {
        let frameCount = AVAudioFrameCount(
            Double(pcmBuffer.frameLength)
            * 16000.0
            / pcmBuffer.format.sampleRate
        )
        guard frameCount > 0,
              let convertedBuffer = AVAudioPCMBuffer(
                  pcmFormat: converter.outputFormat,
                  frameCapacity: frameCount
              )
        else { return }

        var error: NSError?
        var consumed = false
        converter.convert(to: convertedBuffer, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return pcmBuffer
        }

        guard error == nil,
              let channelData = convertedBuffer.floatChannelData
        else { return }

        let samples = Array(
            UnsafeBufferPointer(
                start: channelData[0],
                count: Int(convertedBuffer.frameLength)
            )
        )
        buffer.append(contentsOf: samples)

        let rms = sqrt(
            samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)
        )
        levelSubject.send(min(1.0, rms * 10))
    }
}

struct RecordingResult {
    let audio: [Float]
    let duration: TimeInterval
}

enum RecordingError: Error, LocalizedError {
    case noInputDevice
    case formatConversionFailed

    var errorDescription: String? {
        switch self {
        case .noInputDevice: "No audio input device found"
        case .formatConversionFailed: "Audio format conversion failed"
        }
    }
}
