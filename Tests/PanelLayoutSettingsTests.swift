import XCTest

final class PanelLayoutSettingsTests: XCTestCase {
    /// The default size matches the original panel both with and without the iPhone banner.
    func testDefaultCardDimensions() {
        // The default panel has a 44-point navigation bar above its card row.
        let height = PanelCardSize.defaultHeight
        XCTAssertEqual(height, 280)
        XCTAssertEqual(PanelCardSize.cardSize(rowHeight: 236, panelHeight: height),
                       CGSize(width: 188 * 1.16, height: 188))
        XCTAssertEqual(PanelCardSize.cardSize(rowHeight: 190, panelHeight: height),
                       CGSize(width: 206, height: 164))
    }

    /// A fixed upper or lower card bound used to make several slider stops look identical.
    func testEverySliderStopChangesBothDimensions() {
        for reservedHeight: CGFloat in [44, 90] {
            // Track successive steps in the same row layout.
            var previous = CGSize.zero
            for height in stride(from: PanelCardSize.range.lowerBound, through: PanelCardSize.range.upperBound,
                                 by: PanelCardSize.step) {
                // Each grid receives just the height left below navigation and any banner.
                let size = PanelCardSize.cardSize(rowHeight: height - reservedHeight, panelHeight: height)
                XCTAssertGreaterThan(size.width, previous.width)
                XCTAssertGreaterThan(size.height, previous.height)
                XCTAssertLessThan(size.height, height - reservedHeight)
                previous = size
            }
        }
    }

    /// Persisted preferences are validated before they reach the window frame.
    func testOutOfRangeHeights() {
        XCTAssertEqual(PanelCardSize.clampedHeight(-1), PanelCardSize.range.lowerBound)
        XCTAssertEqual(PanelCardSize.clampedHeight(1000), PanelCardSize.range.upperBound)
        XCTAssertEqual(PanelCardSize.clampedHeight(.nan), PanelCardSize.defaultHeight)
    }

    /// WindowServer and AppKit use opposite vertical axes in multi-display layouts.
    func testScreenContainingMostOfTheWindow() {
        // One display above the primary screen and one to its left.
        let frames = [CGRect(x: 0, y: 0, width: 1200, height: 800),
                      CGRect(x: 0, y: 800, width: 1000, height: 700),
                      CGRect(x: -900, y: 0, width: 900, height: 700)]
        XCTAssertEqual(PanelScreen.screenIndex(forWindow: CGRect(x: 50, y: -180, width: 400, height: 210), in: frames), 1)
        XCTAssertEqual(PanelScreen.screenIndex(forWindow: CGRect(x: -300, y: 150, width: 420, height: 250), in: frames), 2)
        XCTAssertEqual(PanelScreen.screenIndex(forWindow: CGRect(x: -100, y: 150, width: 420, height: 250), in: frames), 0)
        XCTAssertNil(PanelScreen.screenIndex(forWindow: CGRect(x: 1200, y: 100, width: 100, height: 100), in: frames))
    }
}
