import SwiftUI
import SwiftData

/// 추가·수정. 카테고리(그리고 유형)를 고르면 입력칸이 스키마대로 바뀐다.
struct ItemEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var editing: VaultItem?
    var presetCategory: VaultCategory?

    @State private var category: VaultCategory = .card
    @State private var subtype: VaultSubtype?
    @State private var title = ""
    @State private var values: [String: String] = [:]
    @State private var iconName: String?
    @State private var showIconPicker = false
    @State private var saveError: String?
    @State private var showScanner = false
    @State private var scanNote: String?
    /// 기관 입력칸에서 지금 후보 목록을 펼쳐놓은 필드
    @State private var openPicker: String?


    private var fields: [FieldSpec] { VaultSchema.fields(for: category, subtype: subtype) }

    /// 별칭은 선택이므로, 값이 하나라도 들어있으면 저장할 수 있다.
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            || values.values.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    categoryCard
                    titleCard
                    ForEach(fields) { spec in fieldCard(spec) }
                    if let scanNote {
                        Text(scanNote)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.subInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                    if let saveError {
                        Text(saveError).font(.system(size: 13)).foregroundStyle(Theme.orange)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 32)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle(editing == nil ? "추가" : "수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: load)
            .fullScreenCover(isPresented: $showScanner) {
                ScanView { lines in applyScan(lines) }.ignoresSafeArea()
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(selected: $iconName, fallback: category.icon)
            }

        }
    }

    // MARK: 카드들

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("종류").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.subInk)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                ForEach(VaultCategory.allCases) { c in
                    Button { pick(c) } label: {
                        Label(c.title, systemImage: c.icon)
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(category == c ? Theme.orange : Theme.bg))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Theme.line, lineWidth: category == c ? 0 : 1))
                            .foregroundStyle(category == c ? .white : Theme.ink)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !category.subtypes.isEmpty {
                HStack(spacing: 8) {
                    ForEach(category.subtypes) { s in
                        Button { pick(subtype: s) } label: {
                            Text(s.title)
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Capsule().fill(subtype == s ? Theme.orangeBg : Theme.bg))
                                .overlay(Capsule().strokeBorder(Theme.line, lineWidth: subtype == s ? 0 : 1))
                                .foregroundStyle(Theme.ink)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .cardSurface()
    }

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("별칭").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.subInk)
                Text("선택")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.bg))
                    .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
                    .foregroundStyle(Theme.subInk)
                Spacer()
                if ScanAvailability.isSupported {
                    Button { showScanner = true } label: {
                        Label("촬영해서 채우기", systemImage: "camera.viewfinder")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.orange)
                    }
                }
            }
            HStack(spacing: 12) {
                Button { showIconPicker = true } label: {
                    ZStack(alignment: .bottomTrailing) {
                        IconBadge(system: iconName ?? category.icon, size: 44)
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.orange)
                            .background(Circle().fill(Theme.card))
                            .offset(x: 4, y: 4)
                    }
                }
                .buttonStyle(.plain)

                TextField("예: 생활비 카드", text: $title)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.ink)
            }
            Text("비워두면 \(fallbackTitleHint)이 목록에 보입니다. 번호는 넣지 마세요.")
                .font(.system(size: 11)).foregroundStyle(Theme.subInk)
        }
        .cardSurface()
    }

    private func fieldCard(_ spec: FieldSpec) -> some View {
        let binding = Binding(get: { values[spec.key] ?? "" }, set: { values[spec.key] = $0 })
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(spec.label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.subInk)
                if spec.optional {
                    Text("선택")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Theme.bg))
                        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
                        .foregroundStyle(Theme.subInk)
                }
            }

            inputField(spec, binding: binding)
            hint(spec, text: binding.wrappedValue)
        }
        .cardSurface()
    }

    @ViewBuilder
    private func inputField(_ spec: FieldSpec, binding: Binding<String>) -> some View {
        switch spec.kind {
        case .multiline:
            TextEditor(text: binding)
                .frame(minHeight: 100)
                .font(.system(size: 15))
                .scrollContentBackground(.hidden)
        case .account, .cardNumber, .number, .cvc, .rrn, .password, .bizNumber, .license, .date:
            TextField(spec.placeholder, text: binding)
                .keyboardType(.numberPad)
                .font(.system(size: 16, design: .monospaced))
        case .customs, .passport, .vehicle:
            TextField(spec.placeholder, text: binding)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 16, design: .monospaced))
        case .cardIssuer, .bank:
            institutionField(spec, binding: binding)
        case .province:
            listPickerField(spec, binding: binding, options: Regions.provinces)
        case .district:
            listPickerField(spec, binding: binding,
                            options: Regions.districts(of: values["province"] ?? ""),
                            emptyHint: "시·도를 먼저 고르세요")
        default:
            TextField(spec.placeholder, text: binding).font(.system(size: 16))
        }
    }

    /// 목록에서 고르는 칸(시·도, 시·군·구).
    /// 전부 앱 안에 있는 목록이라 통신하지 않는다. 글자를 치면 좁혀진다.
    @ViewBuilder
    private func listPickerField(_ spec: FieldSpec, binding: Binding<String>,
                                 options: [String], emptyHint: String? = nil) -> some View {
        let isOpen = openPicker == spec.key
        let candidates = Regions.search(binding.wrappedValue, in: options)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField(options.isEmpty ? (emptyHint ?? "") : "고르거나 입력하세요",
                          text: binding)
                    .font(.system(size: 16))
                    .disabled(options.isEmpty)
                    .onChange(of: binding.wrappedValue) { _, _ in openPicker = spec.key }
                if !binding.wrappedValue.isEmpty {
                    Button { binding.wrappedValue = ""; openPicker = spec.key } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.faint)
                    }
                }
                if !options.isEmpty {
                    Button { openPicker = isOpen ? nil : spec.key } label: {
                        Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.subInk)
                    }
                }
            }

            if isOpen && !candidates.isEmpty {
                FlowChips(items: candidates, selected: binding.wrappedValue) { name in
                    binding.wrappedValue = name
                    // 시·도를 바꾸면 이전 시·군·구는 맞지 않으므로 비운다.
                    if spec.kind == .province { values["district"] = "" }
                    openPicker = nil
                }
            }
        }
    }

    /// 카드사·은행 — 글자를 칠 때마다 아래에 후보가 나오고, 눌러서 고른다.
    @ViewBuilder
    private func institutionField(_ spec: FieldSpec, binding: Binding<String>) -> some View {
        let list = spec.kind == .bank ? Institutions.banks : Institutions.cardIssuers
        let recentKey = spec.kind == .bank ? "recentBanks" : "recentIssuers"
        let isOpen = openPicker == spec.key
        let candidates = Institutions.search(binding.wrappedValue, in: list,
                                             recent: RecentPicks.load(recentKey))

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField(spec.placeholder, text: binding)
                    .font(.system(size: 16))
                    .onChange(of: binding.wrappedValue) { _, _ in openPicker = spec.key }
                if !binding.wrappedValue.isEmpty {
                    Button { binding.wrappedValue = ""; openPicker = spec.key } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.faint)
                    }
                }
                Button {
                    openPicker = isOpen ? nil : spec.key
                } label: {
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.subInk)
                }
            }

            if isOpen && !candidates.isEmpty {
                FlowChips(items: candidates.map(\.name),
                          selected: binding.wrappedValue) { name in
                    binding.wrappedValue = name
                    RecentPicks.remember(name, key: recentKey)
                    openPicker = nil
                }
            }
        }
    }

    @ViewBuilder
    private func hint(_ spec: FieldSpec, text: String) -> some View {
        switch spec.kind {
        case .cardNumber:
            let digits = CardFormat.normalize(text)
            if !digits.isEmpty {
                HStack(spacing: 6) {
                    Text(CardFormat.display(digits))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Theme.subInk)
                    if digits.count >= 12 {
                        Image(systemName: CardFormat.isLuhnValid(digits)
                              ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(CardFormat.isLuhnValid(digits) ? .green : Theme.orange)
                    }
                    Text(CardFormat.brand(of: digits).displayName)
                        .font(.system(size: 11)).foregroundStyle(Theme.subInk)
                }
            }
        case .date:
            let d = DateFormat.normalize(text)
            if !d.isEmpty {
                HStack(spacing: 6) {
                    Text(DateFormat.display(d))
                        .font(.system(size: 13, design: .monospaced)).foregroundStyle(Theme.subInk)
                    if d.count == 8, !DateFormat.isPlausible(d) {
                        Text("날짜를 확인해 주세요")
                            .font(.system(size: 11)).foregroundStyle(Theme.orange)
                    }
                }
            }
        case .rrn:
            let d = IdentityFormat.normalizeRRN(text)
            if !d.isEmpty {
                Text(IdentityFormat.displayRRN(d))
                    .font(.system(size: 13, design: .monospaced)).foregroundStyle(Theme.subInk)
            }
        case .bizNumber:
            let d = IdentityFormat.normalizeBiz(text)
            if !d.isEmpty {
                HStack(spacing: 6) {
                    Text(IdentityFormat.displayBiz(d))
                        .font(.system(size: 13, design: .monospaced)).foregroundStyle(Theme.subInk)
                    if d.count == 10 {
                        Image(systemName: IdentityFormat.isValidBiz(d)
                              ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(IdentityFormat.isValidBiz(d) ? .green : Theme.orange)
                    }
                }
            }
        case .license:
            let d = IdentityFormat.normalizeLicense(text)
            if !d.isEmpty {
                Text(IdentityFormat.displayLicense(d))
                    .font(.system(size: 13, design: .monospaced)).foregroundStyle(Theme.subInk)
            }
        case .customs:
            let s = IdentityFormat.normalizeCustoms(text)
            if !s.isEmpty {
                Text(s + (IdentityFormat.isValidCustoms(s) ? "" : "  · 13자를 채워주세요"))
                    .font(.system(size: 13, design: .monospaced)).foregroundStyle(Theme.subInk)
            }
        default:
            EmptyView()
        }
    }

    // MARK: 동작

    private func applyScan(_ lines: [String]) {
        let found = ScanParser.parse(lines: lines, category: category, subtype: subtype)
        guard !found.isEmpty else {
            scanNote = "읽어낸 값이 없습니다. 밝은 곳에서 글자가 또렷하게 나오도록 다시 찍어보세요."
            return
        }
        var filled = 0
        for (key, value) in found where (values[key] ?? "").isEmpty {
            values[key] = value
            filled += 1
        }
        scanNote = filled > 0
            ? "\(filled)개 칸을 채웠습니다. 맞는지 확인해 주세요."
            : "새로 채울 빈 칸이 없었습니다."
    }

    private func load() {
        guard let item = editing else {
            if let preset = presetCategory { category = preset }
            subtype = category.subtypes.first
            return
        }
        category = item.category
        subtype = item.subtype
        title = item.title
        iconName = item.iconName
        values = item.values()
    }

    /// 사용자가 종류를 직접 바꿨을 때만 입력값을 비운다.
    /// (화면이 열릴 때 기존 항목을 불러오는 것과 구분하기 위해 버튼에서 처리한다)
    private func pick(_ newCategory: VaultCategory) {
        guard newCategory != category else { return }
        category = newCategory
        subtype = newCategory.subtypes.first
        values = [:]
        openPicker = nil
    }

    private func pick(subtype newSubtype: VaultSubtype) {
        guard newSubtype != subtype else { return }
        subtype = newSubtype
        values = [:]
        openPicker = nil
    }

    /// 별칭을 비웠을 때 목록에 무엇이 보이는지 안내한다.
    private var fallbackTitleHint: String {
        switch category {
        case .card: return "카드사"
        case .account: return "은행명"
        case .doorlock: return "장소"
        case .wifi: return "네트워크 이름"
        case .address: return "도로명 주소"
        case .etc where subtype == .business: return "상호"
        default: return subtype?.title ?? category.title
        }
    }

    private func save() {
        // 번호류는 숫자·규격만 남겨 저장한다.
        var cleaned = values
        for spec in fields {
            guard let raw = cleaned[spec.key] else { continue }
            switch spec.kind {
            case .account, .password: cleaned[spec.key] = BankFormat.normalize(raw)
            case .cardNumber: cleaned[spec.key] = CardFormat.normalize(raw)
            case .rrn: cleaned[spec.key] = IdentityFormat.normalizeRRN(raw)
            case .customs: cleaned[spec.key] = IdentityFormat.normalizeCustoms(raw)
            case .passport: cleaned[spec.key] = IdentityFormat.normalizePassport(raw)
            case .bizNumber: cleaned[spec.key] = IdentityFormat.normalizeBiz(raw)
            case .license: cleaned[spec.key] = IdentityFormat.normalizeLicense(raw)
            case .date: cleaned[spec.key] = DateFormat.normalize(raw)
            default: break
            }
        }
        cleaned = cleaned.filter { !$0.value.isEmpty }

        let hint = category == .card
            ? CardFormat.brand(of: cleaned["number"] ?? "").rawValue
            : nil

        do {
            if let item = editing {
                item.categoryRaw = category.rawValue
                item.subtypeRaw = subtype?.rawValue
                item.title = title
                item.iconName = iconName
                item.formatHint = hint
                try item.setValues(cleaned)
            } else {
                let item = VaultItem(category: category, subtype: subtype, title: title,
                                     formatHint: hint, encrypted: Data())
                item.iconName = iconName
                try item.setValues(cleaned)
                context.insert(item)
            }
            try context.save()
            AutoBackup.touch(context)
            dismiss()
        } catch {
            saveError = "저장하지 못했습니다. 다시 시도해 주세요."
        }
    }
}

/// 후보 칩 목록
struct FlowChips: View {
    let items: [String]
    let selected: String
    var onPick: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
            ForEach(items, id: \.self) { name in
                Button { onPick(name) } label: {
                    Text(name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(selected == name ? Theme.orangeBg : Theme.bg))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Theme.line, lineWidth: selected == name ? 0 : 1))
                        .foregroundStyle(Theme.ink)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 최근 고른 기관 — 후보 정렬에만 쓴다.
enum RecentPicks {
    static func load(_ key: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }
    static func remember(_ name: String, key: String) {
        var list = load(key).filter { $0 != name }
        list.insert(name, at: 0)
        UserDefaults.standard.set(Array(list.prefix(5)), forKey: key)
    }
}
