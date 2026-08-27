import SwiftUI

struct OnboardingView: View {
    @AppStorage("didOnboard") private var didOnboard = false
    @ObservedObject var lock: AppLock
    @State private var showPasscode = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "lock.square.stack.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(Theme.orange)
                        Text("금고곰")
                            .font(.system(size: 30, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                        Text("카드·계좌·통관부호·주소·와이파이 비번처럼\n매번 찾아 헤매는 내 정보를 잠금 뒤에 넣어둡니다.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.subInk)
                    }
                    .padding(.top, 40)

                    VStack(spacing: 12) {
                        point("서버가 없습니다", "정보는 이 기기 안에서 암호화되어 보관되고, 밖으로 나가지 않습니다.")
                        point("잠금 뒤에 둡니다", "암호로 열립니다. Face ID는 설정에서 켜면 함께 쓸 수 있습니다.")
                        point("복사는 잠깐만", "복사한 값은 정해진 시간 뒤 자동으로 지워집니다.")
                    }

                    Button { showPasscode = true } label: {
                        Text("암호 정하고 시작하기")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Theme.dark))
                            .foregroundStyle(Theme.onDark)
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showPasscode) {
            PasscodeSetupView(lock: lock, mode: .initial) {
                didOnboard = true
                lock.unlock()
            }
        }
    }

    private func point(_ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Theme.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(body)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.subInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .cardSurface(padding: 16, radius: 18)
    }
}
