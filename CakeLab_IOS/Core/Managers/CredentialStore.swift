import Foundation
import Security

// MARK: - Secure Credential Store
/// Stores and retrieves login passwords in Keychain using the email as account key.
final class CredentialStore {
    private let service = "com.cakelab.auth.credentials"

    func save(email: String, password: String) throws {
        let account = normalized(email)
        let data = Data(password.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CredentialStoreError.saveFailed(status)
        }
    }

    func password(for email: String) throws -> String {
        let account = normalized(email)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess else {
            throw CredentialStoreError.readFailed(status)
        }

        guard let data = item as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw CredentialStoreError.invalidData
        }

        return password
    }

    func hasPassword(for email: String) -> Bool {
        (try? password(for: email)) != nil
    }

    func delete(email: String) {
        let account = normalized(email)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }

    private func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum CredentialStoreError: LocalizedError {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Could not save credentials. Keychain status: \(status)."
        case .readFailed(let status):
            return "Could not read saved credentials. Keychain status: \(status)."
        case .invalidData:
            return "Saved credentials are corrupted. Please sign in again."
        }
    }
}
