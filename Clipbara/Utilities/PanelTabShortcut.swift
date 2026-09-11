import AppKit

enum PanelTab: Equatable, Hashable {
    case history
    case pinboard(UUID)
}

/// Fixed panel-local shortcuts, in the same order as the visible tabs.
/// No global hotkeys are registered for tab navigation.
enum PanelTabShortcut {
    static func index(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Int? {
        let chord = modifiers.intersection([.command, .option, .control, .shift])
        guard chord == .command else { return nil }

        // Physical number row and numeric keypad, 1 through 9. Caps Lock and
        // the keypad flag do not change the shortcut; extra modifiers do.
        let numberRow: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
        let keypad: [UInt16] = [83, 84, 85, 86, 87, 88, 89, 91, 92]
        return numberRow.firstIndex(of: keyCode) ?? keypad.firstIndex(of: keyCode)
    }

    static func target(at index: Int, pinboardIDs: [UUID]) -> PanelTab? {
        guard (0..<9).contains(index) else { return nil }
        if index == 0 { return .history }
        guard pinboardIDs.indices.contains(index - 1) else { return nil }
        return .pinboard(pinboardIDs[index - 1])
    }

    static func hint(at index: Int) -> String? {
        guard (0..<9).contains(index) else { return nil }
        return "⌘\(index + 1)"
    }
}
