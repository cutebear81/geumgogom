import UIKit

enum ClipboardService {
    /// 복사 후 자동으로 지워지기까지의 시간(초). 0이면 안 지운다.
    static var expirySeconds: TimeInterval {
        get { UserDefaults.standard.object(forKey: "clipboardExpiry") as? TimeInterval ?? 60 }
        set { UserDefaults.standard.set(newValue, forKey: "clipboardExpiry") }
    }

    /// 민감한 값을 클립보드에 넣는다.
    /// - `localOnly`로 유니버설 클립보드(다른 기기로 넘어가는 것)를 막는다.
    /// - `expirationDate`로 지정 시간 뒤 시스템이 알아서 지운다.
    static func copy(_ value: String) {
        var options: [UIPasteboard.OptionsKey: Any] = [.localOnly: true]
        if expirySeconds > 0 {
            options[.expirationDate] = Date().addingTimeInterval(expirySeconds)
        }
        UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: value]], options: options)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
