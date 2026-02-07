import AppKit

enum ClipboardManager {
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    static func pasteToActiveApp() {
        let src = CGEventSource(stateID: .combinedSessionState)

        let keyDown = CGEvent(
            keyboardEventSource: src,
            virtualKey: 0x09, // V key
            keyDown: true
        )
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(
            keyboardEventSource: src,
            virtualKey: 0x09,
            keyDown: false
        )
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
