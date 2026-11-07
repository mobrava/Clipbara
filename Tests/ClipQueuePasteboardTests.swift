import AppKit
import XCTest

/// Uses a private named pasteboard, never the general one.
@MainActor
final class ClipQueuePasteboardTests: XCTestCase {
    private var pasteboard: NSPasteboard!
    private var board: ClipQueuePasteboard!
    private var pastes = 0
    private var replaces = 0
    private var keyboard = ClipQueuePasteboard.Keyboard(lastKeyDown: .distantPast, commandHeld: false)

    override func setUp() async throws {
        pasteboard = NSPasteboard(name: .init("com.minsang.ClipbaraTests.queue.\(UUID().uuidString)"))
        board = ClipQueuePasteboard(pasteboard: pasteboard)
        pastes = 0
        replaces = 0
        keyboard = .init(lastKeyDown: .distantPast, commandHeld: false)
        board.onPaste = { [unowned self] in pastes += 1 }
        board.onReplace = { [unowned self] in replaces += 1 }
        board.keyboard = { [unowned self] in keyboard }
    }

    override func tearDown() async throws {
        pasteboard.releaseGlobally()
    }

    private func place(_ text: String) {
        board.place([(.string, Data(text.utf8)), (.rtf, Data("{\\rtf1 \(text)}".utf8))])
    }

    /// ⌘V pressed after the item was placed.
    private func pressPaste() {
        keyboard = .init(lastKeyDown: Date().addingTimeInterval(0.001), commandHeld: true)
    }

    private func settle() async throws {
        try await Task.sleep(for: ClipQueuePasteboard.settleDelay + .milliseconds(150))
    }

    func testMarksTheItemSoClipboardHistoryLeavesItAlone() {
        place("a")
        let types = pasteboard.types ?? []
        for marker in ClipQueuePasteboard.markerTypes {
            XCTAssertTrue(types.contains(marker), "missing \(marker.rawValue)")
        }
        XCTAssertTrue(board.ownsClipboard)
    }

    func testDoesNotCountAnythingUntilTheDataIsRead() async throws {
        place("a")
        _ = pasteboard.types
        try await settle()
        XCTAssertEqual(pastes, 0)
    }

    func testReadingTheDataCountsAsOnePaste() async throws {
        place("a")
        pressPaste()
        XCTAssertEqual(pasteboard.string(forType: .string), "a")
        // The same paste asking for a second type is still one paste.
        XCTAssertNotNil(pasteboard.data(forType: .rtf))
        try await settle()
        XCTAssertEqual(pastes, 1)
        XCTAssertEqual(replaces, 0)
    }

    func testEachPlacementCountsOnce() async throws {
        place("a")
        pressPaste()
        _ = pasteboard.string(forType: .string)
        try await settle()
        place("b")
        pressPaste()
        XCTAssertEqual(pasteboard.string(forType: .string), "b")
        try await settle()
        XCTAssertEqual(pastes, 2)
    }

    func testAReadRightAfterAnAppActivatesPutsTheItemBackInstead() async throws {
        place("a")
        // Even with a key just pressed, such as the Tab of ⌘Tab.
        pressPaste()
        board.noteActivation()
        _ = pasteboard.string(forType: .string)
        try await settle()
        XCTAssertEqual(pastes, 0)
        XCTAssertEqual(replaces, 1)
    }

    func testReplacingBeforeTheDelayCancelsThePendingPaste() async throws {
        place("a")
        pressPaste()
        _ = pasteboard.string(forType: .string)
        place("b")
        try await settle()
        XCTAssertEqual(pastes, 0)
    }

    func testResetStopsCounting() async throws {
        place("a")
        board.reset()
        _ = pasteboard.data(forType: .string)
        try await settle()
        XCTAssertEqual(pastes, 0)
        XCTAssertFalse(board.ownsClipboard)
    }

    // MARK: - Reads that aren't pastes (#78)

    func testAReadWithoutAKeyPutsTheItemBackInstead() async throws {
        place("a")
        XCTAssertEqual(pasteboard.string(forType: .string), "a")
        try await settle()
        XCTAssertEqual(pastes, 0)
        XCTAssertEqual(replaces, 1)
    }

    func testTheCopyThatQueuedTheItemIsNotItsPaste() async throws {
        // ⌘C, then the item goes on the clipboard, then another app reads it.
        keyboard = .init(lastKeyDown: Date(), commandHeld: true)
        try await Task.sleep(for: .milliseconds(5))
        place("a")
        _ = pasteboard.string(forType: .string)
        try await settle()
        XCTAssertEqual(pastes, 0)
        XCTAssertEqual(replaces, 1)
    }

    func testOnlyAPasteShortcutRightAfterThePlacementCounts() {
        let placed = Date(timeIntervalSince1970: 1_000)
        func read(keyAt: TimeInterval, command: Bool, at: TimeInterval) -> Bool {
            ClipQueuePasteboard.isPaste(
                keyboard: .init(lastKeyDown: placed + keyAt, commandHeld: command),
                placedAt: placed,
                now: placed + at
            )
        }
        XCTAssertTrue(read(keyAt: 2, command: true, at: 2.02), "⌘V")
        XCTAssertTrue(read(keyAt: 2, command: false, at: 2.03), "⌘V sent by another app, Command already up")
        XCTAssertFalse(read(keyAt: -0.1, command: true, at: 0.05), "the ⌘C that copied it")
        XCTAssertFalse(read(keyAt: 2, command: false, at: 2.3), "typing")
        XCTAssertFalse(read(keyAt: 2, command: true, at: 3.5), "long after the key")
        XCTAssertFalse(read(keyAt: -50, command: false, at: 5), "no key at all")
    }

    func testTheItemGoesBackSoonAfterAReadThatWasNotAPaste() async throws {
        place("a")
        _ = pasteboard.string(forType: .string)
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(replaces, 1)
    }

    func testReadsRightAfterPuttingTheItemBackWaitLonger() async throws {
        XCTAssertEqual(ClipQueuePasteboard.replaceDelay(streak: 0), .milliseconds(100))
        XCTAssertEqual(ClipQueuePasteboard.replaceDelay(streak: 2), .milliseconds(400))
        XCTAssertEqual(ClipQueuePasteboard.replaceDelay(streak: 9), .seconds(2))

        // An app that reads every change: 0.1 + 0.2 + 0.4 s to the third time
        // back, not 0.3 s.
        board.onReplace = { [unowned self] in
            replaces += 1
            place("a")
            if replaces < 3 { _ = pasteboard.string(forType: .string) }
        }
        place("a")
        _ = pasteboard.string(forType: .string)
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertEqual(replaces, 2)
        try await Task.sleep(for: .milliseconds(550))
        XCTAssertEqual(replaces, 3)
    }

    func testACopyOfTheItemPutBackStillCountsAsTheQueueItem() {
        place("a")
        let copy = NSPasteboardItem()
        copy.setString("a", forType: .string)
        for type in ClipQueuePasteboard.markerTypes { copy.setData(Data(), forType: type) }
        pasteboard.clearContents()
        pasteboard.writeObjects([copy])
        XCTAssertFalse(board.ownsClipboard)
        XCTAssertTrue(board.holdsQueueItem)

        pasteboard.clearContents()
        pasteboard.setString("copied", forType: .string)
        XCTAssertFalse(board.holdsQueueItem)
    }
}
