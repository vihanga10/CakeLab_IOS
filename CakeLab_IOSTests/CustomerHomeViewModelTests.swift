import XCTest
@testable import CakeLab_IOS

@MainActor
final class CustomerHomeViewModelTests: XCTestCase {

    func testInitialStateIsEmptyAndIdle() {
        let viewModel = CustomerHomeViewModel()

        XCTAssertTrue(viewModel.activeOrders.isEmpty)
        XCTAssertTrue(viewModel.artisans.isEmpty)
        XCTAssertFalse(viewModel.isLoadingOrders)
        XCTAssertFalse(viewModel.isLoadingArtisans)
        XCTAssertNil(viewModel.errorMessage)
    }
}
