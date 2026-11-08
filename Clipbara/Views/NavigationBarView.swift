import SwiftUI
import SwiftData
import UniformTypeIdentifiers

private enum DroppedClipResult {
    case added(String)
    case alreadyAdded(String)
    case missing
}

struct NavigationBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openSettings) private var openSettings
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pinboard.displayOrder) private var pinboards: [Pinboard]
    @Query(sort: \ClipboardItem.copiedAt, order: .reverse) private var historyItems: [ClipboardItem]
    @Query private var pinboardEntries: [PinboardEntry]

    @State private var isAddingPinboard = false
    @State private var newPinboardName = ""
    @State private var renamingPinboard: Pinboard?
    @State private var deletingPinboard: Pinboard?
    @State private var targetedPinboardID: UUID?
    /// The pinboard tab being dragged to a new position (#3).
    @State private var draggingPinboardID: UUID?
    /// Where the dragged tab would land: a blue bar before or after a tab.
    @State private var tabDropIndicator: TabDropIndicator?
    @State private var renameText = ""
    @State private var isShowingClearAlert = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        navigationBar
        .frame(height: DesignTokens.Nav.height)
        .onAppear {
            appState.orderedPinboardIDs = pinboards.map(\.id)
            let openSettings = openSettings
            appState.openSettingsAction = { openSettings() }
        }
        .onChange(of: pinboards.map(\.id)) { _, ids in
            appState.orderedPinboardIDs = ids
        }
        .alert("Create Pinboard", isPresented: $isAddingPinboard) {
            TextField("Name", text: $newPinboardName)
            Button("Cancel", role: .cancel) { newPinboardName = "" }
            Button("Create") { createPinboard() }
        }
        .onChange(of: appState.clearHistoryRequested) { _, newValue in
            if newValue {
                appState.clearHistoryRequested = false
                isShowingClearAlert = clearableHistoryCount > 0
            }
        }
        .alert("Clear Clipboard History?", isPresented: $isShowingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear History", role: .destructive) { clearHistory() }
        } message: {
            Text("This deletes \(clearableHistoryCount) unpinned clips from history. Pinboard items stay available.")
        }
        .alert("Delete Pinboard?", isPresented: .init(
            get: { deletingPinboard != nil },
            set: { if !$0 { deletingPinboard = nil } }
        )) {
            Button("Cancel", role: .cancel) { deletingPinboard = nil }
            Button("Delete Pinboard", role: .destructive) {
                if let deletingPinboard {
                    deletePinboard(deletingPinboard)
                }
                deletingPinboard = nil
            }
        } message: {
            Text("This removes the pinboard only. The clips stay in clipboard history.")
        }
        .alert("Rename Pinboard", isPresented: .init(
            get: { renamingPinboard != nil },
            set: { if !$0 { renamingPinboard = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { renamingPinboard = nil }
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    renamingPinboard?.name = trimmed
                    try? modelContext.save()
                }
                renamingPinboard = nil
            }
        }
    }

    // MARK: - Navigation Bar (default state)

    private var navigationBar: some View {
        HStack(spacing: 12) {
            searchField

            toolbarDivider

            tabGroup
                .frame(minWidth: 120)
                .layoutPriority(1)

            Spacer(minLength: 8)

            toolbarDivider

            actionGroup
        }
        .padding(.horizontal, DesignTokens.Nav.horizontalPadding)
    }

    private var tabGroup: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    navTab(
                        label: String(localized: "History"),
                        icon: "clock",
                        isActive: appState.selectedTab == .history,
                        shortcutNumber: 1
                    ) {
                        appState.panelController.selectTab(.history)
                    }
                    .id(PanelTab.history)
                    .help("History (⌘1)")

                    if !pinboards.isEmpty {
                        Divider()
                            .frame(height: 18)
                            .padding(.horizontal, 2)
                    }

                    ForEach(Array(pinboards.enumerated()), id: \.element.id) { index, pinboard in
                        navTab(
                            label: pinboard.name,
                            icon: "folder",
                            isActive: appState.selectedTab == .pinboard(pinboard.id),
                            isDropTargeted: targetedPinboardID == pinboard.id,
                            shortcutNumber: index + 2 <= 9 ? index + 2 : nil
                        ) {
                            appState.panelController.selectTab(.pinboard(pinboard.id))
                        }
                        .id(PanelTab.pinboard(pinboard.id))
                        .help(PanelTabShortcut.hint(at: index + 1).map { "\(pinboard.name) (\($0))" } ?? pinboard.name)
                        .onDrag {
                            draggingPinboardID = pinboard.id
                            let provider = NSItemProvider()
                            provider.registerDataRepresentation(
                                forTypeIdentifier: UTType.clipbaraPinboardTab.identifier,
                                visibility: .ownProcess
                            ) { [id = pinboard.id] completion in
                                completion(id.uuidString.data(using: .utf8), nil)
                                return nil
                            }
                            return provider
                        }
                        .onDrop(
                            of: [.clipbaraPinboardTab, .pasteClipClipboardItemID, .text, .url, .fileURL, .image, .data, .item],
                            delegate: PinboardTabDropDelegate(
                                pinboardID: pinboard.id,
                                draggingPinboardID: $draggingPinboardID,
                                targetedPinboardID: $targetedPinboardID,
                                indicator: $tabDropIndicator,
                                landingEdge: landingEdge(on:),
                                moveTab: moveDraggedTab(to:),
                                dropClips: { providers in addDroppedClip(from: providers, to: pinboard.id) }
                            )
                        )
                        .overlay(alignment: tabDropIndicator?.edge == .trailing ? .trailing : .leading) {
                            if tabDropIndicator?.pinboardID == pinboard.id {
                                RoundedRectangle(cornerRadius: 1, style: .continuous)
                                    .fill(Color.accentColor)
                                    .frame(width: 2, height: 20)
                                    .offset(x: tabDropIndicator?.edge == .trailing ? 3 : -3)
                                    .allowsHitTesting(false)
                            }
                        }
                        .contextMenu {
                            Button("Rename Pinboard") {
                                renameText = pinboard.name
                                renamingPinboard = pinboard
                            }
                            Divider()
                            Button("Delete Pinboard", role: .destructive) {
                                deletingPinboard = pinboard
                            }
                        }
                    }
                }
            }
            .onChange(of: appState.selectedTab) { _, tab in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(tab, anchor: .center)
                }
            }
        }
    }

    private var actionGroup: some View {
        HStack(spacing: 4) {
            optionsMenuButton

            NavIconButton(
                icon: "plus",
                iconSize: 12,
                colorScheme: colorScheme
            ) {
                newPinboardName = nextPinboardName()
                isAddingPinboard = true
            }
            .help("New Pinboard")

            if appState.selectedTab == .history {
                NavIconButton(
                    icon: "trash",
                    iconSize: 13,
                    colorScheme: colorScheme
                ) {
                    isShowingClearAlert = true
                }
                .disabled(clearableHistoryCount == 0)
                .opacity(clearableHistoryCount == 0 ? 0.45 : 1)
                .help(clearableHistoryCount == 0
                    ? String(localized: "No unpinned history to clear")
                    : String(localized: "Clear Clipboard History"))
            }
        }
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.10))
            .frame(width: 1, height: 20)
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)

            TextField("Search clipboard...", text: searchTextBinding)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(DesignTokens.Nav.activeTextColor(for: colorScheme))
                .focused($isSearchFocused)

            if !appState.searchState.searchText.isEmpty {
                Button {
                    appState.searchState.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: DesignTokens.Nav.searchWidth, height: DesignTokens.Nav.tabHeight)
        .background(DesignTokens.Nav.searchBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Nav.tabCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Nav.tabCornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.07), lineWidth: 0.75)
        )
    }

    // MARK: - Tab Component

    private func navTab(
        label: String,
        icon: String? = nil,
        isActive: Bool,
        isDropTargeted: Bool = false,
        shortcutNumber: Int? = nil,
        action: @escaping () -> Void
    ) -> some View {
        NavTabButton(
            label: label,
            icon: icon,
            isActive: isActive,
            isDropTargeted: isDropTargeted,
            shortcutNumber: appState.showsTabShortcutHints ? shortcutNumber : nil,
            colorScheme: colorScheme,
            action: action
        )
    }

    // MARK: - Bindings & Actions

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { appState.searchState.searchText },
            set: { appState.searchState.updateSearch($0) }
        )
    }

    private var optionsMenuButton: some View {
        OptionsMenuButton(
            colorScheme: colorScheme,
            searchState: appState.searchState
        )
    }

    private var pinnedItemIDs: Set<UUID> {
        Set(pinboardEntries.compactMap { $0.clipboardItem?.id })
    }

    private var clearableHistoryItems: [ClipboardItem] {
        let pinned = pinnedItemIDs
        return historyItems.filter { !pinned.contains($0.id) }
    }

    private var clearableHistoryCount: Int {
        clearableHistoryItems.count
    }

    /// A tab dragged leftward lands before the tab under the pointer, one
    /// dragged rightward after it, so every gap is reachable. nil over itself.
    private func landingEdge(on target: UUID) -> HorizontalEdge? {
        guard let dragged = draggingPinboardID, dragged != target,
              let from = pinboards.firstIndex(where: { $0.id == dragged }),
              let to = pinboards.firstIndex(where: { $0.id == target }) else { return nil }
        return to < from ? .leading : .trailing
    }

    /// Moves the dragged tab to `target`'s position and saves the order.
    /// Tabs don't shuffle while dragging (a moving tab slid out from under
    /// the pointer and swapped back); the blue bar shows the landing spot.
    private func moveDraggedTab(to target: UUID) {
        guard let dragged = draggingPinboardID, dragged != target else { return }
        var order = pinboards
        guard let from = order.firstIndex(where: { $0.id == dragged }),
              let to = order.firstIndex(where: { $0.id == target }) else { return }
        order.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        withAnimation(.easeInOut(duration: 0.18)) {
            for (index, pinboard) in order.enumerated() where pinboard.displayOrder != index {
                pinboard.displayOrder = index
            }
            try? modelContext.save()
        }
        appState.orderedPinboardIDs = order.map(\.id)
    }

    private func createPinboard() {
        let trimmed = newPinboardName.trimmingCharacters(in: .whitespaces)
        let name = trimmed.isEmpty ? nextPinboardName() : uniquePinboardName(preferred: trimmed)
        let nextOrder = (pinboards.map(\.displayOrder).max() ?? -1) + 1
        let pinboard = Pinboard(name: name, displayOrder: nextOrder)
        modelContext.insert(pinboard)
        try? modelContext.save()
        newPinboardName = ""
        // Keep shortcut positions current until @Query publishes the insert.
        appState.orderedPinboardIDs = pinboards.filter { $0.id != pinboard.id }.map(\.id) + [pinboard.id]
        appState.panelController.selectTab(.pinboard(pinboard.id))
    }

    private func clearHistory() {
        for item in clearableHistoryItems {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }

    private func addDroppedClip(from providers: [NSItemProvider], to pinboardId: UUID) -> Bool {
        if let draggedID = appState.draggedClipboardItemID {
            dropClip(itemId: draggedID, on: pinboardId)
            targetedPinboardID = nil
            appState.finishClipboardDrag()
            return true
        }

        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.pasteClipClipboardItemID.identifier)
        }) else {
            return false
        }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.pasteClipClipboardItemID.identifier) { data, _ in
            guard
                let data,
                let idString = String(data: data, encoding: .utf8),
                let itemId = UUID(uuidString: idString)
            else { return }

            Task { @MainActor in
                dropClip(itemId: itemId, on: pinboardId)
                targetedPinboardID = nil
                appState.finishClipboardDrag()
            }
        }

        return true
    }

    /// A card from another pinboard moves; one from History is added.
    private func dropClip(itemId: UUID, on pinboardId: UUID) {
        guard !appState.dropDraggedPinboardEntry(clipID: itemId, on: pinboardId) else { return }
        showDropResult(addClip(itemId: itemId, toPinboard: pinboardId))
    }

    private func addClip(itemId: UUID, toPinboard pinboardId: UUID) -> DroppedClipResult {
        guard
            let item = historyItems.first(where: { $0.id == itemId }),
            let pinboard = pinboards.first(where: { $0.id == pinboardId })
        else {
            return .missing
        }

        let alreadyAdded = pinboard.entries.contains { $0.clipboardItem?.id == itemId }
        guard !alreadyAdded else { return .alreadyAdded(pinboard.name) }

        let nextOrder = (pinboard.entries.map(\.displayOrder).max() ?? -1) + 1
        let entry = PinboardEntry(clipboardItem: item, pinboard: pinboard, displayOrder: nextOrder)
        modelContext.insert(entry)
        item.isPinned = true
        try? modelContext.save()
        return .added(pinboard.name)
    }

    private func showDropResult(_ result: DroppedClipResult) {
        switch result {
        case .added(let name):
            appState.showToast(String(localized: "Added to \(name)"))
        case .alreadyAdded(let name):
            appState.showToast(String(localized: "Already in \(name)"), systemImage: "checkmark.circle")
        case .missing:
            appState.showToast(String(localized: "Could not add clip"), systemImage: "exclamationmark.triangle.fill")
        }
    }

    private func nextPinboardName() -> String {
        uniquePinboardName(preferred: String(localized: "Pinboard"))
    }

    private func uniquePinboardName(preferred: String) -> String {
        let existingNames = Set(pinboards.map(\.name))
        guard existingNames.contains(preferred) else { return preferred }

        var index = 2
        while existingNames.contains("\(preferred) \(index)") {
            index += 1
        }
        return "\(preferred) \(index)"
    }

    private func deletePinboard(_ pinboard: Pinboard) {
        if appState.selectedTab == .pinboard(pinboard.id) {
            appState.panelController.selectTab(.history)
        }
        appState.orderedPinboardIDs.removeAll { $0 == pinboard.id }
        modelContext.delete(pinboard)
        try? modelContext.save()
    }
}

// MARK: - NavTabButton (extracted for @State hover)

private struct NavTabButton: View {
    let label: String
    let icon: String?
    let isActive: Bool
    let isDropTargeted: Bool
    /// Shown in place of the icon while ⌘ is held (#53).
    let shortcutNumber: Int?
    let colorScheme: ColorScheme
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        // A tap gesture rather than a Button: a Button keeps the mouse and a
        // pinboard tab could never start a drag to reorder it (#3).
        tabLabel
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
            .onHover { isHovered = $0 }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .animation(.easeInOut(duration: 0.15), value: isActive)
            .animation(.easeInOut(duration: 0.12), value: isDropTargeted)
            .animation(.easeOut(duration: 0.1), value: shortcutNumber)
    }

    private var tabLabel: some View {
            HStack(spacing: 5) {
                if let icon {
                    // The number sits over the hidden icon so the tabs keep
                    // their widths and don't shift while ⌘ is held.
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                        .opacity(shortcutNumber == nil ? 1 : 0)
                        .overlay {
                            if let shortcutNumber {
                                Text(verbatim: "\(shortcutNumber)")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .frame(width: 14, height: 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                            .strokeBorder(.foreground.opacity(0.55), lineWidth: 1)
                                    )
                                    .transition(.opacity)
                            }
                        }
                }

                Text(label)
                    .font(isActive ? DesignTokens.Nav.activeFont : DesignTokens.Nav.inactiveFont)
                    .lineLimit(1)
            }
            .foregroundStyle(
                isActive
                    ? DesignTokens.Nav.activeTextColor(for: colorScheme)
                    : DesignTokens.Nav.inactiveTextColor(for: colorScheme)
            )
            .padding(.horizontal, 10)
            .frame(height: DesignTokens.Nav.tabHeight)
            .background(
                isDropTargeted
                    ? Color.accentColor.opacity(colorScheme == .dark ? 0.24 : 0.16)
                    : isActive || isHovered
                    ? DesignTokens.Nav.activeBackground(for: colorScheme)
                    : Color.clear
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Nav.tabCornerRadius, style: .continuous)
                    .strokeBorder(
                        isDropTargeted ? Color.accentColor.opacity(0.7) : Color.clear,
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Nav.tabCornerRadius, style: .continuous))
    }
}

// MARK: - NavIconButton (icon-only button with hover)

private struct NavIconButton: View {
    let icon: String
    let iconSize: CGFloat
    let colorScheme: ColorScheme
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(DesignTokens.Nav.inactiveTextColor(for: colorScheme))
                .frame(width: 28, height: DesignTokens.Nav.tabHeight)
                .background(
                    isHovered
                        ? DesignTokens.Nav.activeBackground(for: colorScheme)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - OptionsMenuButton (NSMenu-based for proper centering)

private struct OptionsMenuButton: View {
    let colorScheme: ColorScheme
    let searchState: SearchState

    @State private var isHovered = false

    var body: some View {
        NavIconButton(
            icon: "ellipsis",
            iconSize: 14,
            colorScheme: colorScheme
        ) {
            showMenu()
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        // Filter by Type submenu
        let typeMenu = NSMenu()
        for type in ContentType.allCases {
            let item = NSMenuItem(title: type.displayName, action: nil, keyEquivalent: "")
            let isSelected = searchState.selectedContentTypes.contains(type)
            if isSelected {
                item.state = .on
            }
            item.target = MenuActionTarget.shared
            item.representedObject = MenuAction.toggleContentType(type, searchState)
            item.action = #selector(MenuActionTarget.performAction(_:))
            typeMenu.addItem(item)
        }
        if !searchState.selectedContentTypes.isEmpty {
            typeMenu.addItem(.separator())
            let clearItem = NSMenuItem(title: String(localized: "Clear Filters"), action: nil, keyEquivalent: "")
            clearItem.target = MenuActionTarget.shared
            clearItem.representedObject = MenuAction.clearContentTypes(searchState)
            clearItem.action = #selector(MenuActionTarget.performAction(_:))
            typeMenu.addItem(clearItem)
        }
        let typeMenuItem = NSMenuItem(title: String(localized: "Filter by Type"), action: nil, keyEquivalent: "")
        typeMenuItem.submenu = typeMenu
        menu.addItem(typeMenuItem)

        // Filter by Date submenu
        let dateMenu = NSMenu()
        for filter in SearchState.DateFilter.allCases {
            let item = NSMenuItem(title: filter.displayName, action: nil, keyEquivalent: "")
            if searchState.dateFilter == filter {
                item.state = .on
            }
            item.target = MenuActionTarget.shared
            item.representedObject = MenuAction.setDateFilter(filter, searchState)
            item.action = #selector(MenuActionTarget.performAction(_:))
            dateMenu.addItem(item)
        }
        let dateMenuItem = NSMenuItem(title: String(localized: "Filter by Date"), action: nil, keyEquivalent: "")
        dateMenuItem.submenu = dateMenu
        menu.addItem(dateMenuItem)

        // The same setting as Settings > General, surfaced where pasting
        // happens (#49), with the one-off Shift switch spelled out below it.
        menu.addItem(.separator())
        let plainTextItem = NSMenuItem(title: String(localized: "Always Paste as Plain Text"), action: nil, keyEquivalent: "")
        plainTextItem.state = UserDefaults.standard.bool(forKey: PasteService.alwaysPlainTextDefaultsKey) ? .on : .off
        plainTextItem.target = MenuActionTarget.shared
        plainTextItem.representedObject = MenuAction.toggleAlwaysPlainText
        plainTextItem.action = #selector(MenuActionTarget.performAction(_:))
        menu.addItem(plainTextItem)
        let shiftHint = NSMenuItem(title: String(localized: "Hold \u{21e7} while pasting to switch for a single paste."), action: nil, keyEquivalent: "")
        shiftHint.isEnabled = false
        menu.addItem(shiftHint)

        // A way to Settings that doesn't need the menu bar icon (#25).
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: String(localized: "Settings…"), action: nil, keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = MenuActionTarget.shared
        settingsItem.representedObject = MenuAction.openSettings(AppState.shared)
        settingsItem.action = #selector(MenuActionTarget.performAction(_:))
        menu.addItem(settingsItem)

        // Show menu at mouse location
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
}

// MARK: - NSMenu action helpers

private enum MenuAction {
    case toggleContentType(ContentType, SearchState)
    case clearContentTypes(SearchState)
    case setDateFilter(SearchState.DateFilter, SearchState)
    case toggleAlwaysPlainText
    case openSettings(AppState)
}

@MainActor
private final class MenuActionTarget: NSObject {
    static let shared = MenuActionTarget()

    @objc func performAction(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? MenuAction else { return }
        Task { @MainActor in
            switch action {
            case .toggleContentType(let type, let state):
                state.toggleContentType(type)
            case .clearContentTypes(let state):
                state.selectedContentTypes = []
            case .setDateFilter(let filter, let state):
                state.dateFilter = filter
            case .toggleAlwaysPlainText:
                let key = PasteService.alwaysPlainTextDefaultsKey
                UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: key), forKey: key)
            case .openSettings(let appState):
                appState.openSettings()
            }
        }
    }
}

// MARK: - Pinboard tab drops

extension UTType {
    /// A pinboard tab dragged within the panel to reorder it (#3).
    static let clipbaraPinboardTab = UTType(exportedAs: "com.minsang.PasteClip.pinboard-tab")
}

struct TabDropIndicator: Equatable {
    let pinboardID: UUID
    let edge: HorizontalEdge
}

/// A pinboard tab takes two kinds of drops: another pinboard tab, which moves
/// there, and clips, which are added (or moved from another pinboard).
private struct PinboardTabDropDelegate: DropDelegate {
    let pinboardID: UUID
    @Binding var draggingPinboardID: UUID?
    @Binding var targetedPinboardID: UUID?
    @Binding var indicator: TabDropIndicator?
    let landingEdge: (UUID) -> HorizontalEdge?
    let moveTab: (UUID) -> Void
    let dropClips: ([NSItemProvider]) -> Bool

    private static let clipTypes: [UTType] = [.pasteClipClipboardItemID, .text, .url, .fileURL, .image, .data, .item]

    private func isTabDrag(_ info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.clipbaraPinboardTab])
    }

    func validateDrop(info: DropInfo) -> Bool {
        return isTabDrag(info) || info.hasItemsConforming(to: Self.clipTypes)
    }

    func dropEntered(info: DropInfo) {
        if isTabDrag(info) {
            indicator = landingEdge(pinboardID).map { TabDropIndicator(pinboardID: pinboardID, edge: $0) }
        } else {
            targetedPinboardID = pinboardID
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: isTabDrag(info) ? .move : .copy)
    }

    func dropExited(info: DropInfo) {
        if targetedPinboardID == pinboardID { targetedPinboardID = nil }
        if indicator?.pinboardID == pinboardID { indicator = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        if isTabDrag(info) {
            indicator = nil
            moveTab(pinboardID)
            draggingPinboardID = nil
            return true
        }
        targetedPinboardID = nil
        return dropClips(info.itemProviders(for: Self.clipTypes))
    }
}

