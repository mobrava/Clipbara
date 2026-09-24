import SwiftUI
import SwiftData

@main
struct ClipbaraApp: App {
    // Not @State: init() starts clipboard monitoring and registers the hotkeys on this
    // instance, but SwiftUI is free to discard the first @State value and build a new
    // one. Built with the Xcode 27 SDK it does exactly that, so the started instance
    // was deallocated right after launch and the UI got one that never started.
    private let appState = AppState.shared
    @StateObject private var updaterViewModel = CheckForUpdatesViewModel()

    private var sharedModelContainer: ModelContainer { Self.sharedModelContainer }

    private static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ClipboardItem.self,
            Pinboard.self,
            PinboardEntry.self,
            ExcludedApp.self,
        ])

        let storeURL = StoreManager.resolveStoreURL()
        StoreManager.backupStore(at: storeURL)

        let config = ModelConfiguration(url: storeURL)

        // 1차: 정상 오픈
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            StoreManager.logger.error("Failed to open store: \(error.localizedDescription)")
        }

        // 2차: 손상된 store 삭제 후 재시도 (백업은 이미 존재)
        StoreManager.deleteStore(at: storeURL)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            StoreManager.logger.error("Recovery failed: \(error.localizedDescription)")
        }

        // 3차: in-memory 폴백 (앱은 실행되지만 데이터 비영속)
        do {
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        } catch {
            fatalError("Cannot create any ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        MenuBarExtra("Clipbara", systemImage: "clipboard") {
            MenuBarContentView()
                .environment(appState)
                .environmentObject(updaterViewModel)
                .modelContainer(sharedModelContainer)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(appState)
                .environmentObject(updaterViewModel)
                .modelContainer(sharedModelContainer)
        }
    }

    init() {
        let context = sharedModelContainer.mainContext
        appState.start(modelContext: context, modelContainer: sharedModelContainer)

        // First-run welcome tour (NSApp is not ready in init, defer it)
        Task { @MainActor [appState, sharedModelContainer] in
            try? await Task.sleep(for: .milliseconds(400))
            OnboardingWindowController.shared.showIfNeeded(
                appState: appState,
                modelContainer: sharedModelContainer
            )
        }

        // Apply saved theme on launch (NSApp is not ready in init, defer it)
        DispatchQueue.main.async { [sharedModelContainer] in
            let theme = UserDefaults.standard.string(forKey: "appTheme") ?? "System"
            switch theme {
            case "Light": NSApp.appearance = NSAppearance(named: .aqua)
            case "Dark": NSApp.appearance = NSAppearance(named: .darkAqua)
            default: NSApp.appearance = nil
            }

            // Save SwiftData on app termination
            NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated {
                    try? sharedModelContainer.mainContext.save()
                }
            }

            // Save when app loses focus (guards against force-kill/power loss)
            NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated {
                    try? sharedModelContainer.mainContext.save()
                }
            }
        }
    }
}
