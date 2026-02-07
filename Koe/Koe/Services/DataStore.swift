import Foundation
import Observation

@Observable
@MainActor
final class DataStore {
    var records: [TranscriptionRecord] = []
    var dictionaryEntries: [DictionaryEntry] = []
    var stats: UsageStats = UsageStats()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private var storageDir: URL {
        let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("Koe")
    }

    private var recordsFile: URL {
        storageDir.appendingPathComponent("records.json")
    }
    private var dictionaryFile: URL {
        storageDir.appendingPathComponent("dictionary.json")
    }
    private var statsFile: URL {
        storageDir.appendingPathComponent("stats.json")
    }

    init() {
        ensureStorageDir()
        loadAll()
    }

    // MARK: - Records

    func addRecord(_ record: TranscriptionRecord) {
        records.insert(record, at: 0)
        saveRecords()
    }

    func deleteRecord(_ record: TranscriptionRecord) {
        records.removeAll { $0.id == record.id }
        saveRecords()
    }

    var sortedRecords: [TranscriptionRecord] {
        records.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Dictionary Entries

    func addDictionaryEntry(_ entry: DictionaryEntry) {
        dictionaryEntries.insert(entry, at: 0)
        saveDictionary()
    }

    func deleteDictionaryEntry(_ entry: DictionaryEntry) {
        dictionaryEntries.removeAll { $0.id == entry.id }
        saveDictionary()
    }

    func updateDictionaryEntry(_ entry: DictionaryEntry) {
        guard let idx = dictionaryEntries.firstIndex(
            where: { $0.id == entry.id }
        ) else { return }
        dictionaryEntries[idx] = entry
        saveDictionary()
    }

    var sortedDictionaryEntries: [DictionaryEntry] {
        dictionaryEntries.sorted { $0.createdAt > $1.createdAt }
    }

    var enabledReplacements: [(String, String)] {
        dictionaryEntries
            .filter(\.isEnabled)
            .map { ($0.trigger, $0.replacement) }
    }

    // MARK: - Stats

    func updateStats(duration: TimeInterval, wordCount: Int) {
        stats.record(duration: duration, wordCount: wordCount)
        saveStats()
    }

    // MARK: - Persistence

    private func ensureStorageDir() {
        try? fileManager.createDirectory(
            at: storageDir,
            withIntermediateDirectories: true
        )
    }

    private func loadAll() {
        records = load(from: recordsFile) ?? []
        dictionaryEntries = load(from: dictionaryFile) ?? []
        stats = load(from: statsFile) ?? UsageStats()
    }

    private func load<T: Decodable>(from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func saveRecords() {
        save(records, to: recordsFile)
    }

    private func saveDictionary() {
        save(dictionaryEntries, to: dictionaryFile)
    }

    private func saveStats() {
        save(stats, to: statsFile)
    }
}
