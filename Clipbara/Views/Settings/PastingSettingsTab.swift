import Combine
import SwiftUI

struct PastingSettingsTab: View {
    @AppStorage(PasteService.alwaysPlainTextDefaultsKey) private var alwaysPastePlainText: Bool = false
    @AppStorage(DirectPaste.enabledDefaultsKey) private var pasteIntoActiveApp: Bool = false
    @State private var hasPastePermission = DirectPaste.hasPermission
    /// Permission is granted in System Settings, outside the app, so poll while visible.
    private let permissionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $alwaysPastePlainText) {
                    Text("Always Paste as Plain Text")
                    Text("Removes fonts, colors, and links from rich text and HTML clips, pasting only the text.")
                        + Text(verbatim: " ")
                        + Text("Hold \u{21e7} while pasting to switch for a single paste.")
                }

                if DirectPaste.isAvailable {
                    Toggle(isOn: $pasteIntoActiveApp) {
                        Text("Paste into the Active App")
                        Text("Clicking a clip or pressing Return pastes it where you were typing. When off, the clip is only copied.")
                            + Text(verbatim: " ")
                            + Text("After the panel closes, Clipbara presses \u{2318}V for you. This needs Accessibility permission, which is used for nothing else.")
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
                            Label("Accessibility permission is off, so clips are only copied.", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            // App Store builds are sandboxed, and macOS neither prompts
                            // for nor lists a sandboxed app, so the user adds it.
                            Text("If Clipbara isn't in the list, add it with the + button.")
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onReceive(permissionTimer) { _ in
            let current = DirectPaste.hasPermission
            if current != hasPastePermission { hasPastePermission = current }
        }
    }
}
