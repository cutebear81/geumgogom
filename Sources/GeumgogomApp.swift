import SwiftUI
import SwiftData

@main
struct GeumgogomApp: App {
    @StateObject private var lock = AppLock()
    @AppStorage("didOnboard") private var didOnboard = false
    @Environment(\.scenePhase) private var phase
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if didOnboard {
                    HomeView()
                        .environmentObject(lock)
                        // 앱 스위처에 내용이 찍히지 않도록 잠기거나 비활성일 때 가린다.
                        .blur(radius: shouldBlur ? 24 : 0)
                    if lock.isLocked { LockView(lock: lock) }
                } else {
                    OnboardingView(lock: lock)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: lock.isLocked)
            .task { VaultMigration.run(Self.container.mainContext) }
            .overlay {
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .task {
                            try? await Task.sleep(for: .seconds(1.1))
                            withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
                        }
                }
            }
        }
        .modelContainer(Self.container)
        .onChange(of: phase) { _, new in
            if new == .background { lock.enteredBackground() }
            if new == .active { lock.becameActive() }
        }
    }

    /// SwiftData 저장소.
    /// iCloud 권한(Documents)이 들어가면 SwiftData 가 **CloudKit 동기화를 자동으로 켜려 한다.**
    /// 우리는 CloudKit 을 쓰지 않고 암호화 파일로만 백업하므로 명시적으로 꺼둔다.
    /// (안 끄면 "must have a CloudKit entitlement" 로 앱이 즉시 죽는다)
    static let container: ModelContainer = {
        let config = ModelConfiguration(cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: VaultItem.self, configurations: config)
        } catch {
            fatalError("저장소를 열지 못했습니다: \(error)")
        }
    }()

    private var shouldBlur: Bool {
        guard LockSettings.isEnabled else { return false }
        return lock.isLocked || phase != .active
    }
}
