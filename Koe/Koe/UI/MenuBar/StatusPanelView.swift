import SwiftUI

struct StatusPanelView: View {
    let appState: AppState
    let onOpenDashboard: () -> Void
    let onStopRecording: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusHeader
            if !appState.lastTranscription.isEmpty {
                lastTranscriptionPreview
            }
            Divider()
            hotkeyHint
            Divider()
            menuActions
        }
        .padding(8)
        .frame(width: 280)
    }

    private var statusHeader: some View {
        HStack {
            Image(systemName: appState.menuBarIcon)
                .foregroundStyle(statusColor)
            Text(statusText)
                .font(.headline)
            Spacer()
        }
    }

    private var lastTranscriptionPreview: some View {
        Text(appState.lastTranscription)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var hotkeyHint: some View {
        HStack(spacing: 4) {
            Text("Hold")
                .font(.caption)
                .foregroundStyle(.secondary)
            KeyboardShortcutBadge(text: "Right Option")
            Text("to record")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var menuActions: some View {
        VStack(spacing: 2) {
            Button("Open Dashboard") { onOpenDashboard() }
            if appState.isRecording {
                Button("Stop Recording") { onStopRecording() }
            } else if appState.recordingState != .idle {
                Button("Cancel") { onCancel() }
            }
            Divider()
            Button("Quit Koe") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private var statusColor: Color {
        switch appState.recordingState {
        case .idle: .secondary
        case .recording: .red
        case .transcribing: .orange
        case .processing: .blue
        }
    }

    private var statusText: String {
        switch appState.recordingState {
        case .idle: "Ready"
        case .recording: "Recording..."
        case .transcribing: "Transcribing..."
        case .processing: "Processing..."
        }
    }
}

struct KeyboardShortcutBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
