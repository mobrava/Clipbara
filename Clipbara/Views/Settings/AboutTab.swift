import SwiftUI

struct AboutTab: View {
    @EnvironmentObject private var updaterViewModel: CheckForUpdatesViewModel
    @Environment(AppState.self) private var appState

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text(verbatim: "Clipbara")
                .font(.title.bold())

            Text("Version \(appVersion) (\(buildNumber))")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("A simple clipboard manager for macOS.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                #if !APPSTORE
                Button("Check for Updates…") {
                    updaterViewModel.checkForUpdates()
                }
                .disabled(!updaterViewModel.canCheckForUpdates)
                #endif

                Button("Show Welcome Tour…") {
                    guard let container = appState.modelContainer else { return }
                    OnboardingWindowController.shared.show(appState: appState, modelContainer: container)
                }
            }
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
