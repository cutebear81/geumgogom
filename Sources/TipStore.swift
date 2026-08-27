import Foundation
import StoreKit

/// 후원(소모성 IAP) 3종. 토니네 앱 공통 구조.
@MainActor
final class TipStore: ObservableObject {
    static let ids = ["com.tonyne.geumgogom.tip.icecream",
                      "com.tonyne.geumgogom.tip.coffee",
                      "com.tonyne.geumgogom.tip.meal"]

    /// 이름과 설명은 앱에서 직접 한글로 쓴다.
    /// 스토어에서 받아오는 값은 기기 언어 설정에 따라 영문으로 내려올 수 있어서다. 가격만 스토어 값을 쓴다.
    static func label(for id: String) -> (emoji: String, name: String, detail: String) {
        if id.hasSuffix("icecream") { return ("🍦", "아이스크림 한 개", "가볍게 응원해요") }
        if id.hasSuffix("coffee")   { return ("☕️", "커피 한 잔", "고맙습니다") }
        return ("🍚", "든든한 한 끼", "큰 힘이 됩니다")
    }

    @Published var products: [Product] = []
    @Published var thanks = false
    @Published var failed = false

    func load() async {
        guard products.isEmpty else { return }
        products = ((try? await Product.products(for: Self.ids)) ?? [])
            .sorted { $0.price < $1.price }
    }

    func buy(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    thanks = true
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            failed = true
        }
    }
}
