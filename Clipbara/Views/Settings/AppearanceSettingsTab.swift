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

struct AppearanceSettingsTab: View {
    @AppStorage("appTheme") private var appTheme: String = AppTheme.system.rawValue
    @AppStorage(PanelController.animatesPanelDefaultsKey) private var animatesPanel: Bool = true
    @State private var reducesMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    /// System Reduce Transparency, which makes the panel solid and turns off
    /// Background Transparency.
    @State private var reducesTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    /// Share of the screen width the panel takes, in percent.
    @AppStorage(PanelWidth.defaultsKey) private var panelWidth: Double = PanelWidth.defaultValue
    /// Panel height, which sets the card size.
    @AppStorage(PanelCardSize.defaultsKey) private var panelHeight: Double = PanelCardSize.defaultValue
    /// Which display the panel opens on.
    @AppStorage(PanelScreen.defaultsKey) private var panelScreen: PanelScreen = .pointer
    /// Panel background, from the standard blur (0) to clear (1).
    @AppStorage(PanelBackgroundTransparency.defaultsKey)
    private var backgroundTransparency: Double = PanelBackgroundTransparency.defaultValue

    var body: some View {
        form
            .padding()
        .onAppear {
            applyTheme(appTheme)
        }
    }

    /// The settings, in grouped boxes.
    private var form: some View {
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

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Animate Panel")
                    Group {
                        if reducesMotion {
                            Text("Off while Reduce Motion is on in System Settings > Accessibility > Display.")
                        } else {
                            Text("Slide the history panel in and out. When off, it appears and closes at once.")
                        }
                    }
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: $animatesPanel)
                    .labelsHidden()
                    .disabled(reducesMotion)
            }
            .onReceive(NSWorkspace.shared.notificationCenter.publisher(
                for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification
            )) { _ in
                reducesMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                reducesTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
            }

            Section {
                SettingsSliderRow(
                    title: "Panel Width",
                    value: $panelWidth,
                    range: PanelWidth.range,
                    step: PanelWidth.step,
                    valueText: (panelWidth / 100).formatted(.percent.precision(.fractionLength(0)))
                )
                SettingsSliderRow(
                    title: "Card Size",
                    value: $panelHeight,
                    range: PanelCardSize.range,
                    step: PanelCardSize.step,
                    // Card size relative to the default.
                    valueText: (panelHeight / PanelCardSize.defaultValue)
                        .formatted(.percent.precision(.fractionLength(0)))
                )
                Picker("Show Panel On", selection: $panelScreen) {
                    ForEach(PanelScreen.allCases, id: \.self) { screen in
                        Text(screen.displayName).tag(screen)
                    }
                }
                .pickerStyle(.menu)
                SettingsSliderRow(
                    title: "Background Transparency",
                    value: $backgroundTransparency,
                    range: PanelBackgroundTransparency.range,
                    step: PanelBackgroundTransparency.step,
                    valueText: backgroundTransparency.formatted(.percent.precision(.fractionLength(0)))
                )
                .disabled(reducesTransparency)
                if reducesTransparency {
                    Text("Off while Reduce Transparency is on in System Settings > Accessibility > Display.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Panel")
            } footer: {
                // The footer sits under the box and lines up with its edges,
                // which is where System Settings puts a pane's buttons.
                VStack(alignment: .leading, spacing: 12) {
                    Text("Width, card size and transparency update an open panel right away. The screen applies the next time the panel opens.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    HStack {
                        Spacer()
                        Button("Restore Defaults") { restoreDefaults() }
                            .disabled(isAtDefaults)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    /// Whether every setting on this tab already has its default value.
    private var isAtDefaults: Bool {
        appTheme == AppTheme.system.rawValue
            && animatesPanel
            && panelWidth == PanelWidth.defaultValue
            && panelHeight == PanelCardSize.defaultValue
            && panelScreen == .pointer
            && backgroundTransparency == PanelBackgroundTransparency.defaultValue
    }

    /// Puts every setting on this tab back to its default. Assigned rather
    /// than removed from UserDefaults so the theme's `onChange` applies it and
    /// an open panel resizes at once.
    private func restoreDefaults() {
        appTheme = AppTheme.system.rawValue
        animatesPanel = true
        panelWidth = PanelWidth.defaultValue
        panelHeight = PanelCardSize.defaultValue
        panelScreen = .pointer
        backgroundTransparency = PanelBackgroundTransparency.defaultValue
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

/// A settings row with a label, a slider and its current value.
private struct SettingsSliderRow: View {
    /// Row label.
    let title: LocalizedStringKey
    /// The stored value the slider edits.
    @Binding var value: Double
    /// Slider bounds.
    let range: ClosedRange<Double>
    /// Slider increment.
    let step: Double
    /// The value as shown next to the slider.
    let valueText: String

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                Slider(value: $value, in: range, step: step)
                    .frame(width: 180)
                Text(valueText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }
}
