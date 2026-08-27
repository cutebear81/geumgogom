import SwiftUI

/// 금고곰 디자인 토큰 — 홀짝곰과 같은 톤(미니멀 오프화이트 + 블랙 + 오렌지).
enum Theme {
    static let bg        = Color(hex: "FAF8F4")   // 오프화이트 배경
    static let card      = Color(hex: "FFFFFF")   // 카드
    static let ink       = Color(hex: "1A1A1A")   // 거의 블랙
    static let subInk    = Color(hex: "6B6B6B")   // 보조 텍스트
    static let line      = Color(hex: "ECE8E1")   // 구분선
    static let orange    = Color(hex: "EE6B26")   // 브랜드 오렌지
    static let orangeBg  = Color(hex: "EE6B26").opacity(0.14)   // 아이콘 배지 배경
    static let faint     = Color(hex: "C9C4BB")   // 흐린 요소
    static let dark      = Color(hex: "1A1817")   // 잠금화면
    static let onDark    = Color(hex: "ECEAE4")
    static let onDarkSub = Color(hex: "9A968E")
}

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: UInt64
        switch s.count {
        case 8: (r, g, b, a) = (v >> 24 & 0xFF, v >> 16 & 0xFF, v >> 8 & 0xFF, v & 0xFF)
        case 6: (r, g, b, a) = (v >> 16 & 0xFF, v >> 8 & 0xFF, v & 0xFF, 255)
        default: (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255,
                  blue: Double(b)/255, opacity: Double(a)/255)
    }
}

extension Color {
    /// 배경이 밝으면 검은 글씨, 어두우면 흰 글씨.
    /// 노란 계열(국민·카카오) 위에 흰 글씨를 얹으면 안 보여서 필요하다.
    static func readableText(on hex: String) -> Color {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF), g = Double((v >> 8) & 0xFF), b = Double(v & 0xFF)
        let luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
        return luminance > 0.62 ? Color(hex: "1A1A1A") : .white
    }
}

/// 공통 카드 — 흰 면 + 얇은 라인 (홀짝곰과 동일한 규격)
struct CardSurface: ViewModifier {
    var padding: CGFloat = 14
    var radius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Theme.line, lineWidth: 1))
    }
}

extension View {
    func cardSurface(padding: CGFloat = 14, radius: CGFloat = 16) -> some View {
        modifier(CardSurface(padding: padding, radius: radius))
    }
}

/// 오렌지 배지에 담긴 아이콘 (홀짝곰 설정 행과 같은 모양)
struct IconBadge: View {
    let system: String
    var size: CGFloat = 40
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.orangeBg)
                .frame(width: size, height: size)
            Image(systemName: system)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(Theme.orange)
        }
    }
}

/// 설정·목록에서 쓰는 행 — 왼쪽 아이콘, 가운데 제목·부제, 오른쪽 자리(값·선택창·화살표)
struct SettingRow<Trailing: View>: View {
    let icon: String
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            IconBadge(system: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.subInk)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .cardSurface()
    }
}

/// 화면 상단 콘텐츠 헤더. 로고를 쓰는 화면과 제목만 쓰는 화면을 함께 처리한다.
struct GGHeader<Trailing: View>: View {
    var logo: Bool = false
    var title: String = ""
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center) {
            if logo {
                // 내비바가 아니라 콘텐츠 헤더에 둔다 (iOS 26 원형 유리 배경 회피)
                Image("logo")
                    .resizable().scaledToFit()
                    .frame(height: 30)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.subInk)
                    }
                }
            }
            Spacer()
            trailing
        }
        .frame(height: 72)
        .padding(.horizontal, 16)
    }
}

struct GGIconButton: View {
    let system: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 38, height: 38)
                .background(Theme.card, in: Circle())
                .overlay(Circle().strokeBorder(Theme.line, lineWidth: 1))
        }
    }
}

struct SplashView: View {
    @State private var pop = false
    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 14) {
                // logo 이미지셋: 라이트=logo_b, 다크=logo_w 자동 전환
                Image("logo")
                    .resizable().scaledToFit()
                    .frame(width: 200)
                    .scaleEffect(pop ? 1.0 : 0.85)
                    .opacity(pop ? 1 : 0)
                Text("내 정보를 잠금 뒤에")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.subInk)
                Circle()
                    .fill(Theme.orange)
                    .frame(width: 10, height: 10)
                    .scaleEffect(pop ? 1.2 : 0.8)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { pop = true }
        }
    }
}
