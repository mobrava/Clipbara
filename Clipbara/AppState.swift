import SwiftUI
import SwiftData
import KeyboardShortcuts

struct PanelToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let systemImage: String
}

@MainActor
@Observable
final class AppState {
    /// The one app-wide instance. Owned here rather than by SwiftUI state so it can
    /// never be recreated behind the hotkey and clipboard timer that point at it.
    static let shared = AppState()

    let clipboardMonitor = ClipboardMonitor()
    let pasteService = PasteService()
    let panelController = PanelController()
    let searchState = SearchState()
    let clipQueue = ClipQueue()
    let clipUndo = ClipUndoStack()

    var selectedTab: PanelTab = .history
    /// Published by NavigationBarView so shortcuts follow its exact display order.
    var orderedPinboardIDs: [UUID] = []
    var previewItem: ClipboardItem?
    var panelToast: PanelToast?
    var panelPresentationID = 0
    var draggedClipboardItemID: UUID?
    /// Set while a card is dragged out of a pinboard, so dropping it on
    /// another pinboard's tab moves it there instead of copying it.
    struct DraggedPinboardEntry {
        let entryID: UUID
        let clipID: UUID
        let pinboardID: UUID
    }
    @ObservationIgnored var draggedPinboardEntry: DraggedPinboardEntry?
    /// The clip whose text is being edited in the preview (#54).
    var editingClipID: UUID?
    /// The card under the pointer. Space previews it instead of the selected
    /// card (#26).
    var hoveredClipID: UUID?
    /// True while ⌘ alone is held with the panel open: tabs show the number
    /// that ⌘-number jumps to (#53).
    var showsTabShortcutHints = false
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    private(set) var modelContainer: ModelContainer?

    /// Cached filtered items for keyboard navigation (updated by CardGridView)
    var currentFilteredItems: [ClipboardItem] = []

    @ObservationIgnored private var hasStarted = false
    /// Settings > General > Show Icon in Menu Bar. Missing means on (#25).
    nonisolated static let showsMenuBarIconDefaultsKey = "showMenuBarIcon"
    /// SwiftUI's `openSettings`, captured from the panel's content (built at
    /// launch) so AppKit paths can open Settings without the menu bar item:
    /// reopening the app and the panel's Settings item.
    @ObservationIgnored var openSettingsAction: (@MainActor () -> Void)?

    func start(modelContext: ModelContext, modelContainer: ModelContainer) {
        // App.init may run more than once; start the monitor and hotkeys only once.
        guard !hasStarted else { return }
        hasStarted = true
        self.modelContainer = modelContainer
        clipQueue.attach(to: self)
        URLCommandHandler.shared.install(appState: self)
        clipboardMonitor.onCapture = { [weak self] item in
            self?.clipQueue.capture(item)
        }
        clipboardMonitor.start(modelContext: modelContext)
        ReviewPrompter.noteLaunch()
        #if APPSTORE
        Entitlements.shared.start()
        #endif
        panelController.onPanelWillHide = { [weak self] in
            self?.searchState.reset()
            self?.previewItem = nil
            ReviewPrompter.panelWillHide { [weak self] in
                self?.panelController.isVisible ?? false
            }
        }
        setupHotkey()

        // Render the panel once off screen so the first hotkey press is instant.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, let container = self.modelContainer else { return }
            self.panelController.prewarm(modelContainer: container, appState: self)
        }
    }

    func togglePanel() {
        guard let container = modelContainer else { return }
        #if APPSTORE
        // Without an active trial or unlock, offer it instead of the history.
        // Clipboard capture keeps running, so nothing is lost in the meantime.
        if !panelController.isVisible, !Entitlements.shared.checkHistoryAccess() {
            PaywallWindowController.shared.show()
            return
        }
        #endif
        panelController.toggle(modelContainer: container, appState: self)
    }

    func toggleClipQueue() {
        #if APPSTORE
        if !clipQueue.isActive, !Entitlements.shared.checkHistoryAccess() {
            PaywallWindowController.shared.show()
            return
        }
        #endif
        clipQueue.toggle()
    }

    func markPanelPresented() {
        panelPresentationID += 1
    }

    func selectForPreview(_ item: ClipboardItem?) {
        previewItem = item
    }

    func showToast(_ message: String, systemImage: String = "checkmark.circle.fill") {
        toastTask?.cancel()
        panelToast = PanelToast(message: message, systemImage: systemImage)
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1400))
            guard !Task.isCancelled else { return }
            panelToast = nil
        }
    }

    /// Shared paste path for panel and pinboard cards.
    /// - Parameter asPlainText: `nil` resolves from the setting combined with the Shift modifier.
    func paste(_ item: ClipboardItem, asPlainText: Bool? = nil) {
        // Picking a clip replaces the item the queue lined up, and the next
        // ⌘V would then drop the wrong one from the queue. End it instead.
        clipQueue.stop()
        clipboardMonitor.skipNextChange()
        pasteService.paste(item: item, asPlainText: asPlainText)
        // ⌘V has to reach the app behind the panel, so send it once the
        // panel is off screen and no longer the key window.
        if DirectPaste.isReady {
            hidePanel(then: { _ = DirectPaste.sendPasteShortcut() })
        } else {
            hidePanel()
        }
    }

    // MARK: - Deleting with undo (#45)

    func deleteClip(_ item: ClipboardItem) {
        guard let context = modelContainer?.mainContext else { return }
        if hoveredClipID == item.id { hoveredClipID = nil }
        clipUndo.deleteClip(item, in: context)
        showToast(String(localized: "Deleted. Press \u{2318}Z to undo."), systemImage: "trash")
    }

    func removeFromPinboard(_ entry: PinboardEntry) {
        guard let context = modelContainer?.mainContext else { return }
        clipUndo.removeEntry(entry, in: context)
        showToast(String(localized: "Removed from pinboard. Press \u{2318}Z to undo."), systemImage: "pin.slash")
    }

    // MARK: - Editing (#54)

    /// Only plain text for now: editing rich text or HTML as text would drop
    /// its formatting.
    nonisolated static func canEdit(_ item: ClipboardItem) -> Bool {
        item.contentType == .plainText
    }

    func editClip(_ item: ClipboardItem) {
        panelController.beginEditing(item)
    }

    func saveEdit(_ item: ClipboardItem, text: String) {
        editingClipID = nil
        guard let context = modelContainer?.mainContext, text != item.textContent else { return }
        clipUndo.editText(of: item, to: text, in: context)
        showToast(String(localized: "Saved. Press \u{2318}Z to undo."), systemImage: "pencil")
    }

    func cancelEdit() {
        editingClipID = nil
    }

    func moveToPinboard(_ entry: PinboardEntry, destination: Pinboard) {
        guard let context = modelContainer?.mainContext else { return }
        clipUndo.moveEntry(entry, to: destination, in: context)
        showToast(String(localized: "Moved to \(destination.name). Press \u{2318}Z to undo."), systemImage: "arrow.right.circle")
    }

    /// Handles a clip dropped on a pinboard tab. Returns false when the drag
    /// did not come from a pinboard, so the caller adds the clip instead.
    func dropDraggedPinboardEntry(clipID: UUID, on pinboardID: UUID) -> Bool {
        guard let drag = draggedPinboardEntry, drag.clipID == clipID else { return false }
        draggedPinboardEntry = nil
        guard drag.pinboardID != pinboardID, let context = modelContainer?.mainContext else { return true }
        let entryID = drag.entryID
        var entries = FetchDescriptor<PinboardEntry>(predicate: #Predicate { $0.id == entryID })
        entries.fetchLimit = 1
        var boards = FetchDescriptor<Pinboard>(predicate: #Predicate { $0.id == pinboardID })
        boards.fetchLimit = 1
        if let entry = try? context.fetch(entries).first, let board = try? context.fetch(boards).first {
            moveToPinboard(entry, destination: board)
        }
        return true
    }

    /// Returns false when there was nothing to restore.
    @discardableResult
    func undoDeletion() -> Bool {
        guard let context = modelContainer?.mainContext, clipUndo.undo(in: context) else { return false }
        showToast(String(localized: "Restored"), systemImage: "arrow.uturn.backward")
        return true
    }

    func hidePanel(then completion: (@MainActor @Sendable () -> Void)? = nil) {
        previewItem = nil
        hoveredClipID = nil
        draggedPinboardEntry = nil
        editingClipID = nil
        panelToast = nil
        toastTask?.cancel()
        draggedClipboardItemID = nil
        searchState.reset()
        selectedTab = .history
        panelController.hidePanel(then: completion)
    }

    /// Opens Settings in front, closing the panel first if it is open.
    func openSettings() {
        let open: @MainActor @Sendable () -> Void = { [weak self] in
            self?.openSettingsAction?()
            SettingsWindowFront.bring()
        }
        if panelController.isVisible {
            hidePanel(then: open)
        } else {
            open()
        }
    }

    func finishClipboardDrag() {
        draggedClipboardItemID = nil
        searchState.ensureSelection(itemCount: currentFilteredItems.count)
        panelController.restoreKeyboardNavigationFocus(activateApp: true)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            panelController.restoreKeyboardNavigationFocus(activateApp: true)
        }
    }

    var clearHistoryRequested = false

    private func setupHotkey() {
        KeyboardShortcuts.onKeyDown(for: .toggleHistoryPanel) { [weak self] in
            Task { @MainActor in
                self?.togglePanel()
            }
        }
        KeyboardShortcuts.onKeyDown(for: .toggleClipQueue) { [weak self] in
            Task { @MainActor in
                self?.toggleClipQueue()
            }
        }
        KeyboardShortcuts.onKeyDown(for: .clearHistory) { [weak self] in
            Task { @MainActor in
                guard self?.panelController.isVisible == true else { return }
                self?.clearHistoryRequested = true
            }
        }
    }
}
