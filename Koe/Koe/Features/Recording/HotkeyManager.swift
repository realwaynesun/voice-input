import Cocoa
import Carbon
import ApplicationServices

final class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isOptionPressed = false

    private var permissionRetryTimer: Timer?
    private var permissionRetryAttempts = 0
    private let maxPermissionRetryAttempts = 30

    private var didRequestInputMonitoring = false
    private var didRequestAccessibility = false

    var onRecordStart: (() -> Void)?
    var onRecordStop: (() -> Void)?

    func start() {
        if eventTap != nil {
            log("start() called but event tap already exists")
            return
        }

        let axTrusted = AXIsProcessTrusted()
        let listenTrusted = listenEventAccessGranted()
        let listenDesc = listenTrusted.map { $0 ? "true" : "false" } ?? "n/a"
        log(
            "start() called, AXIsProcessTrusted=\(axTrusted), listenEventAccess=\(listenDesc)"
        )

        if !axTrusted && !didRequestAccessibility {
            didRequestAccessibility = true
            log("Requesting Accessibility permission...")
            PermissionChecker.requestAccessibility()
        }

        if listenTrusted == false && !didRequestInputMonitoring {
            didRequestInputMonitoring = true
            if #available(macOS 10.15, *) {
                log("Requesting Input Monitoring permission (ListenEvent)...")
                let granted = CGRequestListenEventAccess()
                log("CGRequestListenEventAccess() returned \(granted)")
            }
        }

        _ = tryCreateEventTap()

        let permissionsGranted = axTrusted || (listenTrusted ?? false)
        if !permissionsGranted {
            log("Event tap created but permissions missing; scheduling retry")
            schedulePermissionRetryIfNeeded()
        }
    }

    func stop() {
        permissionRetryTimer?.invalidate()
        permissionRetryTimer = nil
        permissionRetryAttempts = 0

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                runLoopSource,
                .commonModes
            )
        }
        eventTap = nil
        runLoopSource = nil
        isOptionPressed = false
    }

    private func listenEventAccessGranted() -> Bool? {
        if #available(macOS 10.15, *) {
            return CGPreflightListenEventAccess()
        }
        return nil
    }

    private func tryCreateEventTap() -> Bool {
        guard eventTap == nil else { return true }

        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = {
            _, type, event, userInfo -> Unmanaged<CGEvent>? in
            guard let userInfo else {
                return Unmanaged.passRetained(event)
            }
            let manager = Unmanaged<HotkeyManager>
                .fromOpaque(userInfo)
                .takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                manager.log(
                    "Event tap disabled (type=\(type.rawValue)); re-enabling"
                )
                if let tap = manager.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passRetained(event)
            }

            manager.handleFlagsChanged(event)
            return Unmanaged.passRetained(event)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else {
            let axTrusted = AXIsProcessTrusted()
            let listenDesc = listenEventAccessGranted().map {
                $0 ? "true" : "false"
            } ?? "n/a"
            log(
                "ERROR: CGEvent.tapCreate returned nil (AX=\(axTrusted), Listen=\(listenDesc))"
            )
            return false
        }
        log("Event tap created OK")

        runLoopSource = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            eventTap,
            0
        )
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            runLoopSource,
            .commonModes
        )
        CGEvent.tapEnable(tap: eventTap, enable: true)
        log("Event tap enabled on main run loop")
        return true
    }

    private func schedulePermissionRetryIfNeeded() {
        guard permissionRetryTimer == nil else { return }

        permissionRetryAttempts = 0
        permissionRetryTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            self.permissionRetryAttempts += 1

            let axTrusted = AXIsProcessTrusted()
            let listenTrusted = self.listenEventAccessGranted() ?? false

            self.log(
                "Retry \(self.permissionRetryAttempts)/\(self.maxPermissionRetryAttempts): AX=\(axTrusted), Listen=\(listenTrusted)"
            )

            if axTrusted || listenTrusted {
                self.recreateEventTap()
                self.log(
                    "Permissions granted after \(self.permissionRetryAttempts) retries; event tap recreated"
                )
                timer.invalidate()
                self.permissionRetryTimer = nil
                self.permissionRetryAttempts = 0
                return
            }

            if self.permissionRetryAttempts >= self.maxPermissionRetryAttempts {
                self.log(
                    "ERROR: Hotkey not active after \(self.maxPermissionRetryAttempts) seconds. Check Input Monitoring / Accessibility permissions, then restart Koe."
                )
                timer.invalidate()
                self.permissionRetryTimer = nil
                self.permissionRetryAttempts = 0
            }
        }
    }

    private func recreateEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                runLoopSource,
                .commonModes
            )
        }
        eventTap = nil
        runLoopSource = nil
        _ = tryCreateEventTap()
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        log("flagsChanged keyCode=\(keyCode) flags=\(flags.rawValue)")

        // Right Option key = keycode 61
        guard keyCode == 61 else { return }

        let optionDown = flags.contains(.maskAlternate)

        if optionDown, !isOptionPressed {
            isOptionPressed = true
            log("Right Option PRESSED -> onRecordStart")
            DispatchQueue.main.async { [weak self] in
                self?.onRecordStart?()
            }
        } else if !optionDown, isOptionPressed {
            isOptionPressed = false
            log("Right Option RELEASED -> onRecordStop")
            DispatchQueue.main.async { [weak self] in
                self?.onRecordStop?()
            }
        }
    }

    private func log(_ msg: String) {
        let line = "[\(Date())] [HotkeyManager] \(msg)\n"

        // Prefer /tmp for convenience; fall back to a sandbox-safe temp dir.
        let tmpURL = URL(fileURLWithPath: "/tmp/koe-debug.log")
        if append(line, to: tmpURL) { return }

        let fallbackURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("koe-debug.log")
        _ = append(line, to: fallbackURL)
    }

    private func append(_ line: String, to url: URL) -> Bool {
        do {
            let data = Data(line.utf8)
            if FileManager.default.fileExists(atPath: url.path) {
                let fh = try FileHandle(forWritingTo: url)
                defer { try? fh.close() }
                fh.seekToEndOfFile()
                fh.write(data)
            } else {
                try data.write(to: url, options: .atomic)
            }
            return true
        } catch {
            return false
        }
    }

    deinit {
        stop()
    }
}
