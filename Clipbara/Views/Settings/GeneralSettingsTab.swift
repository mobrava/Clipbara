import SwiftUI
import SwiftData
import ServiceManagement
import UniformTypeIdentifiers

struct GeneralSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @AppStorage("historyLimit") private var historyLimit: Int = 500
    @AppStorage(HistoryRetention.defaultsKey) private var retentionDays: Int = HistoryRetention.forever.rawValue
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @AppStorage(AppState.showsMenuBarIconDefaultsKey) private var showsMenuBarIcon = true
    @State private var showHiddenIconNotice = false
    @State private var pendingRetention: HistoryRetention?
    @State private var pendingRetentionCount = 0
    @State private var clearCount = 0
    @State private var showClearAlert = false
    @State private var transferMessage: String?
    @State private var showTransferAlert = false

    var body: some View {
        Form {
            Section {
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
                Toggle(isOn: $showsMenuBarIcon) {
                    Text("Show Icon in Menu Bar")
                    if !showsMenuBarIcon {
                        Text("To open Settings, open Clipbara again or press \u{2318}, in the panel.")
                    }
                }
                .onChange(of: showsMenuBarIcon) { _, isShown in
                    if !isShown { showHiddenIconNotice = true }
                }

                if !showsMenuBarIcon {
                    Button("Quit Clipbara") {
                        NSApplication.shared.terminate(nil)
                    }
                }
            }

            Section("History") {
                Picker("History Limit", selection: $historyLimit) {
                    Text("100").tag(100)
                    Text("500").tag(500)
                    Text("1,000").tag(1000)
                    Text("5,000").tag(5000)
                    Text("Unlimited").tag(0)
                }
                .pickerStyle(.menu)

                Picker(selection: retentionBinding) {
                    ForEach(HistoryRetention.allCases) { retention in
                        Text(retention.title).tag(retention)
                    }
                } label: {
                    Text("Keep History")
                    Text("Clips older than this are deleted. Clips on pinboards are kept.")
                }
                .pickerStyle(.menu)

                LabeledContent {
                    Button("Clear\u{2026}") { requestClear() }
                } label: {
                    Text("Clear History")
                    Text("Deletes every clip that isn't on a pinboard.")
                }
            }

            #if APPSTORE
            SyncSettingsSection()
            #endif

            Section("Backup") {
                LabeledContent {
                    Button("Export\u{2026}") { exportHistory() }
                } label: {
                    Text("Export Backup")
                    Text("Export history, pinboards, and settings to a JSON file.")
                }
                LabeledContent {
                    Button("Import\u{2026}") { importHistory() }
                } label: {
                    Text("Import Backup")
                    Text("Import a backup file. Existing clips are kept; duplicates are skipped.")
                }
            }

        }
        .formStyle(.grouped)
        .alert("Menu Bar Icon Hidden", isPresented: $showHiddenIconNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Clipbara keeps running. To open Settings again, open Clipbara from Applications or Spotlight, or press \u{2318}, in the panel.")
        }
        .alert("Delete Older Clips?", isPresented: retentionAlertBinding, presenting: pendingRetention) { retention in
            Button("Cancel", role: .cancel) { pendingRetention = nil }
            Button("Delete Clips", role: .destructive) { applyRetention(retention) }
        } message: { retention in
            Text("\(pendingRetentionCount) clips older than \(retention.title) will be deleted. Clips on pinboards are kept. This can't be undone.")
        }
        .alert("Clear Clipboard History?", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear History", role: .destructive) { clearHistory() }
        } message: {
            Text("This deletes \(clearCount) unpinned clips from history. Pinboard items stay available.")
        }
        .alert("Backup", isPresented: $showTransferAlert, presenting: transferMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    // MARK: - History

    /// Shortening the period asks first when clips would go; nothing changes on Cancel.
    private var retentionBinding: Binding<HistoryRetention> {
        Binding(
            get: { HistoryRetention(rawValue: retentionDays) ?? .forever },
            set: { newValue in
                let count = HistoryRetention.expiredItems(for: newValue, in: modelContext).count
                if count == 0 {
                    retentionDays = newValue.rawValue
                } else {
                    pendingRetentionCount = count
                    pendingRetention = newValue
                }
            }
        )
    }

    private var retentionAlertBinding: Binding<Bool> {
        Binding(get: { pendingRetention != nil }, set: { if !$0 { pendingRetention = nil } })
    }

    private func applyRetention(_ retention: HistoryRetention) {
        retentionDays = retention.rawValue
        HistoryRetention.deleteExpired(for: retention, in: modelContext)
        appState.clipboardMonitor.refreshLatestItems()
        pendingRetention = nil
    }

    private func requestClear() {
        clearCount = HistoryRetention.clearableItems(in: modelContext).count
        showClearAlert = clearCount > 0
    }

    private func clearHistory() {
        for item in HistoryRetention.clearableItems(in: modelContext) {
            modelContext.delete(item)
        }
        try? modelContext.save()
        appState.clipboardMonitor.refreshLatestItems()
    }

    // MARK: - Backup

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
