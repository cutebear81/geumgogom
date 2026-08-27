import SwiftUI
import SwiftData

/// 상세 — 여기서 '꺼내 쓴다'.
/// 값은 기본 마스킹, 탭하면 보인다. 복사는 각 줄 오른쪽 아이콘으로 한다.
struct ItemDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var item: VaultItem
    @State private var revealed: Set<String> = []
    @State private var showEdit = false
    @State private var copied: String?

    private var values: [String: String] { item.values() }
    private var fields: [FieldSpec] { VaultSchema.fields(for: item.category, subtype: item.subtype) }

    var body: some View {
        VStack(spacing: 0) {
            GGHeader(title: item.displayTitle) {
                HStack(spacing: 10) {
                    GGIconButton(system: item.isFavorite ? "star.fill" : "star") {
                        item.isFavorite.toggle(); try? context.save()
                    }
                    GGIconButton(system: "square.and.pencil") { showEdit = true }
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if !addressParts.isEmpty { addressCard }

                    ForEach(fields.filter { !Self.addressKeys.contains($0.key) }) { spec in
                        let raw = values[spec.key] ?? ""
                        if !raw.isEmpty { fieldCard(spec, raw: raw) }
                    }

                    if item.category == .wifi, let ssid = values["ssid"], !ssid.isEmpty {
                        VStack(spacing: 10) {
                            Text("QR 코드")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.subInk)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            WiFiQRView(ssid: ssid,
                                       password: values["password"] ?? "",
                                       security: values["security"] ?? "WPA")
                        }
                        .cardSurface()
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 32)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.bg, for: .navigationBar)
        .sheet(isPresented: $showEdit) { ItemEditView(editing: item) }
        .overlay(alignment: .bottom) {
            if let copied {
                Text("\(copied) 복사")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Theme.dark, in: Capsule())
                    .foregroundStyle(Theme.onDark)
                    .padding(.bottom, 28)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: copied)
    }

    /// 주소를 이루는 칸들. 순서대로 이어 붙인다.
    static let addressKeys = ["province", "district", "road", "address", "detail", "zip"]

    private var addressParts: [String] {
        Self.addressKeys.compactMap { key in
            let v = values[key] ?? ""
            return v.isEmpty ? nil : v
        }
    }

    /// 주소는 쪼개 보여주면 읽기 불편해서 한 줄로 합치고,
    /// 대신 아래에 조각별 복사 버튼을 둔다.
    private var addressCard: some View {
        let full = addressParts.joined(separator: " ")
        return VStack(alignment: .leading, spacing: 10) {
            Text(item.subtype == .business ? "사업장 주소" : "주소")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.subInk)

            HStack(spacing: 12) {
                Text(full)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button { copy(full, label: "주소") } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.orange)
                }
            }

            if addressParts.count > 1 {
                FlowCopyChips(parts: addressParts, minWidth: 150) { copy($0, label: "주소 일부") }
            }
        }
        .cardSurface(padding: 16, radius: 18)
    }

    private func fieldCard(_ spec: FieldSpec, raw: String) -> some View {
        let shown = display(spec, raw: raw)
        let isHidden = spec.sensitive && !revealed.contains(spec.key)

        return VStack(alignment: .leading, spacing: 10) {
            Text(spec.label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.subInk)

            HStack(spacing: 12) {
                Text(isHidden ? masked(spec, raw: raw) : shown)
                    .font(.system(size: 17, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .textSelection(.enabled)
                    .lineLimit(3)

                Spacer(minLength: 4)

                if spec.sensitive {
                    Button {
                        if isHidden { revealed.insert(spec.key) } else { revealed.remove(spec.key) }
                    } label: {
                        Image(systemName: isHidden ? "eye" : "eye.slash")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.subInk)
                    }
                }

                Button {
                    copy(shown, label: spec.label)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.orange)
                }
            }

            // 하이픈으로 나뉘는 번호는 구간별로도 복사할 수 있게 한다
            let segs = segments(spec, raw: raw)
            if segs.count > 1 {
                FlowCopyChips(parts: segs, hideText: true) { copy($0, label: spec.label) }
            }
        }
        .cardSurface(padding: 16, radius: 18)
    }

    private func display(_ spec: FieldSpec, raw: String) -> String {
        switch spec.kind {
        case .cardNumber: return CardFormat.display(raw)
        case .rrn: return IdentityFormat.displayRRN(raw)
        case .bizNumber: return IdentityFormat.displayBiz(raw)
        case .date: return DateFormat.display(raw)
        case .license: return IdentityFormat.displayLicense(raw)
        default: return raw          // 계좌번호는 숫자 그대로
        }
    }

    private func masked(_ spec: FieldSpec, raw: String) -> String {
        switch spec.kind {
        case .cardNumber: return CardFormat.masked(raw)
        case .rrn: return IdentityFormat.maskedRRN(raw)
        case .password, .cvc: return String(repeating: "•", count: raw.count)
        default:
            guard raw.count > 4 else { return String(repeating: "•", count: max(raw.count, 4)) }
            return String(repeating: "•", count: raw.count - 4) + raw.suffix(4)
        }
    }

    private func segments(_ spec: FieldSpec, raw: String) -> [String] {
        spec.kind == .cardNumber ? CardFormat.segments(raw) : [raw]
    }

    private func copy(_ text: String, label: String) {
        ClipboardService.copy(text)
        copied = label
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if copied == label { copied = nil }
        }
    }
}


/// 조각별 복사 칩. 길면 다음 줄로 넘어간다.
struct FlowCopyChips: View {
    let parts: [String]
    /// 글자를 숨기고 버튼만 보일지. 카드번호처럼 가려야 하는 값에 쓴다.
    var hideText: Bool = false
    /// 칩 최소 폭. 주소처럼 긴 값은 넓게 잡아 잘리지 않게 한다.
    var minWidth: CGFloat = 96
    var onCopy: (String) -> Void

    var body: some View {
        FlexibleRows(items: Array(parts.enumerated().map { Chip(index: $0.offset, text: $0.element) }),
                     minWidth: hideText ? 54 : minWidth) { chip in
            Button { onCopy(chip.text) } label: {
                HStack(spacing: 6) {
                    if hideText {
                        Text("\(chip.index + 1)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.subInk)
                    } else {
                        Text(chip.text)
                            .font(.system(size: 13))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.orange)
                }
                .frame(maxWidth: hideText ? .infinity : nil)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Capsule().fill(Theme.bg))
                .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
                .foregroundStyle(Theme.ink)
            }
            .buttonStyle(.plain)
        }
    }

    struct Chip: Hashable { let index: Int; let text: String }
}

/// 조각 칩 배치. 뷰를 그리는 도중 상태를 바꾸는 정렬 트릭 대신
/// 이미 다른 화면에서 쓰는 적응형 그리드를 그대로 쓴다.
struct FlexibleRows<Item: Hashable, Content: View>: View {
    let items: [Item]
    var minWidth: CGFloat = 96
    @ViewBuilder var content: (Item) -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minWidth), spacing: 7)],
                  alignment: .leading, spacing: 7) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                content(item)
            }
        }
    }
}
