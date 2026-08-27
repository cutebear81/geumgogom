import SwiftUI
import StoreKit

struct TipJarView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = TipStore()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("금고곰은 광고도 없고, 정보를 밖으로 보내지도 않습니다.\n마음에 드셨다면 개발을 응원해 주세요.")
                        .font(.footnote)
                        .foregroundStyle(Theme.subInk)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    if store.products.isEmpty {
                        ProgressView().padding(.top, 40)
                    }

                    ForEach(store.products, id: \.id) { product in
                        Button {
                            Task { await store.buy(product) }
                        } label: {
                            let label = TipStore.label(for: product.id)
                            HStack(spacing: 14) {
                                Text(label.emoji).font(.system(size: 26))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(label.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                    Text(label.detail)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.subInk)
                                }
                                Spacer()
                                Text(product.displayPrice)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.orange)
                            }
                            .cardSurface()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("후원하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() }.foregroundStyle(Theme.orange) } }
            .task { await store.load() }
            .alert("고맙습니다", isPresented: $store.thanks) {
                Button("닫기", role: .cancel) {}
            } message: {
                Text("덕분에 계속 만들 수 있습니다.")
            }
            .alert("결제하지 못했습니다", isPresented: $store.failed) {
                Button("확인", role: .cancel) {}
            }
        }
    }

}
