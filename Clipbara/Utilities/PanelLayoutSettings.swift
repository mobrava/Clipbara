import AppKit

/// Card Size stores the panel height in points so the panel and its card row resize together.
enum PanelCardSize {
    /// UserDefaults key shared by Settings and the panel.
    static let defaultsKey = "panelHeight"
    /// Height of the original panel, shown as 100% in Settings.
    static let defaultHeight: Double = 280
    /// Heights available on the slider, in points.
    static let range: ClosedRange<Double> = 240...420
    /// Distance between adjacent slider stops, in points.
    static let step: Double = 10

    /// Card height limits at the default panel size.
    private static let defaultCardHeights: ClosedRange<CGFloat> = 164...188
    /// Minimum card width at the default size, including room for the header.
    private static let defaultMinimumWidth: CGFloat = 206
    /// The width-to-height ratio of the original cards.
    private static let aspectRatio: CGFloat = 1.16
    /// Space around the row for padding and hover effects.
    private static let rowInset: CGFloat = 26

    /// Current panel height, including when the preference has never been set.
    static var currentHeight: CGFloat {
        // Read the same numeric value written by AppStorage.
        let stored = UserDefaults.standard.object(forKey: defaultsKey) as? Double ?? defaultHeight
        return clampedHeight(stored)
    }

    /// - Parameter stored: The panel height read from preferences, in points.
    static func clampedHeight(_ stored: Double) -> Double {
        guard stored.isFinite else { return defaultHeight }
        return min(max(stored, range.lowerBound), range.upperBound)
    }

    /// - Parameters:
    ///   - rowHeight: Space left below navigation and the optional iPhone banner.
    ///   - panelHeight: The chosen panel height, in points.
    static func cardSize(rowHeight: CGFloat, panelHeight: Double) -> CGSize {
        // Scale the original bounds so every slider stop resizes both grids.
        let scale = clampedHeight(panelHeight) / defaultHeight
        // Reserve the original row inset even when the banner is visible.
        let height = min(max(rowHeight - rowInset, defaultCardHeights.lowerBound * scale),
                         defaultCardHeights.upperBound * scale)
        return CGSize(width: max(height * aspectRatio, defaultMinimumWidth * scale), height: height)
    }
}

/// Display used the next time the panel opens.
enum PanelScreen: String, CaseIterable {
    case pointer, activeWindow, main

    /// UserDefaults key shared by Settings and the panel.
    static let defaultsKey = "panelScreen"

    /// The original pointer-based placement also handles unrecognized preferences.
    static var current: Self {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(Self.init(rawValue:)) ?? .pointer
    }

    var displayName: String {
        switch self {
        case .pointer: String(localized: "Screen with Pointer")
        case .activeWindow: String(localized: "Screen with Active Window")
        case .main: String(localized: "Main Screen")
        }
    }

    /// Finds the display containing the largest visible part of the front window.
    /// - Parameter screens: Connected displays in AppKit order, primary display first.
    @MainActor
    static func frontWindowScreen(in screens: [NSScreen]) -> NSScreen? {
        // Clipbara's own Settings window can float above normal windows.
        if NSApp.isActive, let screen = NSApp.keyWindow?.screen { return screen }

        // WindowServer returns onscreen windows in front-to-back order.
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]],
              let front = windows.first(where: {
                  ($0[kCGWindowOwnerPID as String] as? pid_t) == pid
                      && ($0[kCGWindowLayer as String] as? Int) == NSWindow.Level.normal.rawValue
              }),
              let bounds = front[kCGWindowBounds as String] as? NSDictionary,
              let window = CGRect(dictionaryRepresentation: bounds),
              let index = screenIndex(forWindow: window, in: screens.map(\.frame)) else { return nil }
        return screens[index]
    }

    /// - Parameters:
    ///   - window: WindowServer bounds measured downwards from the primary display's top edge.
    ///   - frames: AppKit display frames, primary display first.
    static func screenIndex(forWindow window: CGRect, in frames: [CGRect]) -> Int? {
        guard let primary = frames.first else { return nil }
        // Flip into AppKit coordinates before comparing displays above or below the primary one.
        let bounds = CGRect(x: window.minX, y: primary.maxY - window.maxY,
                            width: window.width, height: window.height)
        // A display must overlap the window by a positive area.
        var largestArea: CGFloat = 0
        // Keep the first display in AppKit order when the overlap is tied.
        var selectedIndex: Int?
        for (index, frame) in frames.enumerated() {
            // Edge contact has zero area and leaves the pointer fallback available.
            let overlap = frame.intersection(bounds)
            let area = overlap.width * overlap.height
            if area > largestArea {
                largestArea = area
                selectedIndex = index
            }
        }
        return selectedIndex
    }
}
