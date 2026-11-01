import SwiftUI

enum DesignTokens {
    // MARK: - Content Type Accent Colors

    static func typeTint(for contentType: ContentType, itemColor: String? = nil) -> Color {
        switch contentType {
        case .plainText, .richText, .html:
            return Color(red: 0.247, green: 0.388, blue: 0.886) // #3F63E2
        case .image:
            return Color(red: 0.169, green: 0.231, blue: 0.584) // #2B3B95
        case .url:
            return Color(red: 0.0, green: 0.588, blue: 0.533)   // #009688 teal
        case .fileURL:
            return Color(red: 0.898, green: 0.494, blue: 0.129) // #E57E21 orange
        case .color:
            if let hex = itemColor {
                return Color(hex: hex) ?? Color.gray
            }
            return Color.gray
        case .unknown:
            return Color(red: 0.247, green: 0.388, blue: 0.886)
        }
    }

    static func headerColor(for contentType: ContentType, itemColor: String? = nil) -> Color {
        typeTint(for: contentType, itemColor: itemColor)
    }

    // MARK: - Card

    enum Card {
        static let cornerRadius: CGFloat = 8
        static let topPadding: CGFloat = 8
        static let horizontalPadding: CGFloat = 10
        static let contentSpacing: CGFloat = 6

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
    }

    // MARK: - Card Header

    enum Header {
        static let titleFont: Font = .system(size: 12, weight: .semibold)
        static let subtitleFont: Font = .system(size: 11, weight: .regular)
        static let subtitleOpacity: Double = 0.8
        static let appIconSize: CGFloat = 26
        static let appIconCornerRadius: CGFloat = 6
        static let badgeVerticalPadding: CGFloat = 3
        static let badgeHorizontalPadding: CGFloat = 7
        static let badgeCornerRadius: CGFloat = 6
    }

    // MARK: - Card Body

    enum Body {
        static let padding: CGFloat = 10
        static let fontSize: CGFloat = 12
        static let lineSpacing: CGFloat = 4
        static let maxLines: Int = 4

        static func textColor(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color(white: 0.88)
                : Color(white: 0.20)
        }
    }

    // MARK: - Card Footer Badge

    enum Badge {
        static let font: Font = .system(size: 11, weight: .medium)
        static let verticalPadding: CGFloat = 4
        static let horizontalPadding: CGFloat = 8
        static let cornerRadius: CGFloat = 8

        static func backgroundColor(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color.white.opacity(0.08)
                : Color.black.opacity(0.06)
        }

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
        static let selectedShadowOpacity: Double = 0.24
        static let selectedShadowRadius: CGFloat = 12
        static let defaultShadowOpacity: Double = 0.06
        static let defaultShadowRadius: CGFloat = 2
        static let hoverShadowOpacity: Double = 0.20
        static let hoverShadowRadius: CGFloat = 12
        static let hoverScale: CGFloat = 1.035
        static let hoverLift: CGFloat = -3
        static let hoverBorderWidth: CGFloat = 1.25
    }

    // MARK: - Navigation Bar

    enum Nav {
        static let height: CGFloat = 44
        static let horizontalPadding: CGFloat = 16
        static let tabHeight: CGFloat = 28
        static let tabCornerRadius: CGFloat = 8
        static let activeFont: Font = .system(size: 13, weight: .medium)
        static let inactiveFont: Font = .system(size: 13, weight: .regular)
        static let dotSize: CGFloat = 8
        static let searchIconSize: CGFloat = 16
        static let searchWidth: CGFloat = 260

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

    // MARK: - Menu Bar

    enum MenuBar {
        /// SF Symbol of the menu bar icon, also shown where the UI points to it.
        static let symbolName = "clipboard"
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
