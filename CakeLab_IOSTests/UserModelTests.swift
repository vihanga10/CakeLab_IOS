import XCTest
@testable import CakeLab_IOS

// MARK: - AppUser Model Tests
/// Tests that AppUser encodes and decodes correctly from Firestore data.
@MainActor
final class UserModelTests: XCTestCase {

    // MARK: - Coding Tests

    /// AppUser should encode and decode all fields correctly via JSONEncoder/Decoder.
    func test_appUser_encodeDecode_roundtrip() throws {
        let original = AppUser(
            id: "uid-123",
            email: "test@cakelab.com",
            name: "Cake Lover",
            role: .customer,
            avatarURL: "https://example.com/avatar.jpg",
            fcmToken: "fcm-token-abc",
            createdAt: Date(timeIntervalSince1970: 1_000_000)
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppUser.self, from: encoded)

        XCTAssertEqual(decoded.id,        original.id)
        XCTAssertEqual(decoded.email,     original.email)
        XCTAssertEqual(decoded.name,      original.name)
        XCTAssertEqual(decoded.role,      original.role)
        XCTAssertEqual(decoded.avatarURL, original.avatarURL)
        XCTAssertEqual(decoded.fcmToken,  original.fcmToken)
    }

    /// Baker role should round-trip correctly.
    func test_appUser_bakerRole_roundtrip() throws {
        let baker = AppUser.mockBaker

        let encoded = try JSONEncoder().encode(baker)
        let decoded = try JSONDecoder().decode(AppUser.self, from: encoded)

        XCTAssertEqual(decoded.role, .baker)
    }

    // MARK: - UserRole Tests

    /// Customer role raw value should match Firestore string.
    func test_userRole_customer_rawValue() {
        XCTAssertEqual(UserRole.customer.rawValue, "customer")
    }

    /// Baker role raw value should match Firestore string.
    func test_userRole_baker_rawValue() {
        XCTAssertEqual(UserRole.baker.rawValue, "baker")
    }

    /// Unknown role raw value should decode to customer as fallback.
    func test_userRole_unknownRaw_defaultsToNil() {
        XCTAssertNil(UserRole(rawValue: "admin"))
    }

    // MARK: - Mock Tests

    /// Mock user should have the expected customer role.
    func test_mockUser_isCustomer() {
        XCTAssertEqual(AppUser.mock.role, .customer)
    }

    /// Mock baker should have the baker role.
    func test_mockBaker_isBaker() {
        XCTAssertEqual(AppUser.mockBaker.role, .baker)
    }

    /// Mock users should have unique IDs.
    func test_mockUsers_haveUniqueIDs() {
        XCTAssertNotEqual(AppUser.mock.id, AppUser.mockBaker.id)
    }
}
