import XCTest
@testable import CakeLab_IOS

@MainActor
final class CustomerOrderStatusViewModelTests: XCTestCase {

    // MARK: - Initial State

    func testInitialStateIsLoadingWithNoOrderOrError() {
        let viewModel = CustomerOrderStatusViewModel()

        XCTAssertTrue(viewModel.isLoading)
        XCTAssertNil(viewModel.order)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testProgressTimestampsStartEmpty() {
        let viewModel = CustomerOrderStatusViewModel()

        XCTAssertTrue(viewModel.progressTimestamps.isEmpty)
    }

    func testCreatedAtStartsNil() {
        let viewModel = CustomerOrderStatusViewModel()

        XCTAssertNil(viewModel.createdAt)
    }

    // MARK: - timestamp(for:)

    func testTimestampReturnsNilForUnknownStatusKey() {
        let viewModel = CustomerOrderStatusViewModel()

        XCTAssertNil(viewModel.timestamp(for: "confirmed"))
        XCTAssertNil(viewModel.timestamp(for: "baking"))
    }

    func testTimestampReturnsStoredDateAfterManualInjection() {
        let viewModel = CustomerOrderStatusViewModel()
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        viewModel.progressTimestamps["baking"] = date

        XCTAssertEqual(viewModel.timestamp(for: "baking"), date)
    }

    // MARK: - requestCategory / requestBudget

    func testRequestCategoryIsNilInitially() {
        let viewModel = CustomerOrderStatusViewModel()

        XCTAssertNil(viewModel.requestCategory)
    }

    func testRequestBudgetMinIsNilInitially() {
        let viewModel = CustomerOrderStatusViewModel()

        XCTAssertNil(viewModel.requestBudgetMin)
        XCTAssertNil(viewModel.requestBudgetMax)
    }
}
