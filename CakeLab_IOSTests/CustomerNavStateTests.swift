import XCTest
@testable import CakeLab_IOS

@MainActor
final class CustomerNavStateTests: XCTestCase {

    override func tearDown() {
        CustomerNavState.shared.reset()
        super.tearDown()
    }

    func testNavigateToUpdatesSelectedTabAndResetCounter() {
        let navState = CustomerNavState.shared
        navState.reset()

        navState.navigateTo(2)

        XCTAssertEqual(navState.selectedTab, 2)
        XCTAssertEqual(navState.tabResetIDs[2], 1)
    }

    func testResetReturnsNavigationStateToDefaults() {
        let navState = CustomerNavState.shared
        navState.selectedTab = 3
        navState.depth = 2
        navState.tabResetIDs = [0: 4, 1: 3, 2: 2, 3: 1]

        navState.reset()

        XCTAssertEqual(navState.selectedTab, 0)
        XCTAssertEqual(navState.depth, 0)
        XCTAssertEqual(navState.tabResetIDs, [0: 0, 1: 0, 2: 0, 3: 0])
    }
}
