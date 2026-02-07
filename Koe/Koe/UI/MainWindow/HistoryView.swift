import SwiftUI

struct HistoryView: View {
    @Environment(DataStore.self) private var dataStore

    @State private var searchText = ""
    @State private var selectedRecord: TranscriptionRecord?

    private var filtered: [TranscriptionRecord] {
        let sorted = dataStore.sortedRecords
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter {
            $0.text.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        HSplitView {
            recordList
                .frame(minWidth: 300)
            detailPanel
                .frame(minWidth: 300)
        }
        .searchable(text: $searchText, prompt: "Search transcriptions")
    }

    private var recordList: some View {
        List(filtered, selection: $selectedRecord) { record in
            HistoryRow(record: record)
                .tag(record)
                .contextMenu {
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(
                            record.text,
                            forType: .string
                        )
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        dataStore.deleteRecord(record)
                        if selectedRecord == record {
                            selectedRecord = nil
                        }
                    }
                }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .overlay {
            if dataStore.records.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock",
                    description: Text("Transcriptions will appear here")
                )
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private var detailPanel: some View {
        Group {
            if let record = selectedRecord {
                HistoryDetailView(record: record)
            } else {
                ContentUnavailableView(
                    "Select a transcription",
                    systemImage: "text.quote"
                )
            }
        }
    }
}

private struct HistoryRow: View {
    let record: TranscriptionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.text)
                .lineLimit(2)
                .font(.body)
            HStack(spacing: 8) {
                if let lang = record.language {
                    Text(lang.uppercased())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
                Text("\(record.wordCount) words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(record.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
