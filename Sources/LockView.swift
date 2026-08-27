import SwiftUI

/// 잠금 화면. 금고를 여는 느낌이라 이 화면만 다크로 간다.
struct LockView: View {
    @ObservedObject var lock: AppLock
    @State private var code = ""
    @State private var shake = false

    var body: some View {
        ZStack {
            Theme.dark.ignoresSafeArea()
            VStack(spacing: 26) {
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.orange)
                Text("금고곰")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Theme.onDark)

                dots
                    .offset(x: shake ? -8 : 0)
                    .animation(.default.repeatCount(3, autoreverses: true).speed(4), value: shake)

                if let msg = lock.lastError {
                    Text(msg)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.orange)
                }

                keypad

                if LockSettings.useBiometrics && lock.isBiometryAvailable {
                    Button {
                        Task { await lock.unlockWithBiometrics() }
                    } label: {
                        Label("\(lock.biometryLabel)로 열기", systemImage: "faceid")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.onDarkSub)
                    }
                }
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 40)
        }
        .task {
            if LockSettings.useBiometrics { await lock.unlockWithBiometrics() }
        }
    }

    private var dots: some View {
        HStack(spacing: 16) {
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(i < code.count ? Theme.orange : Theme.onDarkSub.opacity(0.3))
                    .frame(width: 12, height: 12)
            }
        }
    }

    private var keypad: some View {
        VStack(spacing: 16) {
            ForEach([["1","2","3"], ["4","5","6"], ["7","8","9"], ["", "0", "⌫"]], id: \.self) { row in
                HStack(spacing: 24) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear.frame(width: 66, height: 60)
        } else {
            Button {
                tap(key)
            } label: {
                Text(key)
                    .font(.system(size: key == "⌫" ? 22 : 26, weight: .medium))
                    .foregroundStyle(Theme.onDark)
                    .frame(width: 66, height: 60)
            }
        }
    }

    private func tap(_ key: String) {
        lock.lastError = nil
        if key == "⌫" {
            if !code.isEmpty { code.removeLast() }
            return
        }
        guard code.count < 6 else { return }
        code.append(key)
        guard code.count == 6 else { return }
        if !lock.unlockWithPasscode(code) {
            shake.toggle()
            code = ""
        }
    }
}
