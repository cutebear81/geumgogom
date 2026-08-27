import SwiftUI

/// 자동 백업을 켤 때 받는 백업 비밀번호.
/// 이 비밀번호가 iCloud에 올라간 백업 파일을 여는 유일한 열쇠다.
struct AutoBackupSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirm = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 12) {
                            field("백업 비밀번호", text: $password)
                            Divider().overlay(Theme.line)
                            field("한 번 더", text: $confirm)
                        }
                        .cardSurface()

                        if let error {
                            Text(error).font(.system(size: 13)).foregroundStyle(Theme.orange)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            bullet("내용이 바뀔 때마다 iCloud Drive에 자동으로 저장됩니다.")
                            bullet("백업 파일은 이 비밀번호로 암호화됩니다. 애플도 열 수 없습니다.")
                            bullet("암호화 키는 이 기기에만 남습니다. iCloud로 나가지 않습니다.")
                            bullet("새 기기에서는 이 비밀번호를 넣어야 복원됩니다. 잊으면 되돌릴 방법이 없습니다.")
                        }
                        .cardSurface()

                        Button(action: submit) {
                            Text("자동 백업 켜기")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(password.count < 4 ? Theme.faint : Theme.dark,
                                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .foregroundStyle(Theme.onDark)
                        }
                        .disabled(password.count < 4)
                    }
                    .padding(.horizontal, 16).padding(.top, 10)
                }
            }
            .navigationTitle("자동 백업")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }.foregroundStyle(Theme.orange)
                }
            }
        }
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.subInk)
            SecureField("4자 이상", text: text).font(.system(size: 16))
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Theme.orange).frame(width: 5, height: 5).padding(.top, 6)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Theme.subInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func submit() {
        guard password == confirm else { error = "두 번 입력한 비밀번호가 다릅니다."; return }
        guard AutoBackup.containerURL != nil else {
            error = "iCloud에 로그인되어 있지 않습니다. 설정에서 iCloud Drive를 켜주세요."
            return
        }
        AutoBackup.setPassword(password)
        AutoBackup.isEnabled = true
        dismiss()
    }
}
