import XCTest
import SwiftUI
import LocalAuthentication
import WidgetKit
import MapKit
import EventKit
import PDFKit
import Charts
import AVFoundation
@testable import CakeLab_IOS

final class CakeLabMainUnitTests: XCTestCase {

    override func tearDown() {
        CustomerNavState.shared.reset()
        super.tearDown()
    }

    // MARK: - User Authentication & Face ID

    func testAuthenticationUserRolesUseExpectedBackendValues() {
        XCTAssertEqual(UserRole.customer.rawValue, "customer")
        XCTAssertEqual(UserRole.baker.rawValue, "baker")
        XCTAssertNil(UserRole(rawValue: "admin"))
    }

    func testAuthenticationUserCodableRoundTripPreservesProfileFields() throws {
        let user = AppUser(
            id: "user-001",
            email: "customer@cakelab.com",
            name: "Cake Customer",
            role: .customer,
            avatarURL: "https://example.com/avatar.png",
            fcmToken: "token-001",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            phoneNumber: "0771234567",
            address: "No 10, Galle Road",
            city: "Colombo",
            postalCode: "00300",
            dateOfBirth: Date(timeIntervalSince1970: 900_000_000)
        )

        let encoded = try JSONEncoder().encode(user)
        let decoded = try JSONDecoder().decode(AppUser.self, from: encoded)

        XCTAssertEqual(decoded.id, user.id)
        XCTAssertEqual(decoded.role, .customer)
        XCTAssertEqual(decoded.phoneNumber, "0771234567")
        XCTAssertEqual(decoded.city, "Colombo")
    }

    func testAuthenticationErrorsExposeUserFriendlyMessages() {
        XCTAssertEqual(AuthError.invalidEmail.errorDescription, "Please enter a valid email address.")
        XCTAssertEqual(AuthError.passwordMismatch.errorDescription, "Passwords do not match.")
        XCTAssertEqual(AuthError.networkError("No connection").errorDescription, "No connection")
    }

   

    func testFaceIDAuthenticationReturnsInjectedSuccessResult() async throws {
        let manager = BiometricManager(context: MockBiometricContext(canEvaluate: true, authenticationResult: true))

        let result = try await manager.authenticate(reason: "Unit test Face ID")

        XCTAssertTrue(result)
    }

    func testFaceIDAuthenticationReturnsInjectedFailureResult() async throws {
        let manager = BiometricManager(context: MockBiometricContext(canEvaluate: true, authenticationResult: false))

        let result = try await manager.authenticate(reason: "Unit test Face ID")

        XCTAssertFalse(result)
    }

    // MARK: - Push Notifications: Customer & Baker

    func testCustomerPushNotificationTypesHaveExpectedTitlesAndCategories() {
        XCTAssertEqual(NotificationType.orderStatusUpdated.title, "Order Status Updated")
        XCTAssertEqual(NotificationType.paymentReceipt.title, "Payment Successful")
        XCTAssertEqual(NotificationType.orderStatusUpdated.category, "Order Lifecycle")
        XCTAssertEqual(NotificationType.paymentReceipt.category, "Engagement")
    }

    func testBakerPushNotificationTypesHaveExpectedTitlesAndCategories() {
        XCTAssertEqual(NotificationType.bakerOrderConfirmed.title, "Order Confirmed - Ready to Bake")
        XCTAssertEqual(NotificationType.bakerPaymentReceived.title, "Payment Received")
        XCTAssertEqual(NotificationType.bakerOrderConfirmed.category, "Order Management")
        XCTAssertEqual(NotificationType.bakerPaymentReceived.category, "Baker Engagement")
    }

    func testAppNotificationCodableRoundTripPreservesRoutingIDs() throws {
        let notification = AppNotification(
            id: "notification-001",
            type: .bakerPaymentReceived,
            title: NotificationType.bakerPaymentReceived.title,
            message: "Payment received",
            userType: "baker",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            isRead: false,
            relatedOrderID: "order-001",
            relatedBakerID: "baker-001",
            relatedCustomerID: "customer-001"
        )

        let encoded = try JSONEncoder().encode(notification)
        let decoded = try JSONDecoder().decode(AppNotification.self, from: encoded)

        XCTAssertEqual(decoded.type, .bakerPaymentReceived)
        XCTAssertEqual(decoded.relatedOrderID, "order-001")
        XCTAssertEqual(decoded.relatedCustomerID, "customer-001")
        XCTAssertFalse(decoded.isRead)
    }

    // MARK: - Core Data Home Screens: Customer & Baker

    func testCustomerHomeArtisanProfileFormatsRatingAndReviews() {
        let artisan = makeArtisan(rating: 4.75, reviewCount: 18)

        XCTAssertEqual(artisan.ratingText, "4.8")
        XCTAssertEqual(artisan.reviewsText, "(18 reviews)")
    }

    // MARK: - iOS Advanced Features

    func testWidgetKitDeepLinkRoutesParseCustomerAndBakerTargets() throws {
        let customerURL = try XCTUnwrap(URL(string: "cakelab://widget/customer/status"))
        let bakerURL = try XCTUnwrap(URL(string: "cakelab://widget/baker/matching"))
        let invalidURL = try XCTUnwrap(URL(string: "https://widget/customer/status"))

        XCTAssertEqual(WidgetDeepLinkRoute(url: customerURL), .customerStatus)
        XCTAssertEqual(WidgetDeepLinkRoute(url: bakerURL), .bakerMatching)
        XCTAssertNil(WidgetDeepLinkRoute(url: invalidURL))
    }

    func testWidgetKitLoggedOutSnapshotIsSafeForWidgetRendering() {
        let payload = WidgetSnapshotPayload.loggedOut

        XCTAssertFalse(String(describing: WidgetCenter.shared).isEmpty)
        XCTAssertFalse(payload.isLoggedIn)
        XCTAssertEqual(payload.role, .unknown)
        XCTAssertTrue(payload.customerActiveOrders.isEmpty)
        XCTAssertNil(payload.bakerLatestMatchingRequest)
    }

    func testMapKitRegionCanCenterOnArtisanCoordinates() {
        let artisan = makeArtisan(latitude: 6.9271, longitude: 79.8612)
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: artisan.latitude, longitude: artisan.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
        )

        XCTAssertEqual(region.center.latitude, 6.9271, accuracy: 0.0001)
        XCTAssertEqual(region.center.longitude, 79.8612, accuracy: 0.0001)
        XCTAssertEqual(region.span.latitudeDelta, 0.06, accuracy: 0.0001)
    }

    func testEventKitDeliveryAlarmsAndCalendarErrorsAreConfigured() {
        let oneHourReminder = EKAlarm(relativeOffset: -60 * 60)
        let oneDayReminder = EKAlarm(relativeOffset: -24 * 60 * 60)

        XCTAssertEqual(oneHourReminder.relativeOffset, -3_600)
        XCTAssertEqual(oneDayReminder.relativeOffset, -86_400)
        XCTAssertEqual(
            CalendarEventManager.CalendarError.accessDenied.errorDescription,
            "Calendar access is denied. Please enable Calendar permission in Settings."
        )
    }

    func testPDFKitReceiptRendererCreatesReadablePDFDocument() throws {
        let pdfData = PDFReceiptRenderer.makePDF(from: makePDFReceipt())
        let document = try XCTUnwrap(PDFDocument(data: pdfData))

        XCTAssertGreaterThan(pdfData.count, 0)
        XCTAssertEqual(document.pageCount, 1)
        XCTAssertNotNil(document.page(at: 0))
    }

    @available(iOS 16.0, *)
    func testSwiftUIChartsCanBeBuiltFromAnalyticsPoints() {
        let points = [
            AnalyticsChartPoint(label: "May", value: 2),
            AnalyticsChartPoint(label: "Jun", value: 4)
        ]
        let chart = Chart(points) { point in
            BarMark(
                x: .value("Month", point.label),
                y: .value("Orders", point.value)
            )
        }

        XCTAssertFalse(String(describing: type(of: chart)).isEmpty)
    }

    func testAVSpeechSynthesizerUtteranceUsesAccessibleReadoutText() {
        let utterance = AVSpeechUtterance(string: "Order status updated")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0

        XCTAssertEqual(utterance.speechString, "Order status updated")
        XCTAssertEqual(utterance.rate, AVSpeechUtteranceDefaultSpeechRate)
        XCTAssertEqual(utterance.pitchMultiplier, 1.0)
    }

    // MARK: - Baker Order Management

    func testBakerOrderManagementMapsKnownStatusesToDisplayLabels() {
        XCTAssertEqual(makeBakerOrder(status: "confirmed").statusLabel, "Confirmed")
        XCTAssertEqual(makeBakerOrder(status: "baking").statusLabel, "Baking")
        XCTAssertEqual(makeBakerOrder(status: "decorating").statusLabel, "Decorating")
        XCTAssertEqual(makeBakerOrder(status: "ready").statusLabel, "Ready to Collect")
    }

    // MARK: - Order Status Tracking: Customer & Baker

    func testCustomerOrderStoresTrackingFields() {
        let customerOrder = makeCustomerOrder(status: "Quality Check", currentStep: 4)

        XCTAssertEqual(customerOrder.status, "Quality Check")
        XCTAssertEqual(customerOrder.currentStep, 4)
        XCTAssertEqual(customerOrder.bakerName, "Sweet Bakery")
        XCTAssertEqual(customerOrder.category, "Birthday")
    }

    func testCustomerOrderStoresBakerAndBudgetDetails() {
        let customerOrder = makeCustomerOrder(budgetMin: 5_000, budgetMax: 8_000)

        XCTAssertEqual(customerOrder.bakerID, "artisan-001")
        XCTAssertEqual(customerOrder.bakerRating, "4.8")
        XCTAssertEqual(customerOrder.budgetMin, 5_000)
        XCTAssertEqual(customerOrder.budgetMax, 8_000)
    }

    func testCustomerOrderStatusBakerProfileStoresPhoneNumber() {
        let profile = OrderStatusBakerProfile(
            name: "Sweet Bakery",
            ratingText: "4.9",
            reviewCount: 20,
            address: "Colombo 05",
            city: "Colombo",
            phone: "0712345678",
            profileImageBase64: "",
            imageURL: ""
        )

        XCTAssertEqual(profile.phone, "0712345678")
    }

    @MainActor
    func testCustomerOrderStatusViewModelInitialStateIsLoading() {
        let viewModel = CustomerOrderStatusViewModel()

        XCTAssertTrue(viewModel.isLoading)
        XCTAssertNil(viewModel.order)
        XCTAssertTrue(viewModel.progressTimestamps.isEmpty)
    }

    @MainActor
    func testCustomerOrderStatusTimestampLookupReturnsStoredDate() {
        let viewModel = CustomerOrderStatusViewModel()
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        viewModel.progressTimestamps["baking"] = date

        XCTAssertEqual(viewModel.timestamp(for: "baking"), date)
        XCTAssertNil(viewModel.timestamp(for: "delivered"))
    }

    // MARK: - Baker Portfolio

    func testBakerPortfolioWorkDictionaryCreatesValidWork() {
        let work = PortfolioPreviewWork(dictionary: [
            "workID": "work-001",
            "title": "Wedding Cake",
            "description": "Gold floral design",
            "imageBase64": "base64-image",
            "traits": []
        ])

        XCTAssertEqual(work?.id, "work-001")
        XCTAssertEqual(work?.title, "Wedding Cake")
        XCTAssertEqual(work?.imageReference, "base64-image")
    }

    func testBakerPortfolioWorkDictionaryRejectsMissingImageReference() {
        let work = PortfolioPreviewWork(dictionary: [
            "workID": "work-002",
            "title": "No Image"
        ])

        XCTAssertNil(work)
    }

    func testBakerProfileEmptyHasSafeDefaultPortfolioState() {
        XCTAssertEqual(BakerProfileData.empty.shopName, "Baker Shop")
        XCTAssertTrue(BakerProfileData.empty.portfolioWorks.isEmpty)
        XCTAssertEqual(BakerProfileData.empty.specialties, ["Custom Cakes"])
    }

    // MARK: - Customer/Baker Profile & Payment History

    func testCustomerPaymentHistoryIdentifiesPaymentMethods() {
        XCTAssertTrue(makePaymentRecord(method: "apple_pay").isApplePay)
        XCTAssertTrue(makePaymentRecord(method: "google_pay").isGooglePay)
        XCTAssertTrue(makePaymentRecord(method: "cash").isCash)
        XCTAssertTrue(makePaymentRecord(method: "credit card").isCard)
    }

    func testCustomerPaymentHistoryMasksCardLastFourDigits() {
        XCTAssertEqual(makePaymentRecord(cardLast4: "4242").maskedCard, "•••• 4242")
        XCTAssertEqual(makePaymentRecord(cardLast4: "").maskedCard, "")
    }

    func testCustomerPaymentHistorySuccessDependsOnStatus() {
        XCTAssertTrue(makePaymentRecord(status: "success").isSuccess)
        XCTAssertFalse(makePaymentRecord(status: "failed").isSuccess)
    }

    func testBakerEarningsDataFormatsSummaryValues() {
        let data = EarningsData(
            totalEarningsThisMonth: 39_000,
            totalEarningsLastMonth: 12_000,
            totalEarningsThisYear: 51_000,
            avgPerOrder: 17_000
        )

        XCTAssertEqual(data.thisMonthFormatted, "LKR 39000")
        XCTAssertEqual(data.avgPerOrderFormatted, "LKR 17000")
    }

    // MARK: - Test Helpers

    private func makeArtisan(
        rating: Double = 4.7,
        reviewCount: Int = 32,
        latitude: Double = 6.9271,
        longitude: Double = 79.8612
    ) -> ArtisanProfile {
        ArtisanProfile(
            id: "artisan-001",
            name: "Cake Haven",
            rating: rating,
            reviewCount: reviewCount,
            specialties: ["Wedding Cakes", "Birthday Cakes"],
            city: "Colombo",
            location: "45 Galle Road, Colombo",
            isOnline: true,
            imageURL: nil,
            profileImageBase64: "",
            latitude: latitude,
            longitude: longitude
        )
    }

    private func makeCustomerOrder(
        status: String = "Confirmed",
        currentStep: Int = 1,
        budgetMin: Double = 5_000,
        budgetMax: Double = 8_000
    ) -> CustomerOrder {
        CustomerOrder(
            id: "order-001",
            cakeName: "Chocolate Birthday Cake",
            status: status,
            statusColor: .green,
            deliveryDate: "15/05/2026",
            currentStep: currentStep,
            bakerID: "artisan-001",
            bakerName: "Sweet Bakery",
            bakerRating: "4.8",
            bakerAddress: "Colombo 05",
            category: "Birthday",
            budgetMin: budgetMin,
            budgetMax: budgetMax
        )
    }

    private func makeBakerOrder(status: String) -> BakerOrderFull {
        BakerOrderFull(
            cakeName: "Wedding Cake",
            customerName: "Nimali Perera",
            deliveryDate: "15/05/2026",
            location: "Colombo",
            status: status,
            amount: "LKR 15000",
            progressPercent: 60,
            currentStep: 3,
            notes: "Handle with care"
        )
    }

    private func makeBakerPayment(
        method: String,
        status: String = "success"
    ) -> BakerPaymentRecord {
        BakerPaymentRecord(
            id: "payment-001",
            orderID: "order-001",
            amount: 7_500,
            total: 8_250,
            method: method,
            status: status,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func makePaymentRecord(
        method: String = "card",
        cardLast4: String = "4242",
        status: String = "success"
    ) -> PaymentRecord {
        PaymentRecord(
            id: "payment-001",
            orderID: "order-001",
            cakeName: "Chocolate Cake",
            bakerName: "Sweet Bakery",
            amount: 7_500,
            serviceFee: 750,
            total: 8_250,
            method: method,
            cardholderName: "Cake Customer",
            cardLast4: cardLast4,
            status: status,
            paidAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func makePDFReceipt() -> PDFReceiptData {
        PDFReceiptData(
            id: "receipt-001",
            title: "Payment Receipt",
            receiptNumber: "R-001",
            cakeName: "Chocolate Birthday Cake",
            payerLabel: "Customer",
            payerName: "Cake Customer",
            receiverLabel: "Baker",
            receiverName: "Sweet Bakery",
            paymentMethod: "Card",
            status: "success",
            paidAt: Date(timeIntervalSince1970: 1_700_000_000),
            subtotalLabel: "Bid Amount",
            subtotal: 7_500,
            serviceFee: 750,
            totalLabel: "Total Paid",
            total: 8_250
        )
    }

    private func makeCakeRequest(
        customerID: String = "customer-001",
        budgetMin: Double = 5_000,
        budgetMax: Double = 8_000
    ) -> CakeRequestRecord {
        CakeRequestRecord(
            id: "request-001",
            title: "Chocolate Birthday Cake",
            description: "A chocolate cake with buttercream.",
            customerID: customerID,
            customerName: "Customer",
            customerCity: "Colombo",
            customerAddress: "No 1, Main Street",
            category: "Birthday",
            categories: ["Birthday"],
            styles: ["Minimalist"],
            dietary: ["None"],
            tier: 1,
            cakeSize: "1kg",
            sugarLevel: 0.5,
            flavours: ["Chocolate"],
            fillingFlavour: "Chocolate",
            specialInstructions: "Use less sugar.",
            budgetMin: budgetMin,
            budgetMax: budgetMax,
            expectedDate: Date(timeIntervalSince1970: 1_800_000_000),
            expectedTime: Date(timeIntervalSince1970: 1_800_000_000),
            allowNearby: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            savedAt: nil,
            status: "open",
            bidCount: 2,
            isDirectRequest: false,
            targetArtisanId: nil,
            targetArtisanName: nil
        )
    }
}

private final class MockBiometricContext: BiometricManager.LAContextProtocol {
    let canEvaluate: Bool
    let authenticationResult: Bool

    init(canEvaluate: Bool, authenticationResult: Bool = true) {
        self.canEvaluate = canEvaluate
        self.authenticationResult = authenticationResult
    }

    func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool {
        canEvaluate
    }

    func evaluatePolicy(_ policy: LAPolicy, localizedReason: String) async throws -> Bool {
        authenticationResult
    }
}
