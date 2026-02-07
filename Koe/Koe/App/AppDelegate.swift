import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    let dataStore = DataStore()

    private(set) var pipeline: RecordingPipeline?
    private var didBootstrap = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        debugLog("applicationDidFinishLaunching")
        appState.openAIKey = KeychainHelper.load(key: "openai_api_key") ?? ""
        bootstrap()
    }

    func bootstrap() {
        guard !didBootstrap else {
            debugLog("bootstrap() skipped (already bootstrapped)")
            return
        }
        didBootstrap = true

        debugLog("bootstrap() called")
        let p = RecordingPipeline(appState: appState)
        p.setDataStore(dataStore)
        pipeline = p
        debugLog("Pipeline created")

        Task {
            debugLog("Loading WhisperKit engine...")
            await p.loadEngine()
            debugLog("Engine loaded")
        }
    }

    func debugLog(_ msg: String) {
        let line = "[\(Date())] \(msg)\n"

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
}
