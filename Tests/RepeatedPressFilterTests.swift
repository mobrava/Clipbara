import XCTest

final class RepeatedPressFilterTests: XCTestCase {
    func testFirstPressIsAccepted() {
        var filter = RepeatedPressFilter()
        XCTAssertTrue(filter.accept(at: .now))
    }

    func testBurstFromOnePressCountsOnce() {
        // One press reported four times: at 0 ms, then three times 51 ms later.
        var filter = RepeatedPressFilter()
        let start = ContinuousClock.now
        XCTAssertTrue(filter.accept(at: start))
        for _ in 0..<3 {
            XCTAssertFalse(filter.accept(at: start.advanced(by: .milliseconds(51))))
        }
    }

    func testSeparatePressesAreAccepted() {
        var filter = RepeatedPressFilter()
        let start = ContinuousClock.now
        XCTAssertTrue(filter.accept(at: start))
        XCTAssertTrue(filter.accept(at: start.advanced(by: .milliseconds(150))))
        XCTAssertTrue(filter.accept(at: start.advanced(by: .milliseconds(300))))
    }

    func testRejectedPressDoesNotExtendTheWindow() {
        var filter = RepeatedPressFilter()
        let start = ContinuousClock.now
        XCTAssertTrue(filter.accept(at: start))
        XCTAssertFalse(filter.accept(at: start.advanced(by: .milliseconds(60))))
        XCTAssertTrue(filter.accept(at: start.advanced(by: .milliseconds(110))))
    }
}
