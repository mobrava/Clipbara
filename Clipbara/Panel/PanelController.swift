import AppKit
import SwiftUI
import SwiftData

@MainActor
@Observable
final class PanelController {
    private var panel: ClipbaraPanel?
    /// The panel's SwiftUI content. Slid inside the fixed panel frame so the
    /// window itself never has to travel off screen to animate.
    private var contentHost: NSView?
    private var contentContainer: PanelContentContainer?
    /// Where the running resize animation is heading. `panel.frame` still
    /// reports the old size until the animation ends, so comparing against it
    /// let a quick tab switch back be skipped and the panel settle at the
    /// width of the tab the user had already left.
    private var resizeTargetFrame: NSRect?
    /// The screen the panel was opened on. `panel.screen` is unreliable while
    /// the panel sits flush against a screen edge next to another display.
    private var presentedScreen: NSScreen?
    private var quickLookPanel: ClipboardQuickLookPanel?
    private var quickLookItem: ClipboardItem?
    private var quickLookZoom: ImageZoomController?
    private(set) var isVisible: Bool = false
    private var clickMonitor: Any?
    private var mouseMonitor: Any?
    private var scrollMonitor: Any?
    private var wheelTranslator = WheelScrollTranslation.Translator()
    private var keyMonitor: Any?
    private var flagsMonitor: Any?
    private var tabHintTask: Task<Void, Never>?
    /// Where the pointer was when the keyboard last took over: the panel
    /// opening, a tab switch, an arrow key. A card under a pointer that
    /// hasn't moved since is not what the user is pointing at; it just
    /// happens to be there (or is a card from the previous tab).
    private var keyboardAnchor: NSPoint?
    var onPanelWillHide: (() -> Void)?
    weak var appState: AppState?

    /// Settings > Appearance > Animate Panel. Missing means on.
    nonisolated static let animatesPanelDefaultsKey = "animatePanel"

    /// Whether the panel slides and resizes with animation. The system Reduce
    /// Motion setting turns it off as well (#52).
    static var animatesPanel: Bool {
        let setting = UserDefaults.standard.object(forKey: animatesPanelDefaultsKey) as? Bool ?? true
        return setting && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private let baseHeight: CGFloat = 280
    private let minimumPanelWidth: CGFloat = 720
    private let maximumScreenWidthRatio: CGFloat = 0.90
    private let estimatedCardWidth: CGFloat = 228
    private let estimatedCardSpacing: CGFloat = 8
    private let contentHorizontalPadding: CGFloat = 32
    private let maximumVisibleCardCount = 6

    // MARK: - Screen Selection

    /// Returns the screen that contains `point`, if any.
    ///
    /// Kept static and dependency free so the multi display placement rules can
    /// be exercised without attaching real hardware.
    static func screen(containing point: NSPoint, in screens: [NSScreen]) -> NSScreen? {
        screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    /// The display the user is actually working on.
    ///
    /// `NSScreen.main` resolves to the screen owning the key window, not the
    /// screen the user is looking at. Clipbara is a menu bar app and is never
    /// the active app when the hotkey fires, so `NSScreen.main` can point at
    /// whichever display last held focus and the panel slides in on the wrong
    /// screen. The pointer location matches the user's intent, so prefer it and
    /// fall back to `NSScreen.main` only when the pointer is off screen.
    private var activeScreen: NSScreen {
        Self.screen(containing: NSEvent.mouseLocation, in: NSScreen.screens)
            ?? NSScreen.main
            ?? NSScreen.screens.first!
    }

    func toggle(modelContainer: ModelContainer, appState: AppState) {
        if isVisible {
            hidePanel()
        } else {
            showPanel(modelContainer: modelContainer, appState: appState)
        }
    }

    /// Builds the panel and renders its first frame off screen so the first
    /// hotkey press only has to animate. Called shortly after launch.
    func prewarm(modelContainer: ModelContainer, appState: AppState) {
        guard panel == nil else { return }
        self.appState = appState

        // Build the warm panel at its real on screen position. Parking it below
        // the screen would hand it to a display stacked underneath before the
        // first hotkey press ever happens. It stays invisible via `alphaValue`.
        let screenFrame = activeScreen.visibleFrame
        let frame = panelFrame(in: screenFrame, itemCount: 0, y: screenFrame.origin.y)

        let warm = ClipbaraPanel(contentRect: frame)
        warm.alphaValue = 0
        warm.contentView = makeContentView(modelContainer: modelContainer, appState: appState, size: frame.size)
        warm.orderFrontRegardless()
        warm.contentView?.layoutSubtreeIfNeeded()
        warm.displayIfNeeded()
        warm.orderOut(nil)
        warm.alphaValue = 1
        panel = warm
    }

    func showPanel(modelContainer: ModelContainer, appState: AppState) {
        #if APPSTORE
        ClipSync.shared.syncOnOpen()
        ClipSync.shared.startLivePolling()
        #endif
        guard !isVisible else { return }
        anchorKeyboard()
        self.appState = appState

        let screen = activeScreen
        let screenFrame = screen.visibleFrame
        let itemCount = visibleItemCount(modelContainer: modelContainer, selectedTab: appState.selectedTab)
        let endFrame = panelFrame(in: screenFrame, itemCount: itemCount, y: screenFrame.origin.y)
        presentedScreen = screen

        if panel == nil {
            panel = ClipbaraPanel(contentRect: endFrame)
            panel?.contentView = makeContentView(
                modelContainer: modelContainer,
                appState: appState,
                size: endFrame.size
            )
        } else {
            panel?.setFrame(endFrame, display: false)
        }
        resizeTargetFrame = nil
        refitContent()

        // The panel frame stays put; the content starts one panel height below
        // the window and rides up into it. Moving the window itself would push
        // it onto a display stacked underneath, which is how the panel used to
        // end up on the wrong screen.
        let animates = Self.animatesPanel
        contentHost?.frame.origin.y = animates ? -endFrame.height : 0
        panel?.alphaValue = 1

        // The window shadow is derived from the content alpha. While the
        // content is only partly inside the frame the shadow would outline
        // empty space, so drop it for the duration of the slide.
        panel?.hasShadow = !animates

        panel?.orderFrontRegardless()
        panel?.makeKey()
        panel?.makeFirstResponder(nil)

        // Ordering a window in is not instant: the window server needs a
        // composited frame before anything reaches the screen. Starting the
        // slide in this same turn meant the easeOut curve was already most of
        // the way through by the time the panel actually appeared, so the
        // content popped in instead of riding up. Push the parked first frame
        // out now, then start the slide on the next main actor turn so the
        // whole curve happens on screen. `hidePanel` never had this problem
        // because its window is already visible when it animates.
        panel?.contentView?.displayIfNeeded()
        CATransaction.flush()

        if animates {
            slideContentIn()
        }

        isVisible = true
        appState.markPanelPresented()
        installClickMonitor()
        installMouseMonitor()
        installScrollMonitor()
        installKeyMonitor()
    }

    private func slideContentIn() {
        Task { @MainActor [weak self] in
            guard let self, let contentHost = self.contentHost else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                // Only the origin moves. Animating the whole frame would also
                // carry a width captured before any resize that lands mid-slide.
                contentHost.animator().setFrameOrigin(.zero)
            }, completionHandler: {
                Task { @MainActor [weak self] in
                    self?.panel?.hasShadow = true
                    self?.panel?.invalidateShadow()
                }
            })
        }
    }

    func resizeToContentItemCount(_ itemCount: Int, animated: Bool = true) {
        guard isVisible, let panel else { return }

        let screen = presentedScreen ?? panel.screen ?? activeScreen
        let screenFrame = screen.visibleFrame
        let targetFrame = panelFrame(in: screenFrame, itemCount: itemCount, y: panel.frame.origin.y)

        let currentTarget = resizeTargetFrame ?? panel.frame
        guard abs(currentTarget.width - targetFrame.width) > 1 ||
              abs(currentTarget.origin.x - targetFrame.origin.x) > 1 else {
            return
        }

        if animated, Self.animatesPanel {
            resizeTargetFrame = targetFrame
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(targetFrame, display: true)
            }, completionHandler: { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    // A newer resize may have started; only clear our own target.
                    if self.resizeTargetFrame == targetFrame {
                        self.resizeTargetFrame = nil
                        self.refitContent()
                    }
                }
            })
        } else {
            resizeTargetFrame = nil
            panel.setFrame(targetFrame, display: true)
            refitContent()
        }
    }

    /// Sizes the content to the panel from the window's own frame, not from
    /// whatever size the container ended up with. A report on macOS 26.7 (#38)
    /// showed a correctly sized, centered panel whose content was narrower
    /// from the first time it opened; this covers the case where the
    /// container itself did not follow the window.
    private func refitContent() {
        guard let panel, let container = contentContainer else { return }
        let size = panel.contentRect(forFrameRect: panel.frame).size
        if container.frame.size != size {
            container.frame = NSRect(origin: .zero, size: size)
        }
        container.fitHostedViewWidth()
    }

    func restoreKeyboardNavigationFocus(activateApp: Bool = false) {
        guard isVisible, let panel else { return }
        if activateApp {
            NSApp.activate(ignoringOtherApps: true)
        }
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(nil)
    }

    /// - Parameter completion: Runs after the panel has left the screen.
    func hidePanel(then completion: (@MainActor @Sendable () -> Void)? = nil) {
        guard isVisible, let panel else { return }
        #if APPSTORE
        ClipSync.shared.stopLivePolling()
        #endif
        panel.makeFirstResponder(nil)
        onPanelWillHide?()
        hideQuickLook()

        let panelHeight = panel.frame.height

        removeClickMonitor()
        removeMouseMonitor()
        removeScrollMonitor()
        removeKeyMonitor()

        let finish: @MainActor () -> Void = { [weak self] in
            panel.orderOut(nil)
            panel.hasShadow = true
            self?.contentHost?.frame.origin.y = 0
            self?.presentedScreen = nil
            self?.isVisible = false
            completion?()
        }

        guard Self.animatesPanel else {
            finish()
            return
        }

        panel.hasShadow = false

        NSAnimationContext.runAnimationGroup({ [contentHost] context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            contentHost?.animator().setFrameOrigin(NSPoint(x: 0, y: -panelHeight))
        }, completionHandler: {
            Task { @MainActor in
                finish()
            }
        })
    }

    // MARK: - Click Monitor (dismiss on outside click)

    private func installClickMonitor() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .leftMouseUp]
        ) { [weak self] event in
            Task { @MainActor in
                guard let self, self.isVisible else { return }
                if event.type == .leftMouseUp, self.appState?.draggedClipboardItemID != nil {
                    self.appState?.finishClipboardDrag()
                    return
                }
                if let panel = self.panel,
                   !panel.frame.contains(NSEvent.mouseLocation) {
                    self.hidePanel()
                }
            }
        }
    }

    private func removeClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    // MARK: - Mouse Monitor (release search focus before card clicks)

    private func installMouseMonitor() {
        mouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .leftMouseUp]
        ) { [weak self] event in
            MainActor.assumeIsolated { [weak self] in
                guard let self else { return }
                if event.type == .leftMouseUp, self.appState?.draggedClipboardItemID != nil {
                    self.appState?.finishClipboardDrag()
                } else {
                    self.releaseTextFocusIfNeeded(for: event)
                }
            }
            return event
        }
    }

    private func removeMouseMonitor() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }

    // MARK: - Scroll Monitor (mouse wheel over the sideways card rows)

    private func installScrollMonitor() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            let handled: Bool = MainActor.assumeIsolated { [weak self] in
                self?.translateWheelToHorizontalScroll(event) ?? false
            }
            return handled ? nil : event
        }
    }

    private func removeScrollMonitor() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }

    /// Re-sends a mouse wheel as horizontal movement over a sideways card row.
    private func translateWheelToHorizontalScroll(_ event: NSEvent) -> Bool {
        guard isVisible,
              let window = event.window,
              window === panel || window === quickLookPanel,
              let scrollView = horizontalScrollView(under: event, in: window) else { return false }

        // Cmd/Option + wheel zooms a Quick Look image; leave it to the image view.
        if scrollView is ZoomingImageScrollView,
           !event.modifierFlags.intersection([.command, .option]).isEmpty {
            return false
        }

        let clip = scrollView.contentView.bounds.size
        let document = scrollView.documentView?.frame.size ?? .zero
        let input = WheelScrollTranslation.Input(
            deltaX: event.scrollingDeltaX,
            deltaY: event.scrollingDeltaY,
            phase: WheelScrollTranslation.phase(of: event),
            canScrollHorizontally: document.width - clip.width > 0.5,
            canScrollVertically: document.height - clip.height > 0.5
        )
        guard wheelTranslator.shouldTranslate(input) else { return false }

        guard let horizontalEvent = WheelScrollTranslation.horizontalCopy(of: event) else { return false }
        scrollView.scrollWheel(with: horizontalEvent)
        return true
    }

    private func horizontalScrollView(under event: NSEvent, in window: NSWindow) -> NSScrollView? {
        guard let contentView = window.contentView else { return nil }
        let point = contentView.convert(event.locationInWindow, from: nil)
        guard let hit = contentView.hitTest(point) else { return nil }

        var view: NSView? = hit
        while let current = view {
            if let scrollView = current as? NSScrollView {
                return scrollView
            }
            view = current.superview
        }
        return nil
    }

    private func releaseTextFocusIfNeeded(for event: NSEvent) {
        guard isVisible, let panel else { return }

        let screenPoint = NSEvent.mouseLocation
        guard panel.frame.contains(screenPoint) else { return }

        if isTextInputFocused(in: panel),
           !eventHitsTextInput(event, in: panel) {
            panel.makeFirstResponder(nil)
        }
    }

    private func isTextInputFocused(in panel: NSPanel) -> Bool {
        guard let firstResponder = panel.firstResponder else { return false }
        return firstResponder is NSTextView || firstResponder is NSTextField
    }

    private func eventHitsTextInput(_ event: NSEvent, in panel: NSPanel) -> Bool {
        guard let contentView = panel.contentView else { return false }
        let locationInContent = contentView.convert(event.locationInWindow, from: nil)
        guard let hitView = contentView.hitTest(locationInContent) else { return false }

        var view: NSView? = hitView
        while let current = view {
            if current is NSTextField || current is NSTextView {
                return true
            }
            view = current.superview
        }
        return false
    }

    /// Shared by mouse tabs and Cmd+number. Clear the old navigation cache
    /// synchronously so a fast Return cannot paste an item from the old tab
    /// while SwiftUI is still rendering the new one.
    func selectTab(_ tab: PanelTab) {
        guard let appState, isVisible, appState.selectedTab != tab else { return }
        // The cards leave without reporting that the pointer left them.
        appState.hoveredClipID = nil
        anchorKeyboard()
        if quickLookPanel != nil { hideQuickLook() }
        appState.selectForPreview(nil)
        appState.searchState.selectedIndex = nil
        appState.currentFilteredItems = []
        appState.selectedTab = tab
    }

    // MARK: - Key Monitor (tab shortcuts, arrow keys, space, esc, return)

    private func installKeyMonitor() {
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            let commandOnly = event.modifierFlags.intersection([.command, .option, .control, .shift]) == .command
            MainActor.assumeIsolated { [weak self] in
                self?.commandHeldChanged(commandOnly)
            }
            return event
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = event.keyCode
            let eventWindowNumber = event.windowNumber
            let handled: Bool = MainActor.assumeIsolated { [weak self] in
                guard let self, self.isVisible else { return false }
                // A ⌘ chord like ⌘Z or ⌘V is under way; don't flash the hints.
                self.tabHintTask?.cancel()

                // Pass through key events that target other windows (e.g. the rename
                // alert), so their text fields receive Return/Escape as expected.
                if eventWindowNumber != 0,
                   eventWindowNumber != self.panel?.windowNumber,
                   eventWindowNumber != self.quickLookPanel?.windowNumber {
                    return false
                }

                // Never navigate behind a create/rename/delete sheet or modal.
                guard self.panel?.attachedSheet == nil,
                      self.quickLookPanel?.attachedSheet == nil,
                      NSApp.modalWindow == nil else { return false }

                // While a clip is edited in the preview the keys belong to the
                // editor. Esc cancels (unless an input method is composing);
                // ⌘S reaches the view's Save button (#54).
                if self.appState?.editingClipID != nil, self.quickLookPanel != nil {
                    let composing = (self.quickLookPanel?.firstResponder as? NSTextView)?.hasMarkedText() ?? false
                    if keyCode == 53, !composing {
                        self.appState?.cancelEdit()
                        return true
                    }
                    return false
                }
                let isCommandOnly = event.modifierFlags.intersection([.command, .option, .control, .shift]) == .command

                // Handle tab shortcuts before the search-field pass-through.
                // Missing tabs are a no-op, not a shortcut for the frontmost app.
                if let index = PanelTabShortcut.index(keyCode: keyCode, modifiers: event.modifierFlags) {
                    if let appState = self.appState,
                       let tab = PanelTabShortcut.target(at: index, pinboardIDs: appState.orderedPinboardIDs) {
                        self.selectTab(tab)
                    }
                    return true
                }

                // ⌘, opens Settings, also from the search field (#25).
                if keyCode == 43,
                   event.modifierFlags.intersection([.command, .option, .control, .shift]) == .command {
                    self.appState?.openSettings()
                    return true
                }

                if self.quickLookPanel != nil {
                    if isCommandOnly, keyCode == 14, let item = self.quickLookItem, AppState.canEdit(item) { // ⌘E
                        self.appState?.editingClipID = item.id
                        return true
                    }
                    if let zoom = self.quickLookZoom,
                       let action = ImageZoomController.action(keyCode: keyCode, modifiers: event.modifierFlags) {
                        zoom.perform(action)
                        return true
                    }
                    return self.processKey(keyCode)
                }

                // Check if a text field is focused (search bar) - let it handle the event
                if let firstResponder = self.panel?.firstResponder,
                   firstResponder is NSTextView || firstResponder is NSTextField {
                    // Still handle Escape to close search/panel
                    if keyCode == 53 {
                        return self.processKey(keyCode)
                    }
                    // Results sit in a sideways row, so while typing a search
                    // ←/→ move between them and Return pastes the selected one.
                    // Left to the field: modified keys (text selection), an
                    // input method still composing (Korean), and read-only
                    // text such as a preview's selectable text.
                    let textView = firstResponder as? NSTextView
                    let isEditing = textView?.isEditable ?? true
                    let isComposing = textView?.hasMarkedText() ?? false
                    let isPlain = event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty
                    if isEditing, !isComposing, isPlain, keyCode == 123 || keyCode == 124 || keyCode == 36 {
                        return self.processKey(keyCode)
                    }
                    return false
                }

                let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
                if modifiers == .command, keyCode == 6 { // ⌘Z
                    return self.appState?.undoDeletion() ?? false
                }
                if modifiers.isEmpty, keyCode == 51 || keyCode == 117 { // Delete, Forward Delete
                    return self.deleteSelectedClip()
                }
                if modifiers == .command, keyCode == 14 { // ⌘E
                    return self.editTargetClip()
                }

                if self.startSearch(with: event) {
                    return true
                }

                return self.processKey(keyCode)
            }
            return handled ? nil : event
        }
    }

    /// Keys that keep their panel meaning instead of starting a search: Return, Tab,
    /// Space, Delete, Escape, Forward Delete, the arrows, and keypad Enter.
    private static let navigationKeyCodes: Set<UInt16> = [36, 48, 49, 51, 53, 117, 123, 124, 125, 126, 76]

    /// Typing a character with the panel open moves to the search field and types it
    /// there, so a search needs no click or Tab first (#74).
    private func startSearch(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty,
              !Self.navigationKeyCodes.contains(event.keyCode),
              event.keyCode != QuickLookKeySetting.keyCode,
              let characters = event.characters, !characters.isEmpty,
              characters.unicodeScalars.allSatisfy({ scalar in
                  // Function keys arrive as private-use characters.
                  !CharacterSet.controlCharacters.contains(scalar) && !(0xF700...0xF8FF).contains(scalar.value)
              }),
              let panel, let field = Self.searchField(in: panel.contentView),
              panel.makeFirstResponder(field) else { return false }
        // Deliver the key again on the next pass, once the field has focus, so it
        // takes the same path as typing into the field (input method included).
        NSApp.postEvent(event, atStart: true)
        return true
    }

    private static func searchField(in view: NSView?) -> NSTextField? {
        guard let view else { return nil }
        if let field = view as? NSTextField, field.isEditable, !field.isHidden {
            return field
        }
        for subview in view.subviews {
            if let field = searchField(in: subview) { return field }
        }
        return nil
    }

    private func anchorKeyboard() {
        keyboardAnchor = NSEvent.mouseLocation
    }

    /// The card under the pointer, if the pointer has moved since the
    /// keyboard last took over (#26).
    private func pointedCardIndex(in items: [ClipboardItem]) -> Int? {
        guard let appState, let hovered = appState.hoveredClipID,
              NSEvent.mouseLocation != keyboardAnchor else { return nil }
        return items.firstIndex { $0.id == hovered }
    }

    /// Opens the preview with the clip's text in an editor (#54).
    func beginEditing(_ item: ClipboardItem) {
        guard let appState, AppState.canEdit(item) else { return }
        if let idx = appState.currentFilteredItems.firstIndex(where: { $0.id == item.id }) {
            appState.searchState.selectedIndex = idx
        }
        showQuickLook(item: item)
        appState.editingClipID = item.id
    }

    /// ⌘E edits the card under the pointer, like Space previews it, or
    /// else the selected card.
    private func editTargetClip() -> Bool {
        guard let appState, appState.previewItem == nil else { return false }
        let items = appState.currentFilteredItems
        guard let idx = pointedCardIndex(in: items) ?? appState.searchState.selectedIndex,
              idx < items.count else { return false }
        guard AppState.canEdit(items[idx]) else {
            // Say why nothing opened instead of ignoring the key.
            appState.showToast(String(localized: "Only plain text clips can be edited."), systemImage: "pencil.slash")
            return true
        }
        beginEditing(items[idx])
        return true
    }

    /// Deletes the selected card from history, or on a pinboard tab removes
    /// it from that pinboard only. ⌘Z restores it (#45).
    private func deleteSelectedClip() -> Bool {
        guard let appState, appState.previewItem == nil,
              let idx = appState.searchState.selectedIndex,
              idx < appState.currentFilteredItems.count else { return false }
        let item = appState.currentFilteredItems[idx]
        switch appState.selectedTab {
        case .history:
            appState.deleteClip(item)
        case .pinboard(let pinboardID):
            let itemID = item.id
            guard let entry = item.modelContext.flatMap({ context in
                try? context.fetch(FetchDescriptor<PinboardEntry>(
                    predicate: #Predicate { $0.clipboardItem?.id == itemID && $0.pinboard?.id == pinboardID }
                )).first
            }) else { return false }
            appState.removeFromPinboard(entry)
        }
        return true
    }

    private func processKey(_ keyCode: UInt16) -> Bool {
        guard let appState, isVisible else { return false }
        let items = appState.currentFilteredItems
        let maxIndex = items.count - 1

        // Quick Look toggle (user-configurable key, default Space)
        if keyCode == QuickLookKeySetting.keyCode {
            if quickLookPanel != nil {
                hideQuickLook()
                return true
            }
            if appState.previewItem != nil {
                withAnimation(.easeOut(duration: 0.2)) {
                    appState.selectForPreview(nil)
                }
                return true
            }
            // The card under the pointer wins over the keyboard selection,
            // and becomes the selection so arrows continue from it (#26).
            if let idx = pointedCardIndex(in: items) {
                appState.searchState.selectedIndex = idx
                showQuickLook(item: items[idx])
                return true
            }
            if let idx = appState.searchState.selectedIndex, idx < items.count {
                let item = items[idx]
                showQuickLook(item: item)
                return true
            }
            return false
        }

        switch keyCode {
        case 53: // Escape
            if quickLookPanel != nil {
                hideQuickLook()
                return true
            }
            if appState.previewItem != nil {
                appState.searchState.selectedIndex = nil
                appState.selectForPreview(nil)
                return true
            }
            if appState.searchState.isActive {
                appState.searchState.reset()
                return true
            }
            if appState.selectedTab != .history {
                selectTab(.history)
                return true
            }
            appState.hidePanel()
            return true

        case 123: // Left arrow
            anchorKeyboard()
            appState.searchState.moveSelection(by: -1, maxIndex: maxIndex)
            if let idx = appState.searchState.selectedIndex, idx < items.count {
                if quickLookPanel != nil {
                    updateQuickLook(for: items[idx])
                } else if appState.previewItem != nil {
                    appState.previewItem = items[idx]
                }
            }
            return true

        case 124: // Right arrow
            anchorKeyboard()
            appState.searchState.moveSelection(by: 1, maxIndex: maxIndex)
            if let idx = appState.searchState.selectedIndex, idx < items.count {
                if quickLookPanel != nil {
                    updateQuickLook(for: items[idx])
                } else if appState.previewItem != nil {
                    appState.previewItem = items[idx]
                }
            }
            return true

        case 36: // Return - paste
            if let item = quickLookItem {
                appState.paste(item)
                return true
            }

            guard let idx = appState.searchState.selectedIndex,
                  idx < items.count else { return false }
            appState.paste(items[idx])
            return true

        default:
            return false
        }
    }

    // MARK: - Clipboard Quick Look

    private func showQuickLook(item: ClipboardItem) {
        guard let appState else { return }

        appState.selectForPreview(nil)
        quickLookItem = item

        let screen = self.panel?.screen ?? activeScreen
        let screenFrame = screen.visibleFrame

        let panel: ClipboardQuickLookPanel
        if let existing = quickLookPanel {
            panel = existing
            panel.setFrame(screenFrame, display: false)
        } else {
            panel = ClipboardQuickLookPanel(contentRect: screenFrame)
            quickLookPanel = panel
        }

        let zoom = ImageZoomController()
        quickLookZoom = zoom

        panel.contentView = NSHostingView(
            rootView: ClipboardQuickLookView(
                item: item,
                shelfHeight: baseHeight,
                zoom: zoom,
                onClose: { [weak self] in
                    self?.hideQuickLook()
                },
                onPaste: { [weak appState] in
                    appState?.paste(item)
                }
            )
            .environment(appState)
        )

        panel.orderFrontRegardless()
        panel.makeKey()
    }

    private func updateQuickLook(for item: ClipboardItem) {
        guard quickLookPanel != nil else { return }
        showQuickLook(item: item)
    }

    private func hideQuickLook() {
        appState?.editingClipID = nil
        quickLookPanel?.orderOut(nil)
        quickLookPanel = nil
        quickLookItem = nil
        quickLookZoom = nil
        panel?.makeKey()
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
        commandHeldChanged(false)
    }

    /// Shows the tab numbers once ⌘ has been held on its own for a moment,
    /// so quick chords (⌘Z, ⌘V, ⌘1) don't flash them (#53).
    private func commandHeldChanged(_ held: Bool) {
        tabHintTask?.cancel()
        tabHintTask = nil
        guard held, isVisible else {
            appState?.showsTabShortcutHints = false
            return
        }
        tabHintTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled, let self, self.isVisible else { return }
            self.appState?.showsTabShortcutHints = true
        }
    }

    private func visibleItemCount(modelContainer: ModelContainer, selectedTab: PanelTab) -> Int {
        let context = modelContainer.mainContext

        switch selectedTab {
        case .history:
            let descriptor = FetchDescriptor<ClipboardItem>()
            return (try? context.fetchCount(descriptor)) ?? 0

        case .pinboard(let pinboardId):
            var descriptor = FetchDescriptor<Pinboard>(
                predicate: #Predicate { pinboard in
                    pinboard.id == pinboardId
                }
            )
            descriptor.fetchLimit = 1
            guard let pinboard = try? context.fetch(descriptor).first else { return 0 }
            return pinboard.entries.filter { !$0.isDeleted && $0.clipboardItem != nil }.count
        }
    }

    /// Wraps the SwiftUI content in a plain container so it can be offset
    /// inside the panel. Anything pushed outside the panel frame is clipped by
    /// the window surface, which is what makes the slide read as a reveal.
    private func makeContentView(
        modelContainer: ModelContainer,
        appState: AppState,
        size: NSSize
    ) -> NSView {
        let host = NSHostingView(
            rootView: HistoryPanelView()
                .environment(appState)
                .modelContainer(modelContainer)
        )
        host.frame = NSRect(origin: .zero, size: size)

        let container = PanelContentContainer(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.masksToBounds = true
        container.addSubview(host)
        container.hostedView = host

        contentHost = host
        contentContainer = container
        return container
    }

    private func panelFrame(in screenFrame: NSRect, itemCount: Int, y: CGFloat) -> NSRect {
        let panelWidth = targetPanelWidth(for: itemCount, screenWidth: screenFrame.width)
        let panelX = screenFrame.midX - panelWidth / 2

        return NSRect(
            x: panelX,
            y: y,
            width: panelWidth,
            height: baseHeight
        )
    }

    private func targetPanelWidth(for itemCount: Int, screenWidth: CGFloat) -> CGFloat {
        let screenMaxWidth = max(360, screenWidth - 48)
        let maxWidth = min(screenMaxWidth, max(minimumPanelWidth, screenWidth * maximumScreenWidthRatio))
        let minWidth = min(minimumPanelWidth, maxWidth)
        let visibleCardCount = min(max(itemCount, 1), maximumVisibleCardCount)
        let cardContentWidth =
            CGFloat(visibleCardCount) * estimatedCardWidth +
            CGFloat(max(visibleCardCount - 1, 0)) * estimatedCardSpacing +
            contentHorizontalPadding

        return min(max(minWidth, cardContentWidth), maxWidth)
    }
}

