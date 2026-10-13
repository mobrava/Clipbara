import XCTest

final class IPhoneAppNoticeTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "IPhoneAppNoticeTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testShowsUntilDismissed() {
        XCTAssertTrue(IPhoneAppNotice.shouldShow(defaults: defaults, syncEnabled: false))
        IPhoneAppNotice.dismiss(defaults: defaults)
        XCTAssertFalse(IPhoneAppNotice.shouldShow(defaults: defaults, syncEnabled: false))
    }

    func testHiddenOnceSyncIsOn() {
        XCTAssertFalse(IPhoneAppNotice.shouldShow(defaults: defaults, syncEnabled: true))
    }
}
