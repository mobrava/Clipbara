import AppKit
import SwiftUI

enum DesignTokens {
    // MARK: - Content Type Accent Colors

    /// The color that marks a clip's type. macOS system colors, so each one
    /// matches the rest of the system and shifts for dark mode and Increase
    /// Contrast on its own. Every type gets its own hue.
    static func typeTint(for contentType: ContentType, itemColor: String? = nil) -> Color {
        switch contentType {
        case .plainText:
            return Color(nsColor: .systemBlue)
        case .richText:
            return Color(nsColor: .systemIndigo)
        case .html:
            return Color(nsColor: .systemPurple)
        case .image:
            return Color(nsColor: .systemPink)
        case .url:
            return Color(nsColor: .systemTeal)
        case .fileURL:
            return Color(nsColor: .systemOrange)
        case .color:
            if let hex = itemColor {
                return Color(hex: hex) ?? Color(nsColor: .systemGray)
            }
            return Color(nsColor: .systemGray)
        case .unknown:
            return Color(nsColor: .systemGray)
        }
    }

    static func headerColor(for contentType: ContentType, itemColor: String? = nil) -> Color {
        typeTint(for: contentType, itemColor: itemColor)
    }

    /// Text on the card header. White on the type colors; a color clip's
    /// header is the clip's own color, so a light one gets dark text.
    static func headerTextColor(for contentType: ContentType, itemColor: String? = nil) -> Color {
        guard contentType == .color,
              let hex = itemColor,
              let color = NSColor.fromHex(hex)?.usingColorSpace(.sRGB) else {
            return .white
        }
        // Relative luminance (Rec. 709 weights).
        let luminance = 0.2126 * color.redComponent + 0.7152 * color.greenComponent + 0.0722 * color.blueComponent
        return luminance > 0.6 ? Color.black.opacity(0.82) : .white
    }

    // MARK: - Card

    enum Card {
        static let cornerRadius: CGFloat = 8
        /// Colored band across the top of the card, edge to edge.
        static let headerHeight: CGFloat = 36
        /// Gap between the header's left edge and its type label.
        static let headerLeadingPadding: CGFloat = 12
        static let footerHeight: CGFloat = 28
        /// Left and right inset of the footer row.
        static let footerHorizontalPadding: CGFloat = 8

        static func backgroundColor(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color(white: 0.115)
                : Color(white: 0.99)
        }

        static func borderColor(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color.white.opacity(0.10)
                : Color.black.opacity(0.08)
        }

        /// The resting border, a step darker (lighter in dark mode).
        static func hoverBorderColor(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color.white.opacity(0.20)
                : Color.black.opacity(0.16)
        }
    }

    // MARK: - Card Grid

    /// Layout of the horizontal card row under the navigation bar. Cards take
    /// the row's full height, so the panel height decides the card size and
    /// no empty band is left above or below them.
    enum Grid {
        /// Above the cards. With the navigation bar's own 8pt below the
        /// search field this reads as the same 16pt gap as the sides, and it
        /// leaves room for the hover lift and scale.
        static let topPadding: CGFloat = 8
        static let bottomPadding: CGFloat = 16
        static let horizontalPadding: CGFloat = 16
        static let cardSpacing: CGFloat = 12
        static let minCardHeight: CGFloat = 164
        static let minCardWidth: CGFloat = 206
        /// Card width relative to its height.
        static let cardAspectRatio: CGFloat = 1.16
    }

    // MARK: - Card Header

    enum Header {
        static let titleFont: Font = .system(size: 12, weight: .semibold)
        static let typeIconFont: Font = .system(size: 11, weight: .semibold)
        static let subtitleFont: Font = .system(size: 11, weight: .regular)
        static let subtitleOpacity: Double = 0.8
        /// macOS app icons draw their rounded square at 824 of 1024 points,
        /// with transparent margin around it. Sizes below are measured on
        /// that visible square, not on the image.
        static let appIconBodyRatio: CGFloat = 824.0 / 1024.0
        /// The source app icon's visible square, whole inside the header.
        static let appIconBodySize: CGFloat = 26
        /// Gap between the icon's visible square and the card's right edge;
        /// matches the space above and below it in the 36pt header.
        static let appIconTrailingPadding: CGFloat = 5
    }

    // MARK: - Card Body

    enum Body {
        /// Inset of text-like content (text, links, files) from the card edges.
        /// Images and colors run edge to edge.
        static let padding: CGFloat = 12
        /// The macOS body text size.
        static let fontSize: CGFloat = 13
        static let lineSpacing: CGFloat = 3
        /// Height of the fade that ends body text cut off by the card.
        static let bottomFadeHeight: CGFloat = 18

        static func textColor(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color(white: 0.88)
                : Color(white: 0.20)
        }
    }

    // MARK: - Card Footer

    /// Secondary facts under the content (size, length, domain), as plain text.
    enum Footer {
        static let font: Font = .system(size: 11, weight: .regular)

        static func textColor(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color(white: 0.62)
                : Color(white: 0.40)
        }
    }

    // MARK: - Card Selection

    enum Selection {
        static let borderColor = Color(red: 0.231, green: 0.443, blue: 0.953) // #3B71F3
        static let borderWidth: CGFloat = 2.25
        static let defaultBorderWidth: CGFloat = 0.75
        // Shadows lean down (y > 0) like light from above, and stay soft:
        // resting cards barely lift off the panel, hover and selection a bit more.
        static let selectedShadowOpacity: Double = 0.22
        static let selectedShadowRadius: CGFloat = 10
        static let selectedShadowY: CGFloat = 4
        static let defaultShadowOpacity: Double = 0.06
        static let defaultShadowRadius: CGFloat = 2
        static let defaultShadowY: CGFloat = 1
        // Hover stays neutral and quiet; the accent color is for selection.
        static let hoverShadowOpacity: Double = 0.10
        static let hoverShadowRadius: CGFloat = 8
        static let hoverShadowY: CGFloat = 3
        static let hoverLift: CGFloat = -2
        static let hoverAnimation: Animation = .easeOut(duration: 0.18)
    }

    // MARK: - Navigation Bar

    enum Nav {
        static let height: CGFloat = 44
        static let horizontalPadding: CGFloat = 16
        /// Gap between the search field, toolbar dividers, tab row and action
        /// buttons: the standard 8pt spacing between related macOS controls.
        static let itemSpacing: CGFloat = 8
        static let tabHeight: CGFloat = 28
        static let tabCornerRadius: CGFloat = 8
        static let activeFont: Font = .system(size: 13, weight: .medium)
        static let inactiveFont: Font = .system(size: 13, weight: .regular)
        static let dotSize: CGFloat = 8
        static let searchIconSize: CGFloat = 16
        static let searchWidth: CGFloat = 260
        /// Narrowest the tab row gets before the search field gives way.
        static let tabGroupMinWidth: CGFloat = 120
        /// Width of the fade on a tab row edge that has more tabs past it.
        static let tabEdgeFadeWidth: CGFloat = 28

        static func activeBackground(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color.white.opacity(0.10)
                : Color.black.opacity(0.06)
        }

        static func searchBackground(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color.white.opacity(0.08)
                : Color.black.opacity(0.08)
        }

        static func activeTextColor(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color(white: 0.95)
                : Color(white: 0.16)
        }

        static func inactiveTextColor(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color(white: 0.75)
                : Color(white: 0.38)
        }
    }

    // MARK: - Checkerboard

    enum Checkerboard {
        static let cellSize: CGFloat = 8
        static let lightColor = Color.white
        static let darkColor = Color(white: 0.96) // #F5F5F5
    }
}

// MARK: - Color hex init helper

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6,
              let hexNumber = UInt64(hexSanitized, radix: 16) else {
            return nil
        }

        let r = Double((hexNumber & 0xFF0000) >> 16) / 255.0
        let g = Double((hexNumber & 0x00FF00) >> 8) / 255.0
        let b = Double(hexNumber & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
