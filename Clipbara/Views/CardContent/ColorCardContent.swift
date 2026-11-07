import SwiftUI
import AppKit

struct ColorCardContent: View {
    let item: ClipboardItem

    private var hexString: String {
        item.textContent ?? "#000000"
    }

    private var color: Color {
        Color(nsColor: NSColor.fromHex(hexString) ?? .black)
    }

    /// The swatch fills the card body edge to edge; the hex value is in the footer.
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
