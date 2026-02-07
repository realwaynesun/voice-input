import SwiftUI
import AppKit

final class RecordingOverlayController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<RecordingOverlayContent>?

    func show(audioLevel: Binding<Float>, duration: Binding<TimeInterval>) {
        guard panel == nil else { return }

        let content = RecordingOverlayContent(
            audioLevel: audioLevel,
            duration: duration
        )
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: 200, height: 60)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 60),
            styleMask: [.nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = hosting

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 100
            let y = screenFrame.maxY - 80
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFront(nil)
        self.panel = panel
        self.hostingView = hosting
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
    }
}

struct RecordingOverlayContent: View {
    @Binding var audioLevel: Float
    @Binding var duration: TimeInterval

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
                .opacity(pulseOpacity)
            WaveformView(audioLevel: audioLevel, isRecording: true)
                .frame(height: 32)
            Text(formatDuration(duration))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private var pulseOpacity: Double {
        let phase = Date().timeIntervalSince1970.truncatingRemainder(
            dividingBy: 1.0
        )
        return 0.5 + 0.5 * sin(phase * .pi * 2)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
