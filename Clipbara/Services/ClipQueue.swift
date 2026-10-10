import AppKit

/// Clip Queue: while it is on, every copy joins the queue, and each ⌘V the
/// user presses pastes the next one in order (#9).
///
/// The item due next is always what sits on the clipboard, put there with its
/// data promised rather than written. When another app pastes, it asks for the
/// data, and that request is the signal to line up the following item. This
/// needs no permission, unlike watching the keyboard for ⌘V (App Review
/// rejected that under guideline 2.4.5).
@MainActor
@Observable
final class ClipQueue {
    private(set) var isActive = false
    private(set) var list = ClipQueueList<ClipboardItem>()

    var pastesNewestFirst: Bool {
        get { list.pastesNewestFirst }
        set {
            list.pastesNewestFirst = newValue
            lineUpNext()
        }
    }

    @ObservationIgnored private weak var appState: AppState?
    @ObservationIgnored private let board = ClipQueuePasteboard()
    @ObservationIgnored private var activationObserver: NSObjectProtocol?
    /// What the clipboard promises right now, kept so stopping can write it for real.
    @ObservationIgnored private var placed: ClipboardItem?
    @ObservationIgnored private let window = ClipQueueWindowController()

    func attach(to appState: AppState) {
        self.appState = appState
        board.onPaste = { [weak self] in self?.userDidPaste() }
        board.onReplace = { [weak self] in self?.lineUpNext() }
    }

    func toggle() {
        if isActive { stop() } else { start() }
    }

    func start() {
        guard !isActive else { return }
        isActive = true
        list.removeAll()
        observeActivations()
        window.show(queue: self)
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        if let placed, board.ownsClipboard {
            // Leave real data behind, not a promise nobody will keep.
            write(placed)
        }
        board.reset()
        placed = nil
        list.removeAll()
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        activationObserver = nil
        window.hide()
    }

    /// A copy Clipbara just recorded.
    func capture(_ item: ClipboardItem) {
        guard isActive else { return }
        // A snapshot, so pruning or deleting history can't pull the model out
        // from under the list.
        list.append(item.detachedCopy())
        // Even when the new copy is next, it has to go back on as a promise,
        // or its paste would go unnoticed.
        lineUpNext()
    }

    func remove(id: UUID) {
        let wasNext = list.next?.id == id
        list.remove(id: id)
        if wasNext { lineUpNext() }
    }

    // MARK: - Clipboard

    private var asPlainText: Bool {
        UserDefaults.standard.bool(forKey: PasteService.alwaysPlainTextDefaultsKey)
    }

    private func lineUpNext() {
        guard isActive, let next = list.next, let appState else { return }
        appState.clipboardMonitor.skipNextChange()
        board.place(appState.pasteService.contents(for: next.item, asPlainText: asPlainText))
        placed = next.item
    }

    private func write(_ item: ClipboardItem) {
        guard let appState else { return }
        appState.clipboardMonitor.skipNextChange()
        appState.pasteService.write(item: item, asPlainText: asPlainText)
    }

    private func userDidPaste() {
        guard isActive, list.consumeNext() != nil else { return }
        lineUpNext()
    }

    private func observeActivations() {
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.board.noteActivation()
            }
        }
    }
}

extension ClipboardItem {
    /// An unmanaged copy with the same content, safe to keep after the
    /// original is deleted from history.
    func detachedCopy() -> ClipboardItem {
        let copy = ClipboardItem(
            contentType: contentType,
            rawData: rawData,
            textContent: textContent,
            thumbnailData: thumbnailData,
            sourceAppName: sourceAppName,
            sourceAppBundleId: sourceAppBundleId,
            contentHash: contentHash
        )
        copy.userTitle = userTitle
        copy.copiedAt = copiedAt
        return copy
    }
}
