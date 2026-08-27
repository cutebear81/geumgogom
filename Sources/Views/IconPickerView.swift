import SwiftUI

/// 아이템에 붙일 아이콘 고르기. 고르지 않으면 카테고리 기본 아이콘을 쓴다.
struct IconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: String?
    let fallback: String

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        Button {
                            selected = nil
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                IconBadge(system: fallback, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("기본 아이콘 쓰기")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                    Text("카테고리에 맞는 아이콘이 자동으로 붙습니다")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.subInk)
                                }
                                Spacer()
                                if selected == nil {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Theme.orange)
                                }
                            }
                            .cardSurface()
                        }
                        .buttonStyle(.plain)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: 10)],
                                  spacing: 10) {
                            ForEach(VaultIcons.all, id: \.self) { name in
                                Button {
                                    selected = name
                                    dismiss()
                                } label: {
                                    Image(systemName: name)
                                        .font(.system(size: 19, weight: .semibold))
                                        .foregroundStyle(selected == name ? .white : Theme.orange)
                                        .frame(width: 58, height: 58)
                                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(selected == name ? Theme.orange : Theme.card))
                                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(selected == name ? Color.clear : Theme.line,
                                                          lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 30)
                }
            }
            .navigationTitle("아이콘")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }.foregroundStyle(Theme.orange)
                }
            }
        }
    }
}
