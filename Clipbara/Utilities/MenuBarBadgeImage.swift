import AppKit

/// Menu bar icon for a build with a badge (`Bundle.buildBadge`): the clipboard symbol
/// followed by the badge text.
@MainActor
enum MenuBarBadgeImage {
    /// The icon for this build, or nil when it has no badge and uses the plain symbol.
    static let current: NSImage? = Bundle.main.buildBadge.map { make(badge: $0) }

    /// Draws the clipboard symbol and the badge as one template image, so it follows
    /// the menu bar's light and dark appearance.
    /// - Parameter badge: text drawn after the symbol, such as "DEV"
    /// - Returns: the combined template image
    static func make(badge: String) -> NSImage {
        /// Menu bar icon height in points.
        let height: CGFloat = 18
        /// Gap between the symbol and the badge.
        let gap: CGFloat = 2
        /// Size of the symbol, to size the combined image.
        let symbolSize = symbol().size
        /// Size of the badge text, to size the combined image.
        let tagSize = tag(badge).size()

        /// The combined image, drawn on demand at the menu bar's scale.
        let image = NSImage(
            size: NSSize(width: symbolSize.width + gap + tagSize.width, height: height),
            flipped: false
        ) { _ in
            // Parts are rebuilt here: the drawing handler may run off the main actor.
            /// The symbol, drawn at the left.
            let symbol = symbol()
            /// The badge text, drawn after the symbol.
            let tag = tag(badge)
            symbol.draw(in: NSRect(
                x: 0, y: (height - symbol.size.height) / 2,
                width: symbol.size.width, height: symbol.size.height
            ))
            tag.draw(at: NSPoint(x: symbol.size.width + gap, y: (height - tag.size().height) / 2))
            return true
        }
        image.isTemplate = true
        return image
    }

    /// The menu bar symbol (`DesignTokens.MenuBar.symbolName`) at menu bar size.
    nonisolated private static func symbol() -> NSImage {
        /// Size and weight matching the system's own menu bar icons.
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        return NSImage(systemSymbolName: DesignTokens.MenuBar.symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) ?? NSImage()
    }

    /// The badge text drawn after the symbol.
    /// - Parameter badge: text to draw, such as "DEV"
    nonisolated private static func tag(_ badge: String) -> NSAttributedString {
        NSAttributedString(string: badge, attributes: [
            .font: NSFont.systemFont(ofSize: 9, weight: .heavy),
            .foregroundColor: NSColor.black,
        ])
    }
}
