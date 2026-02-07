import SwiftUI

struct HistoryDetailView: View {
    let record: TranscriptionRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                metadata
                Divider()
                transcriptionText
                if record.text != record.rawText {
                    Divider()
                    rawText
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .toolbar {
            ToolbarItem {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        record.text,
                        forType: .string
                    )
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
        }
    }

    private var metadata: some View {
        HStack(spacing: 16) {
            metadataItem(
                icon: "calendar",
                value: record.createdAt.formatted(
                    .dateTime.month().day().hour().minute()
                )
            )
            metadataItem(
                icon: "timer",
                value: String(format: "%.1fs", record.duration)
            )
            metadataItem(
                icon: "text.word.spacing",
                value: "\(record.wordCount) words"
            )
            if let lang = record.language {
                metadataItem(icon: "globe", value: lang.uppercased())
            }
            metadataItem(icon: "cpu", value: record.backend)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func metadataItem(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(value)
        }
    }

    private var transcriptionText: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcription")
                .font(.headline)
            Text(record.text)
                .font(.body)
                .textSelection(.enabled)
        }
    }

    private var rawText: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Raw (before processing)")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(record.rawText)
                .font(.body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}
