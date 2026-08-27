import Foundation
import CryptoKit
import Security

/// 금고 암호화 계층.
/// 값은 AES-GCM으로 암호화해 저장하고, 키(DEK)는 Keychain에 둔다.
/// 접근 조건은 `WhenUnlockedThisDeviceOnly` — 기기 잠금 해제 상태에서만 읽히고, 백업으로 다른 기기에 복사되지 않는다.
enum VaultCrypto {
    private static let service = "com.tonyne.geumgogom"
    private static let keyAccount = "vault.dek"

    enum CryptoError: Error { case keychain(OSStatus), badPayload }

    // MARK: 키

    /// 저장된 키를 읽고, 없으면 새로 만들어 저장한다.
    static func dataEncryptionKey() throws -> SymmetricKey {
        if let existing = try loadKey() { return existing }
        let key = SymmetricKey(size: .bits256)
        try storeKey(key)
        return key
    }

    private static func loadKey() throws -> SymmetricKey? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var out: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = out as? Data else {
            throw CryptoError.keychain(status)
        }
        return SymmetricKey(data: data)
    }

    private static func storeKey(_ key: SymmetricKey) throws {
        var query = baseQuery()
        query[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw CryptoError.keychain(status) }
    }

    private static func baseQuery() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: keyAccount]
    }

    // MARK: 값

    static func seal(_ plaintext: String) throws -> Data {
        let key = try dataEncryptionKey()
        let box = try AES.GCM.seal(Data(plaintext.utf8), using: key)
        guard let combined = box.combined else { throw CryptoError.badPayload }
        return combined
    }

    static func open(_ ciphertext: Data) throws -> String {
        let key = try dataEncryptionKey()
        let box = try AES.GCM.SealedBox(combined: ciphertext)
        let data = try AES.GCM.open(box, using: key)
        guard let s = String(data: data, encoding: .utf8) else { throw CryptoError.badPayload }
        return s
    }
}

extension VaultCrypto {
    /// 암호 검증용 해시. 원문은 어디에도 저장하지 않는다.
    static func passcodeHash(_ code: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data((salt + code).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}


extension VaultCrypto {
    /// 임의의 비밀 문자열을 Keychain 에 넣고 뺀다. (백업 비밀번호 보관용)
    /// 접근 조건은 데이터 키와 같다 — 이 기기에서 잠금이 풀렸을 때만 읽힌다.
    static func storeSecret(_ value: String, account: String) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.tonyne.geumgogom",
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = Data(value.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    static func readSecret(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.tonyne.geumgogom",
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteSecret(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.tonyne.geumgogom",
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
