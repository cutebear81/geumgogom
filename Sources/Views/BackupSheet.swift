import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 백업 내보내기·복원 시트. 비밀번호를 받아 그 자리에서 처리한다.
struct BackupSheet: View {
    enum Mode { case export, restore }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let mode: Mode
    let items: [VaultItem]
    var onDone: (String) -> Void

    @State private var password = ""
    @State private var exportedURL: URL?
    @State private var showImporter = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("백업 비밀번호")
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.subInk)
                        SecureField("4자 이상", text: $password)
                            .font(.system(size: 16))
                        Text(mode == .export
                             ? "이 비밀번호로 백업 파일이 암호화됩니다. 잊으면 복원할 수 없습니다."
                             : "백업할 때 정한 비밀번호를 입력하세요.")
                            .font(.system(size: 11)).foregroundStyle(Theme.subInk)
                    }
                    .cardSurface()

                    if let error {
                        Text(error).font(.system(size: 13)).foregroundStyle(Theme.orange)
                    }

                    if mode == .restore, AutoBackup.existingBackup() != nil {
                        Button { restoreFromICloud() } label: {
                            Text("iCloud 백업에서 복원")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(password.count < 4 ? Theme.faint : Theme.orange,
                                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .foregroundStyle(.white)
                        }
                        .disabled(password.count < 4)
                    }

                    Button {
                        mode == .export ? runExport() : (showImporter = true)
                    } label: {
                        Text(mode == .export ? "백업 파일 만들기" : "파일 선택해서 복원")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(password.count < 4 ? Theme.faint : Theme.dark))
                            .foregroundStyle(Theme.onDark)
                    }
                    .disabled(password.count < 4)
                }
                .padding(.horizontal, 20).padding(.top, 8)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle(mode == .export ? "백업 내보내기" : "백업 복원")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbar { Button("닫기") { dismiss() } }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.data]) { result in
                runRestore(result)
            }
            // 파일 앱으로 저장 — 여기서 iCloud Drive를 고르면 그대로 iCloud 백업이 된다.
            .fileExporter(isPresented: Binding(get: { exportedURL != nil },
                                               set: { if !$0 { exportedURL = nil } }),
                          document: exportedURL.map(BackupDocument.init),
                          contentType: .data,
                          defaultFilename: "금고곰_백업") { result in
                if case .success = result {
                    onDone("백업 파일을 저장했습니다.")
                    dismiss()
                }
                exportedURL = nil
            }
        }
    }

    private func runExport() {
        do {
            let data = try BackupService.export(items, password: password)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("금고곰_백업.\(BackupService.fileExtension)")
            try data.write(to: url, options: .completeFileProtection)
            exportedURL = url
        } catch {
            self.error = "백업 파일을 만들지 못했습니다."
        }
    }

    /// iCloud Drive 에 자동 저장된 백업을 바로 읽는다.
    private func restoreFromICloud() {
        guard let url = AutoBackup.existingBackup() else {
            error = "iCloud에서 백업 파일을 찾지 못했습니다."
            return
        }
        applyRestore(from: url)
    }

    private func runRestore(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            applyRestore(from: url, scoped: true)
        } catch {
            self.error = "복원하지 못했습니다. 파일을 확인해 주세요."
        }
    }

    private func applyRestore(from url: URL, scoped useScope: Bool = false) {
        do {
            let scoped = useScope && url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            let payload = try BackupService.restore(try Data(contentsOf: url), password: password)
            for entry in payload.items {
                let item = VaultItem(
                    category: VaultCategory(rawValue: entry.category) ?? .etc,
                    subtype: entry.subtype.flatMap(VaultSubtype.init(rawValue:)),
                    title: entry.title, formatHint: entry.formatHint, encrypted: Data())
                item.isFavorite = entry.isFavorite
                try item.setValues(entry.values)
                context.insert(item)
            }
            try context.save()
            onDone("\(payload.items.count)건을 복원했습니다.")
            dismiss()
        } catch BackupService.BackupError.wrongPassword {
            error = "비밀번호가 맞지 않습니다."
        } catch {
            self.error = "복원하지 못했습니다. 파일을 확인해 주세요."
        }
    }
}

/// 파일 앱으로 내보낼 백업 문서
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var data: Data

    init(url: URL) { data = (try? Data(contentsOf: url)) ?? Data() }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
