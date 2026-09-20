import Foundation
import Security

/// GitHub トークンを Keychain に保存する（UserDefaults に平文で置かない）
struct KeychainStore: Sendable {
    let service: String
    let account: String

    static let gitHubToken = KeychainStore(service: "com.wanto.IssueShot", account: "github-token")

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func write(_ value: String) throws {
        let data = Data(value.utf8)
        let status = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var query = baseQuery
            query[kSecValueData as String] = data
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
        } else if status != errSecSuccess {
            throw KeychainError(status: status)
        }
    }

    func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

struct KeychainError: LocalizedError {
    let status: OSStatus
    var errorDescription: String? {
        let detail = SecCopyErrorMessageString(status, nil) as String? ?? String(localized: "不明")
        return String(localized: "Keychain エラー (\(status)): \(detail)")
    }
}
