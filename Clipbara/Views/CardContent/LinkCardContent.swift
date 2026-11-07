import SwiftUI

struct LinkCardContent: View {
    let item: ClipboardItem
    var searchText: String = ""
    @Environment(\.colorScheme) private var colorScheme

    private var urlString: String {
        item.textContent ?? ""
    }

    var body: some View {
        // The full address reads like text; the domain is in the footer.
        Text(TextHighlighter.highlight(urlString, query: searchText))
            .font(.system(size: DesignTokens.Body.fontSize))
            .lineSpacing(DesignTokens.Body.lineSpacing)
            .foregroundStyle(DesignTokens.Body.textColor(for: colorScheme))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .cardBodyFade()
    }
}
