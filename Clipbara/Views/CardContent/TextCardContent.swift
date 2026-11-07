import SwiftUI

struct TextCardContent: View {
    let item: ClipboardItem
    var searchText: String = ""
    @Environment(\.colorScheme) private var colorScheme
    @State private var isCode: Bool = false

    private var previewText: String {
        guard let text = item.textContent else { return "..." }
        let maxCharacters = 900
        if text.count <= maxCharacters {
            return text
        }
        return String(text.prefix(maxCharacters)) + "..."
    }

    var body: some View {
        Group {
            if searchText.isEmpty {
                Text(previewText)
            } else {
                Text(TextHighlighter.highlight(previewText, query: searchText))
            }
        }
        .font(.system(size: DesignTokens.Body.fontSize, design: isCode ? .monospaced : .default))
        .lineSpacing(DesignTokens.Body.lineSpacing)
        .multilineTextAlignment(.leading)
        .foregroundStyle(DesignTokens.Body.textColor(for: colorScheme))
        // As many lines as the card has room for, so a taller panel shows
        // more text instead of more empty space.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardBodyFade()
        .task(id: item.id) {
            guard let text = item.textContent else { return }
            let sample = text.prefix(900)
            let codeIndicators = ["func ", "var ", "let ", "class ", "import ", "def ", "return ", "{", "}", "=>", "->", "();", "//", "/*"]
            isCode = codeIndicators.contains { sample.contains($0) }
        }
    }
}

extension View {
    /// Fades the bottom of a card body out, so text that runs past the card
    /// trails off instead of stopping at a hard edge.
    func cardBodyFade() -> some View {
        mask {
            VStack(spacing: 0) {
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: DesignTokens.Body.bottomFadeHeight)
            }
        }
    }
}
