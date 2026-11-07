import Combine
import SwiftUI
import SwiftData
import ServiceManagement
import UniformTypeIdentifiers

struct GeneralSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @AppStorage("historyLimit") private var historyLimit: Int = 500
    /// Short sounds on copy and paste.
    @AppStorage(SoundFeedback.defaultsKey) private var playsSounds: Bool = false
    @AppStorage(PasteService.alwaysPlainTextDefaultsKey) private var alwaysPastePlainText: Bool = false
    @AppStorage(DirectPaste.enabledDefaultsKey) private var pasteIntoActiveApp: Bool = false
    @State private var hasPastePermission = DirectPaste.hasPermission
    /// Permission is granted in System Settings, outside the app, so poll while visible.
    private let permissionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @AppStorage(AppState.showsMenuBarIconDefaultsKey) private var showsMenuBarIcon = true
    @State private var showHiddenIconNotice = false
    @State private var transferMessage: String?
    @State private var showTransferAlert = false

    var body: some View {
        Form {
            Picker("History Limit", selection: $historyLimit) {
                Text("100").tag(100)
                Text("500").tag(500)
                Text("1,000").tag(1000)
                Text("5,000").tag(5000)
                Text("Unlimited").tag(0)
            }
            .pickerStyle(.menu)

            Toggle("Play Sounds", isOn: $playsSounds)

            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = !newValue
                    }
                }

            // #25. Opening the app again (AppDelegate) and ⌘, or the … menu
            // in the panel lead back here while the icon is hidden.
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Icon in Menu Bar")
                    if !showsMenuBarIcon {
                        Text("To open Settings, open Clipbara again or press \u{2318}, in the panel.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Toggle("", isOn: $showsMenuBarIcon)
                    .labelsHidden()
            }
            .onChange(of: showsMenuBarIcon) { _, isShown in
                if !isShown { showHiddenIconNotice = true }
            }
            .alert("Menu Bar Icon Hidden", isPresented: $showHiddenIconNotice) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Clipbara keeps running. To open Settings again, open Clipbara from Applications or Spotlight, or press \u{2318}, in the panel.")
            }

            if !showsMenuBarIcon {
                Button("Quit Clipbara") {
                    NSApplication.shared.terminate(nil)
                }
            }

            Section("Pasting") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text("Always Paste as Plain Text")
                            InfoHoverButton(text: "Removes fonts, colors, and links from rich text and HTML clips, pasting only the text.")
                        }
                        Text("Hold \u{21e7} while pasting to switch for a single paste.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $alwaysPastePlainText)
                        .labelsHidden()
                }

                if DirectPaste.isAvailable {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                Text("Paste into the Active App")
                                InfoHoverButton(text: "After the panel closes, Clipbara presses \u{2318}V for you. This needs Accessibility permission, which is used for nothing else.")
                            }
                            Text("Clicking a clip or pressing Return pastes it where you were typing. When off, the clip is only copied.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $pasteIntoActiveApp)
                            .labelsHidden()
                    }
                    .onChange(of: pasteIntoActiveApp) { _, isOn in
                        if isOn, !DirectPaste.hasPermission {
                            DirectPaste.requestPermission()
                        }
                        hasPastePermission = DirectPaste.hasPermission
                    }

                    if pasteIntoActiveApp, !hasPastePermission {
                        LabeledContent {
                            Button("Open Accessibility Settings\u{2026}") {
                                DirectPaste.requestPermission()
                                DirectPaste.openAccessibilitySettings()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Label("Accessibility permission is off, so clips are only copied.", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                // App Store builds are sandboxed, and macOS neither prompts
                                // for nor lists a sandboxed app, so the user adds it.
                                Text("If Clipbara isn't in the list, add it with the + button.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .onReceive(permissionTimer) { _ in
                let current = DirectPaste.hasPermission
                if current != hasPastePermission { hasPastePermission = current }
            }

            #if APPSTORE
            SyncSettingsSection()
            #endif

            Section("Backup") {
                LabeledContent("Export history, pinboards, and settings to a JSON file.") {
                    Button("Export\u{2026}") { exportHistory() }
                }
                LabeledContent("Import a backup file. Existing clips are kept; duplicates are skipped.") {
                    Button("Import\u{2026}") { importHistory() }
                }
            }

            Section {
                LabeledContent("Replay the first-run welcome tour.") {
                    Button("Show Welcome Tour\u{2026}") { showWelcomeTour() }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Backup", isPresented: $showTransferAlert, presenting: transferMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private func showWelcomeTour() {
        guard let container = appState.modelContainer else { return }
        OnboardingWindowController.shared.show(appState: appState, modelContainer: container)
    }

    private func exportHistory() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "clipbara-backup.json"
        panel.title = String(localized: "Export Clipbara Backup")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try TransferService.exportDocument(context: modelContext)
            try data.write(to: url)
            transferMessage = String(localized: "Backup exported successfully.")
        } catch {
            transferMessage = String(localized: "Export failed: \(error.localizedDescription)")
        }
        showTransferAlert = true
    }

    private func importHistory() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = String(localized: "Import Clipbara Backup")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let summary = try TransferService.importDocument(data, context: modelContext)
            transferMessage = summary.localizedMessage
        } catch {
            transferMessage = String(localized: "Import failed: \(error.localizedDescription)")
        }
        showTransferAlert = true
    }
}
