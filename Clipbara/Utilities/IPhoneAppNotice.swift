import Foundation

/// A one-time banner telling people who already use Clipbara on the Mac that
/// the iPhone app is out.
///
/// The two builds need different messages. Sync only exists in the App Store
/// build, so the DMG/Homebrew build points to the App Store edition, while the
/// App Store build points to the sync setting and goes away once sync is on.
///
/// Sparkle release notes and App Store "What's New" don't reach people who
/// update automatically or through `brew upgrade`, so the notice lives in the app.
enum IPhoneAppNotice {
    static let dismissedDefaultsKey = "iPhoneAppNoticeDismissed.1.5"

    static let appStoreURL = URL(string: "macappstore://apps.apple.com/app/id6803537696")!

    static func shouldShow(defaults: UserDefaults = .standard, syncEnabled: Bool) -> Bool {
        !defaults.bool(forKey: dismissedDefaultsKey) && !syncEnabled
    }

    static func dismiss(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: dismissedDefaultsKey)
    }
}
