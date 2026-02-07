import Foundation

final class ModelManager: ObservableObject {
    static let modelsDirectory: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("Koe/Models")
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir
    }()

    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false

    func isModelAvailable(_ size: WhisperModelSize) -> Bool {
        let path = Self.modelsDirectory
            .appendingPathComponent("whisperkit-\(size.rawValue)")
        return FileManager.default.fileExists(atPath: path.path)
    }

    func availableModels() -> [WhisperModelSize] {
        WhisperModelSize.allCases.filter { isModelAvailable($0) }
    }
}
