import SwiftUI
import SwiftData
import KeyboardShortcuts

/// The menu bar extra's menu.
///
/// A real menu (`.menuBarExtraStyle(.menu)`), not a popover: the Human
/// Interface Guidelines ask for a menu unless the content is too complex for
/// one, and a menu gets the system's look, highlight, and keyboard handling.
struct MenuBarContentView: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var updaterViewModel: CheckForUpdatesViewModel
    @Query(sort: \ClipboardItem.copiedAt, order: .reverse)
    private var recentItems: [ClipboardItem]

    private var topItems: [ClipboardItem] {
        Array(recentItems.prefix(5))
    }

    var body: some View {
        Section("Recent Copies") {
            if topItems.isEmpty {
                Text("No clipboard history")
            } else {
                ForEach(topItems) { item in
                    MenuBarItemRow(item: item)
                }
            }
        }

        Divider()

        Button("Open History") {
            appState.togglePanel()
        }
        .globalKeyboardShortcut(.toggleHistoryPanel)

        Button(appState.clipQueue.isActive ? "End Clip Queue" : "Start Clip Queue") {
            appState.toggleClipQueue()
        }
        .globalKeyboardShortcut(.toggleClipQueue)

        Toggle("Clipboard Monitoring", isOn: Binding(
            get: { appState.clipboardMonitor.isMonitoring },
            set: { _ in appState.clipboardMonitor.toggle() }
        ))

        #if APPSTORE
        if showsPurchaseItems {
            Divider()

            Button {
                PaywallWindowController.shared.show()
            } label: {
                Text("Unlock Clipbara…")
                trialStatus
            }

            Button("Restore Purchases") {
                PaywallWindowController.shared.show(restore: true)
            }
        }
        #endif

        Divider()

        #if !APPSTORE
        Button("Check for Updates…") {
            updaterViewModel.checkForUpdates()
        }
        .disabled(!updaterViewModel.canCheckForUpdates)
        #endif

        Button("Send Feedback…") {
            NSWorkspace.shared.open(ReviewPrompter.feedbackURL)
        }

        #if APPSTORE
        Button("Rate on App Store") {
            NSWorkspace.shared.open(ReviewPrompter.writeReviewURL)
        }
        #endif

        Divider()

        Button("Settings…") {
            openSettings()
            SettingsWindowFront.bring()
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("Quit Clipbara") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    #if APPSTORE
    /// Hidden once the app is owned, and while a StoreKit check has failed open.
    private var showsPurchaseItems: Bool {
        switch Entitlements.shared.state {
        case .trialActive, .trialNotStarted, .trialExpired: true
        case .unlocked: false
        }
    }

    @ViewBuilder
    private var trialStatus: some View {
        switch Entitlements.shared.state {
        case .trialActive(let daysLeft):
            Text("\(daysLeft) days left")
        case .trialExpired:
            Text("Trial ended")
        case .trialNotStarted, .unlocked:
            EmptyView()
        }
    }
    #endif
}

struct MenuBarItemRow: View {
    let item: ClipboardItem
    @Environment(AppState.self) private var appState

    /// Menus grow to fit their longest item, so long clips are cut here.
    static let titleLimit = 42

    var body: some View {
        Button {
            #if APPSTORE
            guard Entitlements.shared.checkHistoryAccess() else {
                PaywallWindowController.shared.show()
                return
            }
            #endif
            appState.clipQueue.stop()
            appState.clipboardMonitor.skipNextChange()
            appState.pasteService.paste(item: item)
        } label: {
            Image(systemName: item.contentType.systemImage)
            Text(verbatim: title)
            Text(verbatim: subtitle)
        }
    }

    private var title: String {
        let text: String
        switch item.contentType {
        case .plainText, .richText, .html, .url:
            text = item.textContent ?? "…"
        case .image:
            text = String(localized: "Image")
        case .fileURL:
            text = item.textContent ?? String(localized: "File")
        case .color:
            text = item.textContent ?? String(localized: "Color")
        case .unknown:
            text = String(localized: "Unknown")
        }
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.count > Self.titleLimit ? String(trimmed.prefix(Self.titleLimit)) + "…" : trimmed
    }

    private var subtitle: String {
        [item.sourceAppName, RelativeTimeFormatter.string(for: item.copiedAt)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
