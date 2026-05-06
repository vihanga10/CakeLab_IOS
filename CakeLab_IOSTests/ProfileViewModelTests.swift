import XCTest
import UIKit
@testable import CakeLab_IOS

@MainActor
final class ProfileViewModelTests: XCTestCase {

    private let avatarKey = "profileAvatar_test-customer-id"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: avatarKey)
        super.tearDown()
    }

    func testInitializerCopiesUserFieldsIntoEditableFormState() {
        let user = AppUser(
            id: "test-customer-id",
            email: "customer@test.com",
            name: "Test Customer",
            role: .customer,
            avatarURL: nil,
            fcmToken: nil,
            createdAt: Date(),
            phoneNumber: "0771234567",
            address: "123 Main Street",
            city: "Colombo",
            postalCode: "10000",
            dateOfBirth: Date(timeIntervalSince1970: 0)
        )

        let viewModel = ProfileViewModel(user: user)

        XCTAssertEqual(viewModel.fullName, "Test Customer")
        XCTAssertEqual(viewModel.email, "customer@test.com")
        XCTAssertEqual(viewModel.phoneNumber, "0771234567")
        XCTAssertEqual(viewModel.address, "123 Main Street")
        XCTAssertEqual(viewModel.city, "Colombo")
        XCTAssertEqual(viewModel.postalCode, "10000")
        XCTAssertEqual(viewModel.dateOfBirth, Date(timeIntervalSince1970: 0))
    }

    func testLoadAvatarFromUserDefaultsReturnsStoredImage() {
        let user = AppUser(
            id: "test-customer-id",
            email: "customer@test.com",
            name: "Test Customer",
            role: .customer,
            avatarURL: nil,
            fcmToken: nil,
            createdAt: Date(),
            phoneNumber: nil,
            address: nil,
            city: nil,
            postalCode: nil,
            dateOfBirth: nil
        )

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        let image = renderer.image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
        UserDefaults.standard.set(data.base64EncodedString(), forKey: avatarKey)

        let viewModel = ProfileViewModel(user: user)
        let loadedImage = viewModel.loadAvatarFromUserDefaults()

        XCTAssertNotNil(loadedImage)
    }
}
