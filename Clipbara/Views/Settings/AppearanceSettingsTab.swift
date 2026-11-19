import SwiftUI

enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    /// Localized label. `rawValue` is what is stored in UserDefaults.
    var displayName: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }
}

@MainActor
struct AppearanceSettingsTab: View {
    @AppStorage(PanelCardSize.defaultsKey) private var panelHeight = PanelCardSize.defaultHeight
    @AppStorage(PanelScreen.defaultsKey) private var panelScreen = PanelScreen.pointer
    @AppStorage("appTheme") private var appTheme: String = AppTheme.system.rawValue
    @AppStorage(PanelController.animatesPanelDefaultsKey) private var animatesPanel: Bool = true
    @State private var reducesMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

    var body: some View {
        Form {
            Picker("Theme", selection: $appTheme) {
                ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                    Text(theme.displayName).tag(theme.rawValue)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: appTheme) { _, newValue in
                applyTheme(newValue)
            }

            LabeledContent("Card Size") {
                // Use the same validated height for the slider, its label, and the panel.
                let height = Binding(get: { PanelCardSize.clampedHeight(panelHeight) }, set: { panelHeight = $0 })
                // Use a localized percentage for both the visible and spoken value.
                let scale = (height.wrappedValue / PanelCardSize.defaultHeight)
                    .formatted(.percent.precision(.fractionLength(0)))
                HStack {
                    Slider(value: height, in: PanelCardSize.range, step: PanelCardSize.step) {
                        Text("Card Size")
                    }
                    .labelsHidden()
                    .accessibilityValue(scale)

                    Text(verbatim: scale)
                        .monospacedDigit()
                }
            }

            Picker("Show Panel On", selection: $panelScreen) {
                ForEach(PanelScreen.allCases, id: \.self) { screen in
                    Text(screen.displayName).tag(screen)
                }
            }
            .pickerStyle(.menu)

            Toggle(isOn: $animatesPanel) {
                Text("Animate Panel")
                if reducesMotion {
                    Text("Off while Reduce Motion is on in System Settings > Accessibility > Display.")
                } else {
                    Text("Slide the history panel in and out. When off, it appears and closes at once.")
                }
            }
            .disabled(reducesMotion)
            .onReceive(NSWorkspace.shared.notificationCenter.publisher(
                for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification
            )) { _ in
                reducesMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            }
        }
        .formStyle(.grouped)
        .onAppear {
            applyTheme(appTheme)
        }
    }

    private func applyTheme(_ theme: String) {
        switch AppTheme(rawValue: theme) {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil
        }
    }
}
