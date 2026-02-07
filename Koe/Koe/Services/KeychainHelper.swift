import Security
import Foundation

enum KeychainHelper {
    private static let service = "com.koe.app"

    @discardableResult
    static func save(key: String, value: String) -> OSStatus {
        guard let data = value.data(using: .utf8) else {
            return errSecParam
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            // Keep it usable even after reboot for agent-style apps.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        )

        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                debugLog(
                    "Keychain save failed (key=\(key)) status=\(addStatus) \(errorString(addStatus))"
                )
            }
            return addStatus
        }

        if updateStatus != errSecSuccess {
            debugLog(
                "Keychain update failed (key=\(key)) status=\(updateStatus) \(errorString(updateStatus))"
            )
        }

        return updateStatus
    }

    static func load(key: String) -> String? {
        loadWithStatus(key: key).value
    }

    static func loadWithStatus(key: String) -> (value: String?, status: OSStatus) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            // Common causes:
            // - errSecItemNotFound: nothing saved yet
            // - errSecAuthFailed / errSecInteractionNotAllowed: Keychain access not granted to this build
            if status != errSecItemNotFound {
                debugLog(
                    "Keychain load failed (key=\(key)) status=\(status) \(errorString(status))"
                )
            }
            return (nil, status)
        }

        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else {
            debugLog("Keychain load returned invalid data (key=\(key))")
            return (nil, errSecDecode)
        }

        return (string, status)
    }

    @discardableResult
    static func delete(key: String) -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            debugLog(
                "Keychain delete failed (key=\(key)) status=\(status) \(errorString(status))"
            )
        }
        return status
    }

    // MARK: - Debug logging (no secrets)

    private static func errorString(_ status: OSStatus) -> String {
        if let s = SecCopyErrorMessageString(status, nil) as String? {
            return "(\(s))"
        }
        return ""
    }

    private static func debugLog(_ msg: String) {
        let line = "[\(Date())] [KeychainHelper] \(msg)\n"

        // Prefer /tmp for convenience; fall back to a sandbox-safe temp dir.
        let tmpURL = URL(fileURLWithPath: "/tmp/koe-debug.log")
        if append(line, to: tmpURL) { return }

        let fallbackURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("koe-debug.log")
        _ = append(line, to: fallbackURL)
    }

    private static func append(_ line: String, to url: URL) -> Bool {
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
}
