import SwiftUI
import SwiftData

struct PrivacySettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \ExcludedApp.appName) private var excludedApps: [ExcludedApp]
    @AppStorage(ContentTypeClassifier.ignoresConfidentialDefaultsKey) private var ignoresConfidential = true
    @AppStorage(ContentTypeClassifier.ignoresTransientDefaultsKey) private var ignoresTransient = true

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $ignoresConfidential) {
                    Text("Ignore Confidential Content")
                    Text("Doesn't save passwords and other content that apps mark as confidential.")
                }
                Toggle(isOn: $ignoresTransient) {
                    Text("Ignore Temporary Content")
                    Text("Doesn't save data that other apps put on the clipboard only for a moment.")
                }
            }

            Section {
                if excludedApps.isEmpty {
                    Text("No apps are excluded.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(excludedApps) { app in
                        HStack(spacing: 10) {
                            Image(nsImage: AppIconProvider.icon(for: app.bundleId, size: 24))
                                .resizable()
                                .frame(width: 24, height: 24)
                            Text(app.appName)
                            Spacer()
                            Button {
                                remove(app)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .help(Text("Remove"))
                        }
                    }
                }
                HStack {
                    Button("Add App\u{2026}") { addApp() }
                    Spacer()
                }
            } header: {
                Text("Excluded Apps")
            } footer: {
                Text("Excluded apps will not have their clipboard content saved.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Select App to Exclude")
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let bundle = Bundle(url: url),
              let bundleId = bundle.bundleIdentifier else { return }

        let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent

        if excludedApps.contains(where: { $0.bundleId == bundleId }) { return }

        modelContext.insert(ExcludedApp(bundleId: bundleId, appName: appName))
        try? modelContext.save()
        appState.clipboardMonitor.loadExcludedApps()
    }

    private func remove(_ app: ExcludedApp) {
        modelContext.delete(app)
        try? modelContext.save()
        appState.clipboardMonitor.loadExcludedApps()
    }
}
