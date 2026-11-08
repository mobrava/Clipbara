import SwiftData
import XCTest

@MainActor
final class HistoryRetentionTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() async throws {
        container = try ModelContainer(
            for: ClipboardItem.self, Pinboard.self, PinboardEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @discardableResult
    private func clip(_ text: String, daysAgo: Double, pinned: Bool = false) -> ClipboardItem {
        let item = ClipboardItem(contentType: .plainText, rawData: Data(text.utf8), textContent: text, contentHash: text)
        item.copiedAt = now.addingTimeInterval(-daysAgo * 86_400)
        item.isPinned = pinned
        context.insert(item)
        try? context.save()
        return item
    }

    private func putOnPinboard(_ item: ClipboardItem) {
        let board = Pinboard(name: "Board")
        context.insert(board)
        context.insert(PinboardEntry(clipboardItem: item, pinboard: board))
        try? context.save()
    }

    private var remaining: [String] {
        let items = (try? context.fetch(FetchDescriptor<ClipboardItem>())) ?? []
        return items.compactMap(\.textContent).sorted()
    }

    func testForeverIsTheDefaultAndKeepsEverything() {
        UserDefaults.standard.removeObject(forKey: HistoryRetention.defaultsKey)
        XCTAssertEqual(HistoryRetention.current, .forever)
        XCTAssertNil(HistoryRetention.forever.cutoff(now: now))
        clip("ancient", daysAgo: 4_000)
        XCTAssertEqual(HistoryRetention.deleteExpired(for: .forever, in: context, now: now), 0)
        XCTAssertEqual(remaining, ["ancient"])
    }

    func testRemovesOnlyUnpinnedClipsPastTheLimit() {
        clip("old", daysAgo: 10)
        clip("recent", daysAgo: 3)
        clip("old pinned", daysAgo: 10, pinned: true)
        let onBoard = clip("old on a pinboard", daysAgo: 10)
        putOnPinboard(onBoard)

        XCTAssertEqual(HistoryRetention.expiredItems(for: .week, in: context, now: now).compactMap(\.textContent), ["old"])
        XCTAssertEqual(HistoryRetention.deleteExpired(for: .week, in: context, now: now), 1)
        XCTAssertEqual(remaining, ["old on a pinboard", "old pinned", "recent"])
    }

    func testCutoffsMatchTheirPeriods() {
        let day: TimeInterval = 86_400
        XCTAssertEqual(HistoryRetention.day.cutoff(now: now)!.timeIntervalSince(now), -day, accuracy: 3_600)
        XCTAssertEqual(HistoryRetention.month.cutoff(now: now)!.timeIntervalSince(now), -30 * day, accuracy: 3_600)
        XCTAssertEqual(HistoryRetention.year.cutoff(now: now)!.timeIntervalSince(now), -365 * day, accuracy: 3_600)
    }

    func testClearingKeepsPinboardClips() {
        clip("a", daysAgo: 1)
        let kept = clip("b", daysAgo: 1)
        putOnPinboard(kept)
        XCTAssertEqual(HistoryRetention.clearableItems(in: context).compactMap(\.textContent), ["a"])
    }
}
