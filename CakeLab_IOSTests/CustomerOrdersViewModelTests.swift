import XCTest
@testable import CakeLab_IOS

@MainActor
final class CustomerOrdersViewModelTests: XCTestCase {

    // MARK: - Initial State

    func testInitialStateIsEmptyAndNotLoading() {
        let viewModel = CustomerOrdersViewModel()

        XCTAssertTrue(viewModel.activeOrders.isEmpty)
        XCTAssertTrue(viewModel.completedOrders.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - CustomerOrder(from: CakeOrder) converter

    func testCustomerOrderFromCakeOrderCopiesFields() {
        let deliveryDate = Date(timeIntervalSince1970: 1_800_000_000)
        let cakeOrder = CakeOrder(
            id: "order-123",
            customerId: "cust-001",
            artisanId: "artisan-001",
            cakeName: "Strawberry Dream",
            status: "baking",
            currentStep: 2,
            deliveryDate: deliveryDate,
            deliveryTime: nil,
            deliveryDateTime: nil,
            artisanName: "The Cake Studio",
            artisanRating: "4.9 (55 reviews)",
            artisanAddress: "Kandy",
            imageURL: nil,
            referenceImages: [],
            category: "Birthday",
            budgetMin: 6000,
            budgetMax: 9000
        )

        let customerOrder = CustomerOrder(from: cakeOrder)

        XCTAssertEqual(customerOrder.id, "order-123")
        XCTAssertEqual(customerOrder.cakeName, "Strawberry Dream")
        XCTAssertEqual(customerOrder.bakerName, "The Cake Studio")
        XCTAssertEqual(customerOrder.bakerRating, "4.9 (55 reviews)")
        XCTAssertEqual(customerOrder.bakerAddress, "Kandy")
        XCTAssertEqual(customerOrder.currentStep, 2)
    }

    func testCustomerOrderCurrentStepIsClampedToValidRange() {
        let makeOrder: (Int) -> CustomerOrder = { step in
            CustomerOrder(from: CakeOrder(
                id: "order-clamp",
                customerId: "c",
                artisanId: "a",
                cakeName: "Cake",
                status: "confirmed",
                currentStep: step,
                deliveryDate: Date(),
                deliveryTime: nil,
                deliveryDateTime: nil,
                artisanName: "Baker",
                artisanRating: "5.0",
                artisanAddress: "Colombo",
                imageURL: nil,
                referenceImages: [],
                category: "Wedding",
                budgetMin: 0,
                budgetMax: 0
            ))
        }

        XCTAssertEqual(makeOrder(0).currentStep, 1)   // clamped up to 1
        XCTAssertEqual(makeOrder(3).currentStep, 3)   // within range
        XCTAssertEqual(makeOrder(6).currentStep, 5)   // clamped down to 5
    }
}
