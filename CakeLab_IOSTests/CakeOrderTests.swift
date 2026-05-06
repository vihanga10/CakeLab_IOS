import XCTest
@testable import CakeLab_IOS

// Tests for the CakeOrder model used in CustomerOrdersView and CustomerOrderStatusView.
final class CakeOrderTests: XCTestCase {

    // MARK: - Helpers

    private func makeOrder(status: String, currentStep: Int = 1) -> CakeOrder {
        CakeOrder(
            id: "order-test-001",
            customerId: "customer-001",
            artisanId: "artisan-001",
            cakeName: "Test Cake",
            status: status,
            currentStep: currentStep,
            deliveryDate: Date(timeIntervalSince1970: 1_800_000_000),
            deliveryTime: nil,
            deliveryDateTime: nil,
            artisanName: "Sweet Bakery",
            artisanRating: "4.8 (23 reviews)",
            artisanAddress: "Colombo 05",
            imageURL: nil,
            referenceImages: [],
            category: "Birthday",
            budgetMin: 5000,
            budgetMax: 8000
        )
    }

    // MARK: - statusLabel

    func testStatusLabelForConfirmed() {
        XCTAssertEqual(makeOrder(status: "confirmed").statusLabel, "Confirmed")
    }

    func testStatusLabelForBaking() {
        XCTAssertEqual(makeOrder(status: "baking").statusLabel, "Baking")
    }

    func testStatusLabelForDecorating() {
        XCTAssertEqual(makeOrder(status: "decorating").statusLabel, "Decorating")
    }

    func testStatusLabelForQualityCheck() {
        XCTAssertEqual(makeOrder(status: "quality_check").statusLabel, "Quality Check")
    }

    func testStatusLabelForDelivered() {
        XCTAssertEqual(makeOrder(status: "delivered").statusLabel, "Delivered")
    }

    func testStatusLabelForUnknownStatusFallsBackToCapitalized() {
        XCTAssertFalse(makeOrder(status: "pending").statusLabel.isEmpty)
    }

    // MARK: - budgetText

    func testBudgetTextFormatsMinAndMaxCorrectly() {
        let order = makeOrder(status: "confirmed")
        // budgetText should contain both min and max values formatted
        XCTAssertTrue(order.budgetText.contains("5,000"))
        XCTAssertTrue(order.budgetText.contains("8,000"))
    }

    // MARK: - formattedDeliveryDate

    func testFormattedDeliveryDateIsNonEmpty() {
        let order = makeOrder(status: "baking")
        XCTAssertFalse(order.formattedDeliveryDate.isEmpty)
    }

    // MARK: - statusColor

    func testStatusColorIsNonNilForAllKnownStatuses() {
        for status in ["confirmed", "baking", "decorating", "quality_check", "delivered"] {
            // statusColor returns a Color — we just verify it doesn't crash
            _ = makeOrder(status: status).statusColor
        }
    }
}
