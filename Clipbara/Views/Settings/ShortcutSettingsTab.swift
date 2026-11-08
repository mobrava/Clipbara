import SwiftUI
import KeyboardShortcuts

struct ShortcutSettingsTab: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Toggle History Panel") {
                    KeyboardShortcuts.Recorder(for: .toggleHistoryPanel)
                }
                LabeledContent {
                    KeyboardShortcuts.Recorder(for: .toggleClipQueue)
                } label: {
                    Text("Start or End Clip Queue")
                    Text("While the queue is on, everything you copy joins it, and each \u{2318}V pastes the next item in order.")
                }
                LabeledContent("Clear All History") {
                    KeyboardShortcuts.Recorder(for: .clearHistory)
                }
            } footer: {
                Text("Combine at least one of \u{2318}, \u{2325} or \u{2303} with a key, like \u{2325}V or \u{2303}\u{21e7}P. Function keys (F1\u{2013}F12) work on their own. Shift alone isn't supported by macOS.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("In the Panel") {
                LabeledContent {
                    LocalKeyRecorderView()
                } label: {
                    Text("Quick Look Preview")
                    Text("Pressed with a card selected. A single key, no modifiers.")
                }
                LabeledContent("History", value: "\u{2318}1")
                LabeledContent("First 8 Pinboards", value: "\u{2318}2\u{2013}\u{2318}9")
            }
        }
        .formStyle(.grouped)
    }
}
