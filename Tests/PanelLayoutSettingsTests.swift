import AppKit
import XCTest

final class PanelLayoutSettingsTests: XCTestCase {
    /// Two side-by-side screens, with the built-in display first.
    private let displays = [CGRect(x: 0, y: 0, width: 1200, height: 800),
                            CGRect(x: 1200, y: 0, width: 1200, height: 800)]
    /// Owner used for entries belonging to the frontmost app.
    private let frontPID: pid_t = 42

    /// Models an entry in the onscreen window list.
    /// - Parameters:
    ///   - bounds: WindowServer frame in points.
    ///   - owner: Owner PID, defaulting to the frontmost app.
    ///   - level: WindowServer layer, defaulting to a normal window.
    ///   - alpha: Window opacity reported by WindowServer.
    private func window(_ bounds: CGRect, owner: pid_t? = nil, level: NSWindow.Level = .normal,
                        alpha: CGFloat = 1) -> [String: Any] {
        [kCGWindowOwnerPID as String: owner ?? frontPID,
         kCGWindowLayer as String: level.rawValue,
         kCGWindowAlpha as String: alpha,
         kCGWindowBounds as String: bounds.dictionaryRepresentation]
    }

    /// The reviewer saw a 66 × 20 pt entry ahead of a document with 73% of its width on the right.
    @MainActor
    func testSmallOverlayAheadOfSpanningDocument() {
        // The overlay and the majority of the document occupy different displays.
        let overlay = window(CGRect(x: 25, y: 80, width: 66, height: 20))
        // Of the document's 1000 pt width, 730 pt are on the right display.
        let document = window(CGRect(x: 930, y: 80, width: 1000, height: 600))
        XCTAssertEqual(PanelScreen.screenIndex(forWindows: [overlay, document], ownerPID: frontPID, in: displays), 1)
    }

    /// An ordinary front document takes precedence over a larger document behind it.
    @MainActor
    func testSmallerFrontDocumentWinsOverLargerBackgroundDocument() {
        // The two documents are on opposite displays so their order is observable.
        let front = window(CGRect(x: 1300, y: 100, width: 250, height: 180))
        // The larger background document occupies most of the built-in display.
        let back = window(CGRect(x: 25, y: 80, width: 1000, height: 600))
        XCTAssertEqual(PanelScreen.screenIndex(forWindows: [front, back], ownerPID: frontPID, in: displays), 1)
    }

    /// A compact window can be the app's only window. Other apps and floating layers are ineligible.
    @MainActor
    func testCompactWindowFallback() {
        // Only the small normal-layer window belongs to the front app and is eligible.
        let compact = window(CGRect(x: 1300, y: 80, width: 66, height: 20))
        // A full-size rect on the other display makes an incorrect choice visible.
        let otherFrame = CGRect(x: 100, y: 100, width: 700, height: 400)
        // These entries either belong to a different app or have no eligible visible content.
        let ineligible = [window(otherFrame, owner: frontPID + 1), window(otherFrame, level: .floating),
                          window(otherFrame, alpha: 0), window(.zero), window(otherFrame.offsetBy(dx: 3000, dy: 0))]
        XCTAssertEqual(PanelScreen.screenIndex(forWindows: [compact] + ineligible, ownerPID: frontPID, in: displays), 1)
        XCTAssertNil(PanelScreen.screenIndex(forWindows: ineligible, ownerPID: frontPID, in: displays))
    }

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
