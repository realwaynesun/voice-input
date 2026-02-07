import SwiftUI

struct WaveformView: View {
    let audioLevel: Float
    let isRecording: Bool

    @State private var animationPhase: Double = 0

    private let barCount = 20

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(
                    height: barHeight(for: index),
                    isRecording: isRecording
                )
            }
        }
        .onChange(of: isRecording) { _, active in
            withAnimation(
                active
                    ? .linear(duration: 1).repeatForever(autoreverses: false)
                    : .easeOut(duration: 0.3)
            ) {
                animationPhase = active ? .pi * 2 : 0
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard isRecording else { return 4 }
        let phase = animationPhase + Double(index) * 0.3
        let wave = (sin(phase) + 1) / 2
        let level = CGFloat(max(0.1, min(1.0, audioLevel)))
        return 4 + (28 * level * wave)
    }
}

private struct WaveformBar: View {
    let height: CGFloat
    let isRecording: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(isRecording ? Color.red : Color.secondary.opacity(0.3))
            .frame(width: 4, height: height)
            .animation(.easeInOut(duration: 0.15), value: height)
    }
}
