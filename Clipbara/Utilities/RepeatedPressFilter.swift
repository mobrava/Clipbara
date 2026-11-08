import Foundation

/// Drops a hotkey press that arrives right after the one before it.
///
/// While a menu is open, KeyboardShortcuts reads keys through two event
/// monitors instead of a Carbon hot key, and it can report one press several
/// times within a few milliseconds (four times for one press of the panel
/// shortcut on macOS 26.6.2). Each report toggles the panel, so it closed and
/// came back. Nobody presses a key twice within a tenth of a second.
struct RepeatedPressFilter {
    var interval: Duration = .milliseconds(100)
    private var lastAccepted: ContinuousClock.Instant?

    mutating func accept(at now: ContinuousClock.Instant = .now) -> Bool {
        if let lastAccepted, now - lastAccepted < interval {
            return false
        }
        lastAccepted = now
        return true
    }
}
