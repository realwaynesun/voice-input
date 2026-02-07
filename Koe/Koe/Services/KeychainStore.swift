import Foundation
import Security

enum KeychainStore {
    private static var service: String {
        Bundle.main.bundleIdentifier ?? "com.koe.app"
    }

    // MARK: - Public API

    static func loadOpenAIKey() -> String {
        readString(account: "openai_api_key") ?? ""
    }

    static func saveOpenAIKey(_ value: String) {
        if value.isEmpty {
            delete(account: "openai_api_key")
            return
        }

        do {
            try writeString(value, account: "openai_api_key")
        } catch {
            // Avoid crashing; the app can still work with manual entry.
            print("Keychain write failed: \(error)")
        }
    }

    // MARK: - Keychain helpers

    private enum KeychainError: Error {
        case unhandled(OSStatus)
    }

    private static func readString(account: String) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            print("Keychain read failed: status=\(status)")
            return nil
        }

        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func writeString(_ value: String, account: String) throws {
        let data = Data(value.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
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
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandled(addStatus)
            }
            return
        }

        guard updateStatus == errSecSuccess else {
            throw KeychainError.unhandled(updateStatus)
        }
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            print("Keychain delete failed: status=\(status)")
        }
    }
}
