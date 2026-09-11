import AppKit
import XCTest

final class WheelScrollTranslationTests: XCTestCase {
    private func input(
        dx: Double = 0,
        dy: Double = -1,
        phase: WheelScrollTranslation.Phase = .none,
        horizontal: Bool = true,
        vertical: Bool = false
    ) -> WheelScrollTranslation.Input {
        WheelScrollTranslation.Input(
            deltaX: dx,
            deltaY: dy,
            phase: phase,
            canScrollHorizontally: horizontal,
            canScrollVertically: vertical
        )
    }

    // MARK: - Which scrolls move a sideways row

    func testAWheelNotchMovesASidewaysRow() {
        var translator = WheelScrollTranslation.Translator()
        XCTAssertTrue(translator.shouldTranslate(input(dy: -1)))
        XCTAssertTrue(translator.shouldTranslate(input(dy: 1)))
        XCTAssertTrue(translator.shouldTranslate(input(dy: -3)))
    }

    func testASidewaysScrollIsLeftAlone() {
        // Shift + wheel, a thumb wheel, and a sideways swipe all arrive as
        // horizontal movement and already work.
        var translator = WheelScrollTranslation.Translator()
        XCTAssertFalse(translator.shouldTranslate(input(dx: -1, dy: 0)))
        XCTAssertFalse(translator.shouldTranslate(input(dx: -3, dy: 1)))
    }

    func testAHighResolutionVerticalScrollAlsoMovesTheRow() {
        // A mouse with vendor smooth scrolling reports the same fine deltas a
        // trackpad does, so the device kind cannot be the deciding factor.
        var translator = WheelScrollTranslation.Translator()
        XCTAssertTrue(translator.shouldTranslate(input(dx: 0.4, dy: -6.2, phase: .began)))
    }

    func testViewsThatAlsoScrollVerticallyKeepTheScroll() {
        var translator = WheelScrollTranslation.Translator()
        XCTAssertFalse(translator.shouldTranslate(input(dy: -1, vertical: true)))
    }

    func testViewsThatCannotScrollSidewaysAreIgnored() {
        var translator = WheelScrollTranslation.Translator()
        XCTAssertFalse(translator.shouldTranslate(input(dy: -1, horizontal: false)))
        XCTAssertFalse(translator.shouldTranslate(input(dy: -1, horizontal: false, vertical: true)))
    }

    func testAnEmptyScrollDoesNothing() {
        var translator = WheelScrollTranslation.Translator()
        XCTAssertFalse(translator.shouldTranslate(input(dx: 0, dy: 0)))
    }

    // MARK: - One decision per gesture

    func testAWobblyVerticalSwipeDoesNotFlipMidGesture() {
        var translator = WheelScrollTranslation.Translator()
        XCTAssertTrue(translator.shouldTranslate(input(dx: 0.2, dy: -8, phase: .began)))
        // The swipe drifts sideways for a frame. It must not snap back to a
        // vertical scroll and jitter.
        XCTAssertTrue(translator.shouldTranslate(input(dx: -5, dy: -1, phase: .changed)))
        XCTAssertTrue(translator.shouldTranslate(input(dx: 0, dy: -4, phase: .changed)))
        XCTAssertTrue(translator.shouldTranslate(input(dx: 0, dy: 0, phase: .ended)))
    }

    func testASidewaysSwipeStaysNativeForItsWholeRun() {
        var translator = WheelScrollTranslation.Translator()
        XCTAssertFalse(translator.shouldTranslate(input(dx: -9, dy: 0.3, phase: .began)))
        XCTAssertFalse(translator.shouldTranslate(input(dx: -1, dy: 4, phase: .changed)))
        XCTAssertFalse(translator.shouldTranslate(input(dx: 0, dy: 0, phase: .ended)))
    }

    func testMomentumKeepsTheDecisionOfItsGesture() {
        var translator = WheelScrollTranslation.Translator()
        XCTAssertTrue(translator.shouldTranslate(input(dx: 0, dy: -9, phase: .began)))
        XCTAssertTrue(translator.shouldTranslate(input(dx: 0, dy: 0, phase: .ended)))
        XCTAssertTrue(translator.shouldTranslate(input(dx: -3, dy: -2, phase: .momentum)))
        XCTAssertTrue(translator.shouldTranslate(input(dx: 0, dy: 0, phase: .momentumEnded)))
    }

    func testANewGestureDecidesAgain() {
        var translator = WheelScrollTranslation.Translator()
        XCTAssertTrue(translator.shouldTranslate(input(dx: 0, dy: -9, phase: .began)))
        XCTAssertTrue(translator.shouldTranslate(input(dx: 0, dy: 0, phase: .momentumEnded)))
        XCTAssertFalse(translator.shouldTranslate(input(dx: -9, dy: 0, phase: .began)))
        XCTAssertFalse(translator.shouldTranslate(input(dx: 0, dy: -9, phase: .changed)))
    }

    func testLeavingASidewaysRowClearsTheDecision() {
        var translator = WheelScrollTranslation.Translator()
        XCTAssertTrue(translator.shouldTranslate(input(dx: 0, dy: -9, phase: .began)))
        // The pointer moves onto a view that scrolls both ways.
        XCTAssertFalse(translator.shouldTranslate(input(dx: 0, dy: -9, phase: .changed, vertical: true)))
        // Back on a sideways row, the stale decision must not be reused.
        XCTAssertFalse(translator.shouldTranslate(input(dx: -9, dy: 0, phase: .changed)))
    }

    // MARK: - Axis swap

    private func wheelEvent(lines: Int32) throws -> NSEvent {
        let cg = try XCTUnwrap(CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: lines,
            wheel2: 0,
            wheel3: 0
        ))
        return try XCTUnwrap(NSEvent(cgEvent: cg))
    }

    func testTheSwapMovesVerticalMovementOntoTheHorizontalAxis() throws {
        let wheel = try wheelEvent(lines: 3)
        XCTAssertEqual(wheel.scrollingDeltaX, 0)
        XCTAssertNotEqual(wheel.scrollingDeltaY, 0)

        let swapped = try XCTUnwrap(WheelScrollTranslation.horizontalCopy(of: wheel))
        XCTAssertEqual(swapped.scrollingDeltaX, wheel.scrollingDeltaY)
        XCTAssertEqual(swapped.scrollingDeltaY, 0)
        XCTAssertEqual(swapped.deltaX, wheel.deltaY)
        XCTAssertEqual(swapped.deltaY, 0)
    }

    func testTheSwapKeepsTheScrollDirection() throws {
        let down = try wheelEvent(lines: -3)
        let up = try wheelEvent(lines: 3)

        let swappedDown = try XCTUnwrap(WheelScrollTranslation.horizontalCopy(of: down))
        let swappedUp = try XCTUnwrap(WheelScrollTranslation.horizontalCopy(of: up))

        XCTAssertLessThan(swappedDown.scrollingDeltaX, 0)
        XCTAssertGreaterThan(swappedUp.scrollingDeltaX, 0)
        XCTAssertEqual(swappedDown.scrollingDeltaX, -swappedUp.scrollingDeltaX)
    }

    func testTheSwapKeepsTheEventAScrollEvent() throws {
        let wheel = try wheelEvent(lines: 1)
        let swapped = try XCTUnwrap(WheelScrollTranslation.horizontalCopy(of: wheel))

        XCTAssertEqual(swapped.type, .scrollWheel)
        XCTAssertFalse(swapped.hasPreciseScrollingDeltas)
        XCTAssertEqual(swapped.hasPreciseScrollingDeltas, wheel.hasPreciseScrollingDeltas)
        XCTAssertEqual(swapped.isDirectionInvertedFromDevice, wheel.isDirectionInvertedFromDevice)
    }

    func testAWheelNotchReportsNoGesturePhase() throws {
        let wheel = try wheelEvent(lines: 1)
        XCTAssertEqual(WheelScrollTranslation.phase(of: wheel), .none)
    }
}
