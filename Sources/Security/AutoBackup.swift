import Foundation
import SwiftData

/// iCloud Drive 자동 백업.
///
/// 내용이 바뀔 때마다 **암호화된 백업 파일 하나**를 iCloud Drive에 덮어쓴다.
/// 암호화 키는 여전히 이 기기의 Keychain에만 있고, 백업 파일은 **사용자가 정한 비밀번호로 다시 암호화**된다.
/// 그래서 iCloud에 올라간 파일만으로는 애플도, 다른 누구도 내용을 볼 수 없다.
enum AutoBackup {
    static let fileName = "금고곰_백업.geumgogom"
    private static let passwordAccount = "backup.password"
    private static let containerID = "iCloud.com.tonyne.geumgogom"

    // MARK: 설정

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "autoBackupEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "autoBackupEnabled") }
    }

    static var lastBackupAt: Date? {
        get { UserDefaults.standard.object(forKey: "autoBackupAt") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "autoBackupAt") }
    }

    static var password: String? { VaultCrypto.readSecret(account: passwordAccount) }

    static func setPassword(_ value: String) {
        VaultCrypto.storeSecret(value, account: passwordAccount)
    }

    static func clear() {
        isEnabled = false
        lastBackupAt = nil
        VaultCrypto.deleteSecret(account: passwordAccount)
    }

    // MARK: iCloud 위치

    /// iCloud Drive 안의 금고곰 폴더. iCloud에 로그인돼 있지 않으면 nil.
    static var containerURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: containerID)?
            .appendingPathComponent("Documents", isDirectory: true)
    }

    static var backupURL: URL? {
        containerURL?.appendingPathComponent(fileName)
    }

    /// iCloud에 이미 백업이 있는지 (새 기기에서 복원 제안용)
    static func existingBackup() -> URL? {
        guard let url = backupURL else { return nil }
        // 아직 내려받지 않은 상태일 수 있으므로 내려받기를 요청해둔다
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: 실행

    enum BackupError: LocalizedError {
        case notSignedIn, noPassword

        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "iCloud에 로그인되어 있지 않습니다."
            case .noPassword:  return "백업 비밀번호가 설정되지 않았습니다."
            }
        }
    }

    /// 지금 백업한다. 켜져 있지 않으면 아무것도 하지 않는다.
    @discardableResult
    static func runIfEnabled(_ items: [VaultItem]) -> Bool {
        guard isEnabled else { return false }
        return (try? run(items)) != nil
    }

    static func run(_ items: [VaultItem]) throws {
        guard let dir = containerURL else { throw BackupError.notSignedIn }
        guard let password, !password.isEmpty else { throw BackupError.noPassword }

        let payload = BackupService.payload(from: items)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try BackupService.seal(payload, password: password)
        try data.write(to: dir.appendingPathComponent(fileName), options: .atomic)
        lastBackupAt = Date()
    }

    /// 저장·삭제 뒤에 부른다.
    /// 값을 꺼내는 일만 여기서 하고, **무거운 암호화는 백그라운드로 넘긴다.**
    /// (백업 키 파생이 일부러 느리게 설계돼 있어 그대로 두면 저장 버튼이 굳는다)
    /// 실패해도 사용자의 작업을 막지 않는다.
    @MainActor
    static func touch(_ context: ModelContext) {
        guard isEnabled,
              let dir = containerURL,
              let password, !password.isEmpty,
              let items = try? context.fetch(FetchDescriptor<VaultItem>()) else { return }

        let payload = BackupService.payload(from: items)
        Task.detached(priority: .utility) {
            guard let data = try? BackupService.seal(payload, password: password) else { return }
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? data.write(to: dir.appendingPathComponent(fileName), options: .atomic)
            await MainActor.run { lastBackupAt = Date() }
        }
    }
}
