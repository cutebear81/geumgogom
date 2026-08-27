import Foundation
import CryptoKit
import CommonCrypto

/// 암호화 백업 파일 내보내기·복원.
///
/// 기기 안의 암호화 키는 이 기기에서만 읽히므로, 백업은 **사용자가 정한 비밀번호로 다시 암호화**한다.
/// 파일을 iCloud Drive에 두면 그대로 iCloud 백업이 되고, 애플도 내용을 볼 수 없다.
enum BackupService {
    static let fileExtension = "geumgogom"

    struct Payload: Codable {
        var version = 1
        var exportedAt = Date()
        var items: [Item]
        struct Item: Codable {
            var category: String
            var subtype: String?
            var title: String
            var formatHint: String?
            var isFavorite: Bool
            var values: [String: String]
        }
    }

    struct Envelope: Codable {
        var salt: Data
        var sealed: Data
        var rounds: Int
    }

    enum BackupError: Error { case wrongPassword, corrupted, keyDerivation }

    // MARK: 비밀번호 → 키

    private static let defaultRounds = 200_000

    /// PBKDF2로 비밀번호를 늘려 키를 만든다. 반복 횟수를 파일에 같이 적어 나중에 올려도 복원되게 한다.
    static func deriveKey(password: String, salt: Data, rounds: Int) throws -> SymmetricKey {
        var out = [UInt8](repeating: 0, count: 32)
        let pwd = Array(password.utf8)
        let saltBytes = [UInt8](salt)
        let status = saltBytes.withUnsafeBufferPointer { saltPtr in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2), pwd, pwd.count,
                saltPtr.baseAddress, saltBytes.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(rounds),
                &out, out.count)
        }
        guard status == kCCSuccess else { throw BackupError.keyDerivation }
        return SymmetricKey(data: Data(out))
    }

    // MARK: 내보내기 / 복원

    /// 모델에서 값을 꺼내 payload 로 만든다. SwiftData 객체를 만지므로 **메인에서** 부른다.
    static func payload(from items: [VaultItem]) -> Payload {
        Payload(items: items.map {
            .init(category: $0.categoryRaw, subtype: $0.subtypeRaw, title: $0.title,
                  formatHint: $0.formatHint, isFavorite: $0.isFavorite, values: $0.values())
        })
    }

    static func export(_ items: [VaultItem], password: String) throws -> Data {
        try seal(payload(from: items), password: password)
    }

    /// 암호화만 한다. 키 파생(PBKDF2)이 무거우므로 백그라운드에서 불러도 된다.
    static func seal(_ payload: Payload, password: String) throws -> Data {
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }

        let key = try deriveKey(password: password, salt: salt, rounds: defaultRounds)
        let box = try AES.GCM.seal(try JSONEncoder().encode(payload), using: key)
        guard let sealed = box.combined else { throw BackupError.corrupted }
        return try JSONEncoder().encode(Envelope(salt: salt, sealed: sealed, rounds: defaultRounds))
    }

    static func restore(_ data: Data, password: String) throws -> Payload {
        guard let env = try? JSONDecoder().decode(Envelope.self, from: data) else {
            throw BackupError.corrupted
        }
        let key = try deriveKey(password: password, salt: env.salt, rounds: env.rounds)
        guard let box = try? AES.GCM.SealedBox(combined: env.sealed),
              let opened = try? AES.GCM.open(box, using: key) else {
            // 복호화 실패는 거의 언제나 비밀번호가 틀린 경우다.
            throw BackupError.wrongPassword
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: opened) else {
            throw BackupError.corrupted
        }
        return payload
    }
}
