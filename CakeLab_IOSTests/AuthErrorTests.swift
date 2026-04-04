import XCTest
@testable import CakeLab_IOS

// MARK: - AuthError Tests
/// Tests that AuthError produces the correct localised descriptions.
final class AuthErrorTests: XCTestCase {

    func test_invalidEmail_description() {
        XCTAssertEqual(AuthError.invalidEmail.errorDescription,
                       "Please enter a valid email address.")
    }

    func test_emptyPassword_description() {
        XCTAssertEqual(AuthError.emptyPassword.errorDescription,
                       "Please enter your password.")
    }

    func test_passwordTooShort_description() {
        XCTAssertEqual(AuthError.passwordTooShort.errorDescription,
                       "Password must be at least 6 characters.")
    }

    func test_passwordMismatch_description() {
        XCTAssertEqual(AuthError.passwordMismatch.errorDescription,
                       "Passwords do not match.")
    }

    func test_roleNotSelected_description() {
        XCTAssertEqual(AuthError.roleNotSelected.errorDescription,
                       "Please select who you are.")
    }

    func test_networkError_containsMessage() {
        let msg = "Connection timed out"
        XCTAssertEqual(AuthError.networkError(msg).errorDescription, msg)
    }

    func test_unknownError_containsMessage() {
        let msg = "Something went wrong"
        XCTAssertEqual(AuthError.unknown(msg).errorDescription, msg)
    }
}
