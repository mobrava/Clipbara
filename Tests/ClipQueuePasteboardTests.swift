import AppKit
import XCTest

/// Uses a private named pasteboard, never the general one.
@MainActor
final class ClipQueuePasteboardTests: XCTestCase {
    private var pasteboard: NSPasteboard!
    private var board: ClipQueuePasteboard!
    private var pastes = 0
    private var replaces = 0

    override func setUp() async throws {
        pasteboard = NSPasteboard(name: .init("com.minsang.ClipbaraTests.queue.\(UUID().uuidString)"))
        board = ClipQueuePasteboard(pasteboard: pasteboard)
        pastes = 0
        replaces = 0
        board.onPaste = { [unowned self] in pastes += 1 }
        board.onReplace = { [unowned self] in replaces += 1 }
    }

    override func tearDown() async throws {
        pasteboard.releaseGlobally()
    }

    private func place(_ text: String) {
        board.place([(.string, Data(text.utf8)), (.rtf, Data("{\\rtf1 \(text)}".utf8))])
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
        XCTAssertEqual(pasteboard.string(forType: .string), "a")
        // The same paste asking for a second type is still one paste.
        XCTAssertNotNil(pasteboard.data(forType: .rtf))
        try await settle()
        XCTAssertEqual(pastes, 1)
        XCTAssertEqual(replaces, 0)
    }

    func testEachPlacementCountsOnce() async throws {
        place("a")
        _ = pasteboard.string(forType: .string)
        try await settle()
        place("b")
        XCTAssertEqual(pasteboard.string(forType: .string), "b")
        try await settle()
        XCTAssertEqual(pastes, 2)
    }

    func testAReadRightAfterAnAppActivatesPutsTheItemBackInstead() async throws {
        place("a")
        board.noteActivation()
        _ = pasteboard.string(forType: .string)
        try await settle()
        XCTAssertEqual(pastes, 0)
        XCTAssertEqual(replaces, 1)
    }

    func testReplacingBeforeTheDelayCancelsThePendingPaste() async throws {
        place("a")
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
}
