import SwiftUI
import SwiftData

/// The panes of the Settings window, listed in its sidebar.
enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case pasting
    case privacy
    case appearance
    case shortcuts
    case about

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .general: "General"
        case .pasting: "Pasting"
        case .privacy: "Privacy"
        case .appearance: "Appearance"
        case .shortcuts: "Shortcuts"
        case .about: "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .pasting: "doc.on.clipboard"
        case .privacy: "hand.raised"
        case .appearance: "paintbrush"
        case .shortcuts: "keyboard"
        case .about: "info.circle"
        }
    }
}

/// A sidebar of panes and, for each, rows with a title and a line explaining
/// it, in the layout of System Settings.
struct SettingsView: View {
    @State private var selection: SettingsPane? = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $selection) { pane in
                Label(pane.title, systemImage: pane.systemImage)
            }
            .navigationSplitViewColumnWidth(180)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            let pane = selection ?? .general
            detail(for: pane)
                .navigationTitle(pane.title)
        }
        .frame(width: 700, height: 520)
        .background(SettingsWindowReader())
    }

    @ViewBuilder
    private func detail(for pane: SettingsPane) -> some View {
        switch pane {
        case .general: GeneralSettingsTab()
        case .pasting: PastingSettingsTab()
        case .privacy: PrivacySettingsTab()
        case .appearance: AppearanceSettingsTab()
        case .shortcuts: ShortcutSettingsTab()
        case .about: AboutTab()
        }
    }
}
