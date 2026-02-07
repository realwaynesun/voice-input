import AppKit

enum SoundFeedback {
    static func playStart() {
        NSSound(named: "Blow")?.play()
    }

    static func playStop() {
        NSSound(named: "Pop")?.play()
    }

    static func playError() {
        NSSound(named: "Basso")?.play()
    }
}
