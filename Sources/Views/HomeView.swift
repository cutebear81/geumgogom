import SwiftUI
import SwiftData

/// 메인 — 폴더가 세로로 쌓여 있고, 누르면 그 자리에서 펼쳐진다.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \VaultItem.updatedAt, order: .reverse) private var items: [VaultItem]
    @State private var search = ""
    @State private var opened: VaultCategory?
    @State private var showAdd = false
    @State private var addCategory: VaultCategory?
    @State private var showSettings = false

    /// 펼쳤을 때 폴더 안에 바로 보여주는 개수. 넘으면 '전체 보기'로 넘긴다.
    private let inlineLimit = 5

    private var searchHits: [VaultItem] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return items.filter { $0.searchHaystack().localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GGHeader(logo: true) {
                    HStack(spacing: 10) {
                        GGIconButton(system: "gearshape") { showSettings = true }
                        GGIconButton(system: "plus") { addCategory = nil; showAdd = true }
                    }
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 9) {
                        searchField
                            .padding(.bottom, 5)

                        if search.isEmpty {
                            ForEach(VaultCategory.allCases) { folder($0) }
                        } else {
                            resultList
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(Theme.bg.ignoresSafeArea())
            .sheet(isPresented: $showAdd) { ItemEditView(editing: nil, presetCategory: addCategory) }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.subInk)
            TextField("무엇이든 검색 (별칭·은행·번호…)", text: $search)
                .foregroundStyle(Theme.ink)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.faint)
                }
            }
        }
        .cardSurface()
    }

    // MARK: 폴더

    private func folder(_ category: VaultCategory) -> some View {
        let list = items.filter { $0.category == category }
        let isOpen = opened == category

        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    opened = isOpen ? nil : category
                }
            } label: {
                HStack(spacing: 11) {
                    IconBadge(system: category.icon, size: 34)
                    Text(category.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text(list.isEmpty ? "비어 있음" : "\(list.count)개")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.subInk)
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.faint)
                        .padding(.leading, 2)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(spacing: 10) {
                    if list.isEmpty {
                        Button { addCategory = category; showAdd = true } label: {
                            Label("\(category.title) 추가하기", systemImage: "plus")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.orange)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                    }
                    ForEach(list.prefix(inlineLimit)) { ItemRow(item: $0, nested: true) }
                    if !list.isEmpty {
                        Button { addCategory = category; showAdd = true } label: {
                            Label("여기에 추가", systemImage: "plus")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.orange)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                    }
                    if list.count > inlineLimit {
                        NavigationLink {
                            CategoryListView(category: category)
                        } label: {
                            Text("\(list.count - inlineLimit)개 더 보기")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.orange)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 12)
                .overlay(alignment: .top) { Divider().overlay(Theme.line) }
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(isOpen ? Theme.orange : Theme.line, lineWidth: 1))
    }

    private var resultList: some View {
        VStack(spacing: 9) {
            if searchHits.isEmpty {
                Text("결과가 없습니다")
                    .font(.system(size: 14)).foregroundStyle(Theme.subInk)
                    .padding(.top, 30)
            }
            ForEach(searchHits) { ItemRow(item: $0, showCategory: true) }
        }
    }
}

/// 한 카테고리 전체를 보는 화면 (폴더 안이 길어질 때만 들어간다)
struct CategoryListView: View {
    @Environment(\.modelContext) private var context
    let category: VaultCategory
    @Query private var all: [VaultItem]

    init(category: VaultCategory) {
        self.category = category
        let raw = category.rawValue
        _all = Query(filter: #Predicate<VaultItem> { $0.categoryRaw == raw },
                     sort: [SortDescriptor(\VaultItem.updatedAt, order: .reverse)])
    }

    var body: some View {
        VStack(spacing: 0) {
            GGHeader(title: category.title, subtitle: "\(all.count)개") { EmptyView() }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 9) {
                    ForEach(all) { item in
                        ItemRow(item: item)
                            .contextMenu {
                                Button("삭제", role: .destructive) {
                                    context.delete(item)
                                    try? context.save()
                                    AutoBackup.touch(context)
                                }
                            }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 32)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.bg, for: .navigationBar)
    }
}

struct ItemRow: View {
    let item: VaultItem
    /// 폴더 안에 들어간 행은 배경을 한 톤 낮춘다
    var nested: Bool = false
    /// 어느 카테고리인지 함께 보여줄지. 폴더 안·카테고리 화면에서는 중복이라 끈다.
    var showCategory: Bool = false

    var body: some View {
        NavigationLink {
            ItemDetailView(item: item)
        } label: {
            HStack(spacing: 12) {
                leading
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    if showCategory {
                        Text(item.subtitleText)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.subInk)
                    }
                }
                Spacer()
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11)).foregroundStyle(Theme.orange.opacity(0.6))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.faint)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(nested ? Theme.bg : Theme.card,
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// 카드사·은행이 정해져 있으면 그 색 뱃지로, 아니면 카테고리 아이콘으로.
    @ViewBuilder
    private var leading: some View {
        if item.iconName != nil {
            IconBadge(system: item.icon, size: 32)
        } else if let inst = item.institution {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(hex: inst.tint))
                    .frame(width: 32, height: 32)
                Text(inst.short)
                    .font(.system(size: inst.short.count > 1 ? 11 : 14, weight: .heavy))
                    .foregroundStyle(Color.readableText(on: inst.tint))
            }
        } else {
            IconBadge(system: item.category.icon, size: 32)
        }
    }
}

extension VaultItem {
    var subtitleText: String {
        if let sub = subtype { return "\(category.title) · \(sub.title)" }
        return category.title
    }
}
