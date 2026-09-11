import SwiftUI
import KeyboardShortcuts

struct ShortcutSettingsTab: View {
    var body: some View {
        Form {
            HStack {
                Text("Toggle History Panel")
                InfoHoverButton(text: "Combine at least one of \u{2318}, \u{2325} or \u{2303} with a key, like \u{2325}V or \u{2303}\u{21e7}P. Function keys (F1\u{2013}F12) work on their own. Shift alone isn't supported by macOS.")
                Spacer()
                KeyboardShortcuts.Recorder(for: .toggleHistoryPanel)
            }
            HStack {
                Text("Clear All History")
                Spacer()
                KeyboardShortcuts.Recorder(for: .clearHistory)
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text("Quick Look Preview")
                        InfoHoverButton(text: "A single key with no modifiers. It only works while the Clipbara panel is open, so it won't clash with other apps.")
                    }
                    Text("Pressed inside the panel with a card selected.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                LocalKeyRecorderView()
            }
            Section("Tab Navigation") {
                LabeledContent("History", value: "⌘1")
                LabeledContent("First 8 Pinboards", value: "⌘2–⌘9")
                Text("Fixed shortcuts in tab order. Only active while the history panel is open, including while searching.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
