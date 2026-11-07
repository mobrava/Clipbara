import SwiftUI
import SwiftData

struct ClipboardCardView: View {
    let item: ClipboardItem
    var isSelected: Bool = false
    var searchText: String = ""
    var cardWidth: CGFloat = 190
    var cardHeight: CGFloat = 240
    var pinboards: [Pinboard] = []
    var enableDrag: Bool = true
    var showsManagementMenu: Bool = true
    let onSelect: (ClipboardItem) -> Void
    let onPaste: (ClipboardItem) -> Void
    var onDelete: (() -> Void)? = nil
    var onRemoveFromPinboard: (() -> Void)? = nil
    /// The pinboard this card is shown in, if any. Its cards get Rename, Move
    /// and Add to other pinboards.
    var currentPinboardID: UUID? = nil
    var onMoveToPinboard: ((Pinboard) -> Void)? = nil

    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var isHovered = false
    @State private var isRenaming = false
    @State private var renameText = ""

    var body: some View {
        if item.isDeleted || item.modelContext == nil {
            EmptyView()
        } else {
            cardBody
        }
    }

    private var cardBody: some View {
        cardSurface
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                appState.hoveredClipID = item.id
            } else if appState.hoveredClipID == item.id {
                appState.hoveredClipID = nil
            }
        }
        .onTapGesture(perform: handleTap)
        .optionalDrag(enabled: enableDrag) {
            appState.draggedClipboardItemID = item.id
            appState.draggedPinboardEntry = nil
            return item.dragProvider()
        } preview: {
            dragPreview
        }
        .optionalContextMenu(enabled: hasMenu) {
            menuItems
        }
        .alert("Rename", isPresented: $isRenaming) {
            TextField("Card name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                // Clearing the field, or leaving the type name that was
                // filled in, goes back to showing the type.
                item.userTitle = trimmed.isEmpty || trimmed == item.contentType.displayName ? nil : trimmed
                try? modelContext.save()
            }
        }
    }

    private var hasMenu: Bool {
        showsManagementMenu || onRemoveFromPinboard != nil
    }

    @ViewBuilder
    private var menuItems: some View {
        if PasteService.supportsPlainText(item) {
            Button("Paste with Formatting") { appState.paste(item, asPlainText: false) }
            Button("Paste as Plain Text") { appState.paste(item, asPlainText: true) }
        } else {
            Button("Paste") { onPaste(item) }
        }
        let otherPinboards = pinboards.filter { $0.id != currentPinboardID }
        if showsManagementMenu || currentPinboardID != nil {
            Divider()
            Button("Rename") {
                // Start from the name the header shows: the user's title, or
                // the type name for a clip that was never renamed.
                renameText = item.userTitle ?? item.contentType.displayName
                isRenaming = true
            }
            if AppState.canEdit(item) {
                Button("Edit Text\u{2026}") { appState.editClip(item) }
            }
            if let onMoveToPinboard, !otherPinboards.isEmpty {
                Menu("Move to Pinboard") {
                    ForEach(otherPinboards) { pinboard in
                        Button(pinboard.name) { onMoveToPinboard(pinboard) }
                    }
                }
            }
            if !otherPinboards.isEmpty {
                Menu("Add to Pinboard") {
                    ForEach(otherPinboards) { pinboard in
                        let alreadyAdded = pinboard.entries.contains { $0.clipboardItem?.id == item.id }
                        Button {
                            addToPinboard(pinboard)
                        } label: {
                            if alreadyAdded {
                                Label(pinboard.name, systemImage: "checkmark")
                            } else {
                                Text(pinboard.name)
                            }
                        }
                        .disabled(alreadyAdded)
                    }
                }
            }
        }
        if showsManagementMenu {
            Divider()
            Button("Delete Clip", role: .destructive) {
                deleteItem()
                onDelete?()
            }
        }
        if let onRemoveFromPinboard {
            Divider()
            Button("Remove from Pinboard", role: .destructive) {
                onRemoveFromPinboard()
            }
        }
    }

    /// No padding of its own: the header runs edge to edge, and the content
    /// and footer each set their own insets.
    /// How far the content runs under the header; see `cardSurface`.
    private static let headerOverlap: CGFloat = 1

    private var cardSurface: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // Room for the header, less the strip the content runs under it.
                Color.clear
                    .frame(height: DesignTokens.Card.headerHeight - Self.headerOverlap)

                contentView

                footerView
            }

            // On top of the content's first `headerOverlap` points. Two solid
            // fills meeting edge to edge (header over an image or a color)
            // flashed a hairline of the card background while the hover lift
            // animated across fractional pixels; overlapping them leaves no seam.
            headerView
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(cardFillColor)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Card.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Card.cornerRadius, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? DesignTokens.Selection.borderColor
                        : (isHovered
                            ? DesignTokens.Card.hoverBorderColor(for: colorScheme)
                            : DesignTokens.Card.borderColor(for: colorScheme)),
                    lineWidth: isSelected
                        ? DesignTokens.Selection.borderWidth
                        : DesignTokens.Selection.defaultBorderWidth
                )
        )
        .shadow(
            color: cardShadowColor,
            radius: isSelected ? DesignTokens.Selection.selectedShadowRadius
                : (isHovered ? DesignTokens.Selection.hoverShadowRadius : DesignTokens.Selection.defaultShadowRadius),
            y: isSelected ? DesignTokens.Selection.selectedShadowY
                : (isHovered ? DesignTokens.Selection.hoverShadowY : DesignTokens.Selection.defaultShadowY)
        )
        .offset(y: isHovered && !isSelected ? DesignTokens.Selection.hoverLift : 0)
        .zIndex(isHovered ? 1 : 0)
        .animation(DesignTokens.Selection.hoverAnimation, value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var dragPreview: some View {
        cardSurface
            .opacity(0.36)
            .scaleEffect(0.94)
    }

    private func handleTap() {
        onSelect(item)
        onPaste(item)
    }

    // MARK: - Header View

    /// A band in the clip type's color with the type and time on the left
    /// and the source app's icon, whole, on the right.
    private var headerView: some View {
        let headerHeight = DesignTokens.Card.headerHeight
        // The icon's visible rounded square.
        let iconBodySize = DesignTokens.Header.appIconBodySize
        // The image, transparent margin included.
        let iconSize = iconBodySize / DesignTokens.Header.appIconBodyRatio
        // Transparent margin on each side of the image.
        let iconMargin = (iconSize - iconBodySize) / 2
        // Spacing between items in the header row.
        let itemSpacing: CGFloat = 6
        // Room the icon takes at the header's right end, gap to the label included.
        let iconReservedWidth = iconBodySize + DesignTokens.Header.appIconTrailingPadding + itemSpacing

        return ZStack(alignment: .trailing) {
            DesignTokens.headerColor(for: item.contentType, itemColor: item.textContent)

            HStack(spacing: itemSpacing) {
                typeLabel

                Text(RelativeTimeFormatter.string(for: item.copiedAt))
                    .font(DesignTokens.Header.subtitleFont)
                    .foregroundStyle(headerTextColor.opacity(DesignTokens.Header.subtitleOpacity))
                    .lineLimit(1)

                Spacer(minLength: 4)
            }
            .padding(.leading, DesignTokens.Card.headerLeadingPadding)
            // Keep the label clear of the icon.
            .padding(.trailing, item.sourceAppBundleId == nil ? 0 : iconReservedWidth)

            if let bundleId = item.sourceAppBundleId {
                Image(nsImage: AppIconProvider.icon(for: bundleId, size: iconSize * 2))
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    // The image's own transparent margin counts toward the gap.
                    .padding(.trailing, DesignTokens.Header.appIconTrailingPadding - iconMargin)
            }
        }
        .frame(height: headerHeight)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    /// Text color on the header band.
    private var headerTextColor: Color {
        DesignTokens.headerTextColor(for: item.contentType, itemColor: item.textContent)
    }

    /// The clip's type (or the name the user gave it) as an icon and label.
    private var typeLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: item.contentType.systemImage)
                .font(DesignTokens.Header.typeIconFont)

            Text(item.userTitle ?? item.contentType.displayName)
                .font(DesignTokens.Header.titleFont)
                .lineLimit(1)
        }
        .foregroundStyle(headerTextColor)
    }

    // MARK: - Footer View

    /// The clip's size or length centered under the content, with the
    /// actions menu at the right.
    private var footerView: some View {
        ZStack {
            Text(footerInfo)
                .font(DesignTokens.Footer.font)
                .foregroundStyle(DesignTokens.Footer.textColor(for: colorScheme))
                .lineLimit(1)
                .truncationMode(.middle)
                // Room for the menu on both sides keeps the text centered on
                // the card without running under the menu.
                .padding(.horizontal, hasMenu ? 28 : 0)

            HStack {
                Spacer()

                if hasMenu {
                    Menu {
                        menuItems
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignTokens.Footer.textColor(for: colorScheme))
                            .opacity(isHovered || isSelected ? 0.72 : 0.34)
                            .frame(width: 24, height: 18)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("More actions")
                }
            }
        }
        .padding(.horizontal, DesignTokens.Card.footerHorizontalPadding)
        .frame(height: DesignTokens.Card.footerHeight)
    }

    private var footerInfo: String {
        switch item.contentType {
        case .plainText, .richText, .html, .unknown:
            let count = item.textContent?.count ?? 0
            if count >= 1000 {
                let thousands = String(format: "%.1f", Double(count) / 1000)
                return String(localized: "\(thousands)K chars")
            }
            return String(localized: "\(count) chars")
        case .url:
            // The type is already in the header; the domain says where it goes.
            guard let text = item.textContent, let host = URL(string: text)?.host() else {
                return String(localized: "URL")
            }
            return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        case .fileURL:
            switch ClipMetadata.fileInfo(for: item) {
            case .file(let byteCount):
                return ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
            case .folder:
                return String(localized: "Folder")
            case .missing:
                return String(localized: "File Not Found")
            }
        case .image:
            let size = ByteCountFormatter.string(fromByteCount: Int64(item.rawData.count), countStyle: .file)
            guard let info = ClipMetadata.imageInfo(for: item) else { return size }
            // Format, pixel size, then bytes: "PNG · 1920 × 1080 · 828 KB".
            let dimensions = "\(info.pixelWidth) × \(info.pixelHeight)"
            return [info.formatName, dimensions, size].compactMap { $0 }.joined(separator: " · ")
        case .color:
            return item.textContent ?? ""
        }
    }

    // MARK: - Card Background

    private var cardFillColor: Color {
        if isSelected {
            return colorScheme == .dark
                ? Color(red: 0.105, green: 0.125, blue: 0.165)
                : Color(red: 0.965, green: 0.975, blue: 1.0)
        }
        return DesignTokens.Card.backgroundColor(for: colorScheme)
    }

    private var cardShadowColor: Color {
        if isSelected {
            return DesignTokens.Selection.borderColor.opacity(DesignTokens.Selection.selectedShadowOpacity)
        }
        return .black.opacity(isHovered ? DesignTokens.Selection.hoverShadowOpacity : DesignTokens.Selection.defaultShadowOpacity)
    }

    // MARK: - Content

    private var contentView: some View {
        Group {
            if item.contentType == .image || item.contentType == .color {
                // Edge to edge between the header and the footer.
                cardContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                cardContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, DesignTokens.Body.padding)
                    // The first `headerOverlap` points sit under the header.
                    .padding(.top, DesignTokens.Body.padding + Self.headerOverlap)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    @ViewBuilder
    private var cardContent: some View {
        switch item.contentType {
        case .plainText, .richText, .html:
            TextCardContent(item: item, searchText: searchText)
        case .image:
            ImageCardContent(item: item)
        case .url:
            LinkCardContent(item: item, searchText: searchText)
        case .fileURL:
            FileCardContent(item: item, searchText: searchText)
        case .color:
            ColorCardContent(item: item)
        case .unknown:
            TextCardContent(item: item, searchText: searchText)
        }
    }

    private func addToPinboard(_ pinboard: Pinboard) {
        let nextOrder = (pinboard.entries.map(\.displayOrder).max() ?? -1) + 1
        let entry = PinboardEntry(clipboardItem: item, pinboard: pinboard, displayOrder: nextOrder)
        modelContext.insert(entry)
        item.isPinned = true
        try? modelContext.save()
    }

    private func deleteItem() {
        appState.deleteClip(item)
    }
}

// MARK: - Conditional Drag Modifier

private extension View {
    @ViewBuilder
    func optionalDrag<Preview: View>(
        enabled: Bool,
        provider: @escaping () -> NSItemProvider,
        @ViewBuilder preview: () -> Preview
    ) -> some View {
        if enabled {
            self.onDrag(provider, preview: preview)
        } else {
            self
        }
    }

    @ViewBuilder
    func optionalContextMenu<Content: View>(
        enabled: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if enabled {
            self.contextMenu(menuItems: content)
        } else {
            self
        }
    }
}
