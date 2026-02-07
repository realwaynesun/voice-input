import AVFoundation
import ApplicationServices

enum PermissionStatus {
    case granted
    case denied
    case notDetermined
}

struct PermissionChecker {
    static func checkMicrophone() async -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            return granted ? .granted : .denied
        @unknown default: return .notDetermined
        }
    }

    static func checkAccessibility() -> PermissionStatus {
        AXIsProcessTrusted() ? .granted : .denied
    }

    static func requestAccessibility() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true
        ] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
