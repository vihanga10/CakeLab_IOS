import XCTest
@testable import CakeLab_IOS

final class CakeRequestRecordTests: XCTestCase {

    func testDisplayTitleFallsBackWhenTitleIsBlank() {
        let request = CakeRequestRecord(
            id: "request-1",
            title: "   ",
            description: "Description",
            customerID: "customer-1",
            customerName: "Customer",
            customerCity: "Colombo",
            customerAddress: "Address",
            category: "",
            categories: [],
            styles: [],
            dietary: [],
            tier: 1,
            cakeSize: "",
            sugarLevel: 0.5,
            flavours: [],
            fillingFlavour: "",
            specialInstructions: "",
            budgetMin: 1000,
            budgetMax: 2000,
            expectedDate: Date(timeIntervalSince1970: 0),
            expectedTime: Date(timeIntervalSince1970: 0),
            allowNearby: false,
            createdAt: Date(timeIntervalSince1970: 0),
            savedAt: nil,
            status: "open",
            bidCount: 0,
            isDirectRequest: false,
            targetArtisanId: nil,
            targetArtisanName: nil
        )

        XCTAssertEqual(request.displayTitle, "Untitled Request")
    }

    func testBudgetTextUsesExpectedCurrencyRange() {
        let request = CakeRequestRecord.mock

        XCTAssertEqual(request.budgetText, "Rs. 22,000 – 28,000")
    }

    func testCompletionPercentReflectsCompletedFields() {
        // The mock has all 10 completeness checks satisfied:
        // title, description, category, budget, styles, flavours,
        // tier, cakeSize, specialInstructions, allowNearby → 10/10 = 100 %
        let request = CakeRequestRecord.mock

        XCTAssertEqual(request.completionPercent, 100)
    }

    func testOwnedByMatchesCustomerID() {
        XCTAssertTrue(CakeRequestRecord.mock.ownedBy(userID: "customer-123"))
        XCTAssertFalse(CakeRequestRecord.mock.ownedBy(userID: "another-user"))
    }
}
