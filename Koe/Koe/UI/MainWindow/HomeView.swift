import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(DataStore.self) private var dataStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                statsGrid
                recentTranscriptions
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Speak naturally, write perfectly")
                .font(.title)
                .fontWeight(.bold)
            HStack(spacing: 4) {
                Text("Hold")
                    .foregroundStyle(.secondary)
                KeyboardShortcutBadge(text: "Right Option")
                Text("to record, release to transcribe")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ],
            spacing: 12
        ) {
            StatCard(
                icon: "clock",
                value: formatDuration(dataStore.stats.totalDictationSeconds),
                label: "Total dictation time"
            )
            StatCard(
                icon: "mic.fill",
                value: "\(dataStore.stats.totalWords)",
                label: "Words dictated"
            )
            StatCard(
                icon: "hourglass",
                value: formatDuration(dataStore.stats.estimatedTimeSavedSeconds),
                label: "Time saved"
            )
            StatCard(
                icon: "bolt.fill",
                value: "\(dataStore.stats.averageWPM)",
                label: "Average WPM",
                iconColor: .orange
            )
            StatCard(
                icon: "number",
                value: "\(dataStore.stats.totalSessions)",
                label: "Total sessions",
                iconColor: .purple
            )
            StatCard(
                icon: "globe",
                value: dominantLanguage,
                label: "Primary language",
                iconColor: .green
            )
        }
    }

    private var recentTranscriptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.headline)

            if dataStore.records.isEmpty {
                emptyState
            } else {
                ForEach(dataStore.sortedRecords.prefix(5)) { record in
                    RecentRecordRow(record: record)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "mic.slash")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No transcriptions yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Hold Right Option and start speaking")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var dominantLanguage: String {
        let langs = dataStore.sortedRecords.compactMap(\.language)
        guard !langs.isEmpty else { return "--" }
        let counts = Dictionary(grouping: langs) { $0 }
            .mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key ?? "--"
    }

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 1 { return "\(Int(seconds))s" }
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

private struct RecentRecordRow: View {
    let record: TranscriptionRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.text)
                    .lineLimit(1)
                    .font(.body)
                HStack(spacing: 8) {
                    if let lang = record.language {
                        Text(lang.uppercased())
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                    Text(record.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(record.wordCount) words")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
