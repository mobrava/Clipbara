import AppKit
import SwiftUI

/// Settings > Appearance > Panel Width. Stored as the percentage of the
/// screen's usable width; the panel is centered when it is narrower.
enum PanelWidth {
    /// UserDefaults key. Missing means full width.
    nonisolated static let defaultsKey = "panelWidthPercent"
    /// Slider range, in percent of the screen width.
    static let range: ClosedRange<Double> = 50...100
    /// Slider step, in percent.
    static let step: Double = 5
    /// Used when the setting is missing.
    static let defaultValue: Double = 100

    /// The stored percentage, clamped to `range`.
    static var percent: Double {
        let stored = UserDefaults.standard.object(forKey: defaultsKey) as? Double ?? defaultValue
        return min(max(stored, range.lowerBound), range.upperBound)
    }

    /// Fraction of the screen width the panel takes.
    static var fraction: CGFloat { CGFloat(percent) / 100 }

    /// Whether the panel spans the whole screen width.
    static var isFull: Bool { percent >= range.upperBound }
}

/// Settings > Appearance > Card Size. Cards fill the panel's card row, so the
/// size is stored as the panel height: navigation bar and row padding (68pt)
/// plus the card height.
enum PanelCardSize {
    /// UserDefaults key. Missing means the default height.
    nonisolated static let defaultsKey = "panelHeight"
    /// Slider range, in points. The low end keeps cards above
    /// `DesignTokens.Grid.minCardHeight`.
    static let range: ClosedRange<Double> = 240...420
    /// Slider step, in points.
    static let step: Double = 10
    /// Used when the setting is missing: 252pt tall cards.
    static let defaultValue: Double = 320

    /// The stored panel height, clamped to `range`.
    static var panelHeight: CGFloat {
        let stored = UserDefaults.standard.object(forKey: defaultsKey) as? Double ?? defaultValue
        return CGFloat(min(max(stored, range.lowerBound), range.upperBound))
    }
}

/// Settings > Appearance > Show Panel On. Which display the panel slides in on.
enum PanelScreen: String, CaseIterable {
    /// The display under the pointer.
    case pointer
    /// The display holding the frontmost app's front window.
    case activeWindow
    /// The display with the menu bar (System Settings > Displays > Main display).
    case main

    /// UserDefaults key. Missing means the pointer's display.
    nonisolated static let defaultsKey = "panelScreen"

    /// The stored setting, or the pointer's display when missing or unknown.
    static var current: PanelScreen {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(PanelScreen.init(rawValue:)) ?? .pointer
    }

    /// Localized label.
    var displayName: String {
        switch self {
        case .pointer: String(localized: "Screen with Pointer")
        case .activeWindow: String(localized: "Screen with Active Window")
        case .main: String(localized: "Main Screen")
        }
    }
}

/// Settings > Appearance > Background Transparency. Fades out the frosted
/// blur behind the cards: 0 is the standard blur, 1 leaves only the cards over
/// what is behind the panel. A solid background comes from the system's
/// Reduce Transparency setting, which the blur follows on its own.
enum PanelBackgroundTransparency {
    /// UserDefaults key. Missing means the standard blur.
    nonisolated static let defaultsKey = "panelTransparency"
    /// Slider range.
    static let range: ClosedRange<Double> = 0...1
    /// Slider step.
    static let step: Double = 0.05
    /// Used when the setting is missing: the standard blur.
    static let defaultValue: Double = 0

    /// Opacity of the blur.
    /// - Parameters:
    ///   - transparency: The setting, from 0 to 1.
    ///   - reducesTransparency: Whether Reduce Transparency is on. The blur
    ///     is then solid and stays fully opaque.
    static func blurOpacity(for transparency: Double, reducesTransparency: Bool) -> Double {
        guard !reducesTransparency else { return 1 }
        return 1 - min(max(transparency, range.lowerBound), range.upperBound)
    }
}

/// Settings > General > Play Sounds. A short system sound on copy and paste.
enum SoundFeedback {
    /// UserDefaults key. Missing means off.
    nonisolated static let defaultsKey = "playsSounds"

    /// Played when a new clip is recorded.
    private static let copySoundName = "Bottle"
    /// Played when a clip is pasted from the panel.
    private static let pasteSoundName = "Tink"

    /// Whether sounds are on.
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    /// Plays the copy sound when sounds are on.
    @MainActor
    static func playCopy() {
        play(copySoundName)
    }

    /// Plays the paste sound when sounds are on.
    @MainActor
    static func playPaste() {
        play(pasteSoundName)
    }

    /// - Parameter name: A system sound name from /System/Library/Sounds.
    @MainActor
    private static func play(_ name: String) {
        guard isEnabled, let sound = NSSound(named: NSSound.Name(name)) else { return }
        // Restart a sound still playing from a quick previous copy.
        sound.stop()
        sound.play()
    }
}
