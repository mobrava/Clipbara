import AppKit
import ApplicationServices

/// Optional "paste into the active app": after a clip is copied and the panel
/// closes, Clipbara presses ⌘V for the user. Off by default. Posting a key
/// event needs Accessibility permission, and without it the clip is only
/// copied, exactly as when the setting is off.
@MainActor
enum DirectPaste {
    nonisolated static let enabledDefaultsKey = "pasteIntoActiveApp"

    /// Stamped on the ⌘V events Clipbara posts, so they can be told apart from
    /// the user's own ⌘V.
    nonisolated static let syntheticEventMarker: Int64 = 0x436C_6970 // "Clip"

    /// Whether this build offers pasting into the active app. App Review rejected
    /// it in the App Store build under guideline 2.4.5 (Accessibility used for
    /// something other than accessibility), so only the DMG build has it. The
    /// Clip Queue no longer needs Accessibility and is in both builds.
    #if APPSTORE
    nonisolated static let isAvailable = false
    #else
    nonisolated static let isAvailable = true
    #endif

    static var isEnabled: Bool {
        isAvailable && UserDefaults.standard.bool(forKey: enabledDefaultsKey)
    }

    /// Reads the Accessibility grant live. `CGPreflightPostEventAccess` kept
    /// answering true inside a running process after the grant was removed in
    /// System Settings, so the settings warning never appeared and ⌘V was
    /// silently dropped. The Accessibility grant alone is enough to post it.
    static var hasPermission: Bool {
        isAvailable && AXIsProcessTrusted()
    }

    /// Whether the next paste should be followed by ⌘V.
    static var isReady: Bool {
        isEnabled && hasPermission
    }

    /// Asks for Accessibility access. A sandboxed build gets no prompt and is
    /// not added to the list (the request is only checked), so Settings tells
    /// the user to add Clipbara with the + button.
    @discardableResult
    static func requestPermission() -> Bool {
        guard isAvailable else { return false }
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Sends ⌘V to whichever app has keyboard focus. Call only after the
    /// panel is off screen, or the panel itself receives it.
    @discardableResult
    static func sendPasteShortcut() -> Bool {
        guard hasPermission else { return false }

        let keyCode = PasteKeyCode.current()
        let source = CGEventSource(stateID: .combinedSessionState)
        // Keep keys the user is still holding from mixing into the shortcut.
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return false
        }
        // Include the left Command device bit; some apps ignore a Command flag
        // that no physical side key accounts for.
        let flags = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x0000_0008)
        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
        keyUp.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
        return true
    }
}
