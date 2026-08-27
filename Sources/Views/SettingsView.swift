import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var lock: AppLock
    @Query private var items: [VaultItem]

    @State private var lockEnabled = LockSettings.isEnabled
    @State private var useBiometrics = LockSettings.useBiometrics
    @State private var autoLock = LockSettings.autoLockSeconds
    @State private var clipboard = ClipboardService.expirySeconds
    @State private var autoBackup = AutoBackup.isEnabled
    @State private var showAutoBackupSetup = false
    @State private var backupNote: String?
    @State private var showBackup = false
    @State private var showRestore = false
    @State private var showTips = false
    @State private var showPasscode = false
    @State private var message: String?

    private let contactEmail = "tonyneplanning@gmail.com"

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        lockToggleRow
                        if lockEnabled {
                            passcodeRow
                            if lock.isBiometryAvailable { biometryRow }
                            autoLockRow
                        } else {
                            note("잠금을 끄면 앱을 열자마자 내용이 보입니다.")
                        }

                        Spacer().frame(height: 6)
                        clipboardRow
                        note("복사한 값을 정한 시간 뒤 시스템이 지웁니다. 다른 기기로 넘어가지 않도록 이 기기에만 복사됩니다.")

                        Spacer().frame(height: 6)
                        autoBackupRow
                        if autoBackup, let note = backupNote ?? lastBackupText {
                            note2(note)
                        }
                        backupRow
                        restoreRow
                        note("자동 백업을 켜면 내용이 바뀔 때마다 iCloud Drive에 암호화된 파일 하나가 덮어써집니다. 암호화 키는 이 기기에만 남고, 백업 파일은 따로 정한 비밀번호로 다시 암호화됩니다. 그 비밀번호를 잊으면 복원할 수 없습니다.")

                        Spacer().frame(height: 6)
                        Button { showTips = true } label: {
                            SettingRow(icon: "heart.fill", title: "후원하기",
                                       subtitle: "개발자를 응원해 주세요") { chevron }
                        }
                        .buttonStyle(.plain)
                        Button { sendMail() } label: {
                            SettingRow(icon: "envelope.fill", title: "문의하기",
                                       subtitle: "궁금한 점을 보내주세요") { chevron }
                        }
                        .buttonStyle(.plain)

                        if let message {
                            Text(message).font(.system(size: 12)).foregroundStyle(Theme.subInk)
                        }

                        Text("금고곰 \(appVersion)")
                            .font(.system(size: 12)).foregroundStyle(Theme.subInk)
                            .padding(.top, 10).padding(.bottom, 16)
                    }
                    .padding(.horizontal, 16).padding(.top, 8)
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }.foregroundStyle(Theme.orange)
                }
            }
            .sheet(isPresented: $showTips) { TipJarView() }
            .sheet(isPresented: $showPasscode) { PasscodeSetupView(lock: lock, mode: .change) }
            .sheet(isPresented: $showAutoBackupSetup, onDismiss: {
                autoBackup = AutoBackup.isEnabled
                if autoBackup { runBackupNow() }
            }) {
                AutoBackupSetupView()
            }
            .sheet(isPresented: $showBackup) { BackupSheet(mode: .export, items: items) { message = $0 } }
            .sheet(isPresented: $showRestore) { BackupSheet(mode: .restore, items: items) { message = $0 } }
        }
    }

    // MARK: 행들

    private var lockToggleRow: some View {
        SettingRow(icon: "lock.fill", title: "화면 잠금",
                   subtitle: lockEnabled ? "암호를 넣어야 열립니다" : "꺼져 있습니다") {
            Toggle("", isOn: $lockEnabled)
                .labelsHidden()
                .tint(Theme.orange)
                .onChange(of: lockEnabled) { _, v in
                    LockSettings.isEnabled = v
                    lock.applyLockSetting()
                    if !v { useBiometrics = false; LockSettings.useBiometrics = false }
                }
        }
    }

    private var passcodeRow: some View {
        Button { showPasscode = true } label: {
            SettingRow(icon: "number.square.fill", title: "암호 잠금",
                       subtitle: "여는 데 쓰는 숫자 6자리") { chevron }
        }
        .buttonStyle(.plain)
    }

    private var biometryRow: some View {
        SettingRow(icon: "faceid", title: lock.biometryLabel,
                   subtitle: useBiometrics ? "암호 대신 쓸 수 있습니다" : "꺼두면 암호로만 엽니다") {
            Toggle("", isOn: $useBiometrics)
                .labelsHidden()
                .tint(Theme.orange)
                .onChange(of: useBiometrics) { _, v in LockSettings.useBiometrics = v }
        }
    }

    private var autoLockRow: some View {
        SettingRow(icon: "clock.fill", title: "자동 잠금",
                   subtitle: "앱을 나갔다 돌아왔을 때") {
            Menu {
                Picker("", selection: $autoLock) {
                    Text("즉시").tag(TimeInterval(0))
                    Text("1분 뒤").tag(TimeInterval(60))
                    Text("5분 뒤").tag(TimeInterval(300))
                }
            } label: {
                menuLabel(autoLockText)
            }
            .onChange(of: autoLock) { _, v in LockSettings.autoLockSeconds = v }
        }
    }

    private var clipboardRow: some View {
        SettingRow(icon: "doc.on.clipboard.fill", title: "복사 후 자동 삭제",
                   subtitle: "복사한 값을 지우는 시간") {
            Menu {
                Picker("", selection: $clipboard) {
                    Text("30초").tag(TimeInterval(30))
                    Text("60초").tag(TimeInterval(60))
                    Text("사용 안 함").tag(TimeInterval(0))
                }
            } label: {
                menuLabel(clipboardText)
            }
            .onChange(of: clipboard) { _, v in ClipboardService.expirySeconds = v }
        }
    }

    /// iCloud 자동 백업 — 내용이 바뀔 때마다 암호화된 파일 하나를 iCloud Drive에 덮어쓴다.
    private var autoBackupRow: some View {
        SettingRow(icon: "arrow.triangle.2.circlepath.icloud.fill", title: "iCloud 자동 백업",
                   subtitle: autoBackup ? "바뀔 때마다 저장됩니다" : "꺼져 있습니다") {
            Toggle("", isOn: $autoBackup)
                .labelsHidden()
                .tint(Theme.orange)
                .onChange(of: autoBackup) { _, on in
                    if on {
                        // 켤 때 비밀번호를 먼저 받는다. 그게 백업 파일을 여는 열쇠다.
                        if AutoBackup.password == nil {
                            showAutoBackupSetup = true
                        } else {
                            AutoBackup.isEnabled = true
                            runBackupNow()
                        }
                    } else {
                        AutoBackup.isEnabled = false
                        backupNote = nil
                    }
                }
        }
    }

    private var lastBackupText: String? {
        guard let at = AutoBackup.lastBackupAt else { return "아직 백업된 적이 없습니다." }
        let f = DateFormatter()
        f.dateFormat = "M월 d일 HH:mm"
        return "마지막 백업 \(f.string(from: at))"
    }

    private func runBackupNow() {
        do {
            try AutoBackup.run(items)
            backupNote = nil
        } catch {
            backupNote = error.localizedDescription
            autoBackup = false
            AutoBackup.isEnabled = false
        }
    }

    private func note2(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(text.contains("않") ? Theme.orange : Theme.subInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private var backupRow: some View {
        Button { showBackup = true } label: {
            SettingRow(icon: "square.and.arrow.up.fill", title: "백업 파일 직접 내보내기",
                       subtitle: "따로 보관하고 싶을 때") { chevron }
        }
        .buttonStyle(.plain)
    }

    private var restoreRow: some View {
        Button { showRestore = true } label: {
            SettingRow(icon: "icloud.and.arrow.down.fill", title: "백업에서 복원",
                       subtitle: "iCloud나 저장해둔 파일에서") { chevron }
        }
        .buttonStyle(.plain)
    }

    // MARK: 조각

    private var autoLockText: String {
        switch autoLock {
        case 0: return "즉시"
        case 60: return "1분 뒤"
        default: return "5분 뒤"
        }
    }

    private var clipboardText: String {
        switch clipboard {
        case 0: return "사용 안 함"
        case 30: return "30초"
        default: return "60초"
        }
    }

    private func menuLabel(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.orange)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.subInk)
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.subInk)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.subInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4).padding(.top, 8)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(Theme.subInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private func sendMail() {
        let subject = "[금고곰] 문의"
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:\(contactEmail)?subject=\(encoded)") { openURL(url) }
    }
}

/// 암호 잠금 설정·변경 (여는 데 쓰는 숫자 6자리)
struct PasscodeSetupView: View {
    enum Mode { case initial, change }
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var lock: AppLock
    let mode: Mode
    var onDone: (() -> Void)?

    @State private var current = ""
    @State private var code = ""
    @State private var confirm = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 12) {
                            if mode == .change {
                                field("현재 암호", text: $current)
                                Divider().overlay(Theme.line)
                            }
                            field("새 암호 6자리", text: $code)
                            Divider().overlay(Theme.line)
                            field("한 번 더", text: $confirm)
                        }
                        .cardSurface()

                        if let error {
                            Text(error).font(.system(size: 13)).foregroundStyle(Theme.orange)
                        }

                        Text("암호를 잊으면 저장한 내용을 열 수 없습니다.")
                            .font(.system(size: 11)).foregroundStyle(Theme.subInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)

                        Button(action: submit) {
                            Text(mode == .initial ? "시작하기" : "변경")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Theme.dark, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .foregroundStyle(Theme.onDark)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 16).padding(.top, 10)
                }
            }
            .navigationTitle(mode == .initial ? "암호 잠금" : "암호 변경")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if mode == .change {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("닫기") { dismiss() }.foregroundStyle(Theme.orange)
                    }
                }
            }
        }
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.subInk)
            SecureField("숫자 6자리", text: text)
                .keyboardType(.numberPad)
                .font(.system(size: 17, design: .monospaced))
        }
    }

    private func submit() {
        if mode == .change, !lock.verifyPasscode(current) {
            error = "현재 암호가 맞지 않습니다."; return
        }
        guard code.count == 6, code.allSatisfy(\.isNumber) else {
            error = "숫자 6자리로 정해주세요."; return
        }
        guard code == confirm else { error = "두 번 입력한 암호가 다릅니다."; return }
        lock.setPasscode(code)
        onDone?()
        dismiss()
    }
}
