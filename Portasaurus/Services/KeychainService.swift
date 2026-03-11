import Foundation
import Security

/// Keychain-backed credential storage, keyed by server URL.
///
/// Passwords are stored as `kSecClassInternetPassword` items.
/// SwiftData is never used for sensitive credentials.
enum KeychainService {

    // MARK: - Errors

    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        case deleteFailed(OSStatus)
        case dataConversionFailed

        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):   "Keychain save failed (OSStatus \(status))."
            case .deleteFailed(let status): "Keychain delete failed (OSStatus \(status))."
            case .dataConversionFailed:     "Failed to convert credential data."
            }
        }
    }

    // MARK: - Public API

    /// Saves `username` and `password` for `serverURL`, replacing any existing entry.
    static func save(username: String, password: String, serverURL: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.dataConversionFailed
        }

        // Delete any existing entry first so we can always use SecItemAdd.
        let deleteQuery: [String: Any] = [
            kSecClass as String:       kSecClassInternetPassword,
            kSecAttrServer as String:  serverURL,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String:       kSecClassInternetPassword,
            kSecAttrServer as String:  serverURL,
            kSecAttrAccount as String: username,
            kSecValueData as String:   passwordData,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    /// Reads credentials for `serverURL`. Returns `nil` when no entry exists.
    static func load(serverURL: String) -> (username: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassInternetPassword,
            kSecAttrServer as String:       serverURL,
            kSecReturnAttributes as String: true,
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let item = result as? [String: Any],
              let username = item[kSecAttrAccount as String] as? String,
              let passwordData = item[kSecValueData as String] as? Data,
              let password = String(data: passwordData, encoding: .utf8)
        else { return nil }

        return (username, password)
    }

    /// Deletes credentials for `serverURL`. Silently succeeds if no entry exists.
    static func delete(serverURL: String) throws {
        let query: [String: Any] = [
            kSecClass as String:      kSecClassInternetPassword,
            kSecAttrServer as String: serverURL,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}
