import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PinboardGridView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    let pinboardId: UUID

    @Query(sort: \Pinboard.displayOrder) private var allPinboards: [Pinboard]

    @State private var orderedEntries: [PinboardEntry] = []
    @State private var draggingEntry: PinboardEntry?

    private var pinboard: Pinboard? {
        allPinboards.first { $0.id == pinboardId }
    }

    var body: some View {
        Group {
            if orderedEntries.isEmpty {
                PanelEmptyState(
                    title: "Empty Pinboard",
                    systemImage: "pin.slash",
                    message: "Drag clips here or use the card menu"
                )
            } else {
                GeometryReader { geo in
                    // Card height: the whole row minus its top and bottom padding.
                    let cardH = max(
                        geo.size.height - DesignTokens.Grid.topPadding - DesignTokens.Grid.bottomPadding,
                        DesignTokens.Grid.minCardHeight
                    )
                    // Card width, kept in proportion to the height.
                    let cardW = max(cardH * DesignTokens.Grid.cardAspectRatio, DesignTokens.Grid.minCardWidth)
                    let rows = [GridItem(.fixed(cardH), spacing: 10)]
                    let pinboardItems = orderedEntries.compactMap(\.clipboardItem)

                    ScrollViewReader { proxy in
                        // No edge fade: fading these colorful cards into the
                        // panel's light background washed them out. A card cut
                        // off at the panel edge shows there is more to scroll.
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHGrid(rows: rows, spacing: DesignTokens.Grid.cardSpacing) {
                                ForEach(Array(orderedEntries.enumerated()), id: \.element.id) { index, entry in
                                    if let item = entry.clipboardItem {
                                        cardView(
                                            entry: entry,
                                            item: item,
                                            index: index,
                                            cardWidth: cardW,
                                            cardHeight: cardH
                                        )
                                        .id(entry.id)
                                    }
                                }
                            }
                            .padding(.horizontal, DesignTokens.Grid.horizontalPadding)
                            .padding(.top, DesignTokens.Grid.topPadding)
                            .padding(.bottom, DesignTokens.Grid.bottomPadding)
                        }
                        // Let hover and selection shadows spill past the row
                        // instead of being cut off under the navigation bar.
                        .scrollClipDisabled()
                        .onChange(of: appState.searchState.selectedIndex) { _, newIndex in
                            if let idx = newIndex, idx < orderedEntries.count {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    proxy.scrollTo(orderedEntries[idx].id, anchor: .center)
                                }
                            }
                        }
                    }
                    .onAppear {
                        syncNavigationItems(pinboardItems)
                    }
                    .onChange(of: orderedEntries.count) { _, _ in
                        syncNavigationItems(orderedEntries.compactMap(\.clipboardItem))
                    }
                }
            }
        }
        .onAppear { syncEntries() }
        // A drag that ended outside the grid (on a tab, or cancelled) never
        // reaches the reorder delegate, which would leave the card dimmed.
        .onChange(of: appState.draggedClipboardItemID) { _, id in
            if id == nil { draggingEntry = nil }
        }
        .onChange(of: pinboard?.entries.count) { _, _ in syncEntries() }
        .onChange(of: appState.panelPresentationID) { _, _ in
            if appState.selectedTab == .pinboard(pinboardId) {
                syncEntries()
            }
        }
    }

    @ViewBuilder
    private func cardView(entry: PinboardEntry, item: ClipboardItem, index: Int, cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        let isDragging = draggingEntry?.id == entry.id

        ClipboardCardView(
            item: item,
            isSelected: appState.searchState.selectedIndex == index,
            searchText: "",
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            pinboards: allPinboards,
            enableDrag: false,
            showsManagementMenu: false,
            onSelect: { _ in
                appState.searchState.selectedIndex = index
            },
            onPaste: { selected in
                appState.paste(selected)
            },
            onRemoveFromPinboard: {
                removeEntry(entry)
            },
            currentPinboardID: pinboardId,
            onMoveToPinboard: { destination in
                takeOut(entry) { appState.moveToPinboard(entry, destination: destination) }
            }
        )
        .opacity(isDragging ? 0.3 : 1.0)
        .scaleEffect(isDragging ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isDragging)
        .onDrag {
            draggingEntry = entry
            // Dropping on another pinboard's tab moves the clip there.
            appState.draggedClipboardItemID = item.id
            appState.draggedPinboardEntry = .init(entryID: entry.id, clipID: item.id, pinboardID: pinboardId)
            return item.dragProvider()
        }
        .onDrop(of: [.text], delegate: ReorderDropDelegate(
            target: entry,
            orderedEntries: $orderedEntries,
            draggingEntry: $draggingEntry,
            commitOrder: commitOrder
        ))
    }

    private func syncEntries() {
        let current = (pinboard?.entries ?? [])
            .filter { !$0.isDeleted && $0.clipboardItem != nil }
            .sorted { $0.displayOrder < $1.displayOrder }
        if orderedEntries.map(\.id) != current.map(\.id) {
            orderedEntries = current
        }
        syncNavigationItems(current.compactMap(\.clipboardItem))
    }

    private func syncNavigationItems(_ items: [ClipboardItem]) {
        appState.currentFilteredItems = items
        appState.searchState.ensureSelection(itemCount: items.count)
    }

    private func commitOrder() {
        for (index, entry) in orderedEntries.enumerated() {
            entry.displayOrder = index
        }
    }

    private func removeEntry(_ entry: PinboardEntry) {
        takeOut(entry) { appState.removeFromPinboard(entry) }
    }

    /// Runs `change`, which takes `entry` out of this pinboard, and keeps the
    /// selection on the card that slides into its place.
    private func takeOut(_ entry: PinboardEntry, _ change: () -> Void) {
        let removedIndex = orderedEntries.firstIndex { $0.id == entry.id } ?? appState.searchState.selectedIndex ?? 0
        orderedEntries.removeAll { $0.id == entry.id }
        change()
        syncNavigationItems(orderedEntries.compactMap(\.clipboardItem))
        if !orderedEntries.isEmpty {
            appState.searchState.selectedIndex = min(removedIndex, orderedEntries.count - 1)
        }
    }
}

// MARK: - DropDelegate

private struct ReorderDropDelegate: DropDelegate {
    let target: PinboardEntry
    @Binding var orderedEntries: [PinboardEntry]
    @Binding var draggingEntry: PinboardEntry?
    let commitOrder: () -> Void

    func dropEntered(info: DropInfo) {
        guard let source = draggingEntry, source.id != target.id else { return }
        guard let sourceIndex = orderedEntries.firstIndex(where: { $0.id == source.id }),
              let destIndex = orderedEntries.firstIndex(where: { $0.id == target.id }) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            orderedEntries.move(
                fromOffsets: IndexSet(integer: sourceIndex),
                toOffset: destIndex > sourceIndex ? destIndex + 1 : destIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        commitOrder()
        draggingEntry = nil
        return true
    }

    func dropExited(info: DropInfo) {
        // keep current order
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggingEntry != nil
    }
}
