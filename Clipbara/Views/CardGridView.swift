import SwiftUI
import SwiftData

struct CardGridView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \ClipboardItem.copiedAt, order: .reverse)
    private var items: [ClipboardItem]
    @Query(sort: \Pinboard.displayOrder)
    private var pinboards: [Pinboard]

    @State private var filteredItems: [ClipboardItem] = []

    var body: some View {
        Group {
            if filteredItems.isEmpty {
                PanelEmptyState(
                    title: appState.searchState.isActive ? "No Results" : "Copy anything",
                    systemImage: appState.searchState.isActive ? "magnifyingglass" : "clipboard",
                    message: appState.searchState.isActive
                        ? "Try a different search or filter"
                        : "Your clipboard history will appear here"
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

                    ScrollViewReader { proxy in
                        // No edge fade: fading these colorful cards into the
                        // panel's light background washed them out. A card cut
                        // off at the panel edge shows there is more to scroll.
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHGrid(rows: rows, spacing: DesignTokens.Grid.cardSpacing) {
                                ForEach(filteredItems.indices, id: \.self) { index in
                                    let item = filteredItems[index]
                                    ClipboardCardView(
                                        item: item,
                                        isSelected: appState.searchState.selectedIndex == index,
                                        searchText: appState.searchState.debouncedSearchText,
                                        cardWidth: cardW,
                                        cardHeight: cardH,
                                        pinboards: pinboards,
                                        onSelect: { _ in
                                            appState.searchState.selectedIndex = index
                                        },
                                        onPaste: { selected in
                                            appState.paste(selected)
                                        },
                                        onDelete: {
                                            restoreSelectionAfterDeletingItem(at: index)
                                        }
                                    )
                                    .id(item.id)
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
                            if let idx = newIndex, idx < filteredItems.count {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    proxy.scrollTo(filteredItems[idx].id, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: items) { _, newItems in
            if appState.selectedTab == .history {
                updateFilteredItems(from: newItems)
            }
        }
        .onChange(of: appState.selectedTab) { _, newTab in
            if newTab == .history {
                updateFilteredItems(from: items)
            }
        }
        .onChange(of: appState.panelPresentationID) { _, _ in
            if appState.selectedTab == .history {
                updateFilteredItems(from: items)
            }
        }
        .onChange(of: appState.searchState.debouncedSearchText) { _, _ in
            if appState.selectedTab == .history {
                updateFilteredItems(from: items)
            }
        }
        .onChange(of: appState.searchState.selectedContentTypes) { _, _ in
            if appState.selectedTab == .history {
                updateFilteredItems(from: items)
            }
        }
        .onChange(of: appState.searchState.dateFilter) { _, _ in
            if appState.selectedTab == .history {
                updateFilteredItems(from: items)
            }
        }
        .onAppear {
            updateFilteredItems(from: items)
        }
    }

    private func updateFilteredItems(from sourceItems: [ClipboardItem]) {
        let updated = appState.searchState.filteredItems(from: sourceItems)
        filteredItems = updated
        appState.currentFilteredItems = updated
        appState.searchState.ensureSelection(itemCount: updated.count)
    }

    private func restoreSelectionAfterDeletingItem(at deletedIndex: Int) {
        let remainingCount = max(filteredItems.count - 1, 0)
        guard remainingCount > 0 else {
            appState.searchState.selectedIndex = nil
            return
        }

        appState.searchState.selectedIndex = min(deletedIndex, remainingCount - 1)
    }
}

struct PanelEmptyState: View {
    let title: LocalizedStringKey
    let systemImage: String
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.tertiary)

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.78))

                Text(message)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
