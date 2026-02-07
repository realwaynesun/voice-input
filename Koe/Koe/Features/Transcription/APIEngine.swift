import Foundation

final class APIEngine: TranscriptionEngine {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func transcribe(audio: [Float]) async throws -> TranscriptionResult {
        let wavData = encodeWAV(samples: audio, sampleRate: 16000)
        let start = Date()

        let boundary = UUID().uuidString
        var request = URLRequest(
            url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        )
        request.httpMethod = "POST"
        request.setValue(
            "Bearer \(apiKey)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        var body = Data()
        body.appendMultipart(boundary: boundary, name: "model", value: "whisper-1")
        body.appendMultipart(
            boundary: boundary,
            name: "response_format",
            value: "verbose_json"
        )
        body.appendMultipartFile(
            boundary: boundary,
            name: "file",
            filename: "audio.wav",
            contentType: "audio/wav",
            data: wavData
        )
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw APIError.requestFailed
        }

        let json = try JSONDecoder().decode(WhisperAPIResponse.self, from: data)

        return TranscriptionResult(
            text: json.text,
            language: json.language,
            duration: Date().timeIntervalSince(start)
        )
    }

    private func encodeWAV(samples: [Float], sampleRate: Int) -> Data {
        let int16Samples = samples.map { sample -> Int16 in
            let clamped = max(-1.0, min(1.0, sample))
            return Int16(clamped * Float(Int16.max))
        }

        var data = Data()
        let dataSize = int16Samples.count * 2
        let fileSize = 36 + dataSize

        data.append("RIFF".data(using: .ascii)!)
        data.appendLittleEndian(UInt32(fileSize))
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))       // PCM
        data.appendLittleEndian(UInt16(1))       // Mono
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(UInt32(sampleRate * 2))
        data.appendLittleEndian(UInt16(2))       // Block align
        data.appendLittleEndian(UInt16(16))      // Bits per sample
        data.append("data".data(using: .ascii)!)
        data.appendLittleEndian(UInt32(dataSize))

        for sample in int16Samples {
            data.appendLittleEndian(sample)
        }
        return data
    }
}

private struct WhisperAPIResponse: Decodable {
    let text: String
    let language: String?
}

enum APIError: Error, LocalizedError {
    case requestFailed

    var errorDescription: String? {
        "OpenAI API request failed"
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: MemoryLayout<T>.size))
    }

    mutating func appendMultipart(
        boundary: String,
        name: String,
        value: String
    ) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append(
            "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n"
                .data(using: .utf8)!
        )
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipartFile(
        boundary: String,
        name: String,
        filename: String,
        contentType: String,
        data fileData: Data
    ) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append(
            ("Content-Disposition: form-data; name=\"\(name)\";"
             + " filename=\"\(filename)\"\r\n")
                .data(using: .utf8)!
        )
        append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        append(fileData)
        append("\r\n".data(using: .utf8)!)
    }
}
