import Foundation
import LocalAuthentication

/// 앱 잠금.
/// 기본은 **암호(숫자 6자리)**로 연다. Face ID는 설정에서 따로 켜야 쓰인다.
/// 잠금 자체도 설정에서 끌 수 있다.
@MainActor
final class AppLock: ObservableObject {
    @Published private(set) var isLocked: Bool
    @Published var lastError: String?

    init() {
        isLocked = LockSettings.isEnabled
    }

    private var backgroundedAt: Date?

    func enteredBackground() { backgroundedAt = Date() }

    func becameActive() {
        guard LockSettings.isEnabled, let at = backgroundedAt else { return }
        backgroundedAt = nil
        if Date().timeIntervalSince(at) >= LockSettings.autoLockSeconds { isLocked = true }
    }

    func lock() { isLocked = true }
    func unlock() { isLocked = false; lastError = nil }

    /// 설정에서 잠금을 껐다 켰을 때 반영
    func applyLockSetting() {
        isLocked = LockSettings.isEnabled ? isLocked : false
    }

    // MARK: 생체인식 (옵션)

    var biometryLabel: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "생체 인식"
        }
    }

    var isBiometryAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    func unlockWithBiometrics() async {
        guard LockSettings.useBiometrics, isBiometryAvailable else { return }
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "암호 입력"
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                                 localizedReason: "저장한 정보를 열려면 본인 확인이 필요합니다.")
            if ok { unlock() }
        } catch {
            // 대부분 사용자가 취소한 경우다. 오류로 알리지 않고 암호 입력으로 넘긴다.
        }
    }

    // MARK: 암호
    // 암호 원문은 저장하지 않는다. 솔트를 붙여 해시한 값만 비교한다.

    var hasPasscode: Bool { UserDefaults.standard.string(forKey: "passcodeHash") != nil }

    func setPasscode(_ code: String) {
        let salt = UUID().uuidString
        UserDefaults.standard.set(salt, forKey: "passcodeSalt")
        UserDefaults.standard.set(VaultCrypto.passcodeHash(code, salt: salt), forKey: "passcodeHash")
    }

    func verifyPasscode(_ code: String) -> Bool {
        guard let salt = UserDefaults.standard.string(forKey: "passcodeSalt"),
              let stored = UserDefaults.standard.string(forKey: "passcodeHash") else { return false }
        return VaultCrypto.passcodeHash(code, salt: salt) == stored
    }

    @discardableResult
    func unlockWithPasscode(_ code: String) -> Bool {
        guard verifyPasscode(code) else {
            lastError = "암호가 맞지 않습니다."
            return false
        }
        unlock()
        return true
    }
}

enum LockSettings {
    /// 화면 잠금 사용 여부 — 금고 앱이라 기본은 켬
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "lockEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "lockEnabled") }
    }

    /// 생체 인식 사용 여부 — 기본은 끔(기본 진입은 암호)
    static var useBiometrics: Bool {
        get { UserDefaults.standard.bool(forKey: "useBiometrics") }
        set { UserDefaults.standard.set(newValue, forKey: "useBiometrics") }
    }

    static var autoLockSeconds: TimeInterval {
        get { UserDefaults.standard.object(forKey: "autoLockSeconds") as? TimeInterval ?? 0 }
        set { UserDefaults.standard.set(newValue, forKey: "autoLockSeconds") }
    }
}
