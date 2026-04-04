import XCTest
@testable import CakeLab_IOS

// MARK: - SignUpViewModel Unit Tests
/// Tests input validation and sign-up logic in SignUpViewModel.
@MainActor
final class SignUpViewModelTests: XCTestCase {

    private var sut: SignUpViewModel!
    private var mockService: MockAuthService!

    override func setUp() {
        super.setUp()
        mockService = MockAuthService()
        sut = SignUpViewModel(authService: mockService)
    }

    override func tearDown() {
        sut = nil
        mockService = nil
        super.tearDown()
    }

    // MARK: - Validation Tests

    /// Invalid email address should fail validation.
    func test_validate_invalidEmail_returnsFalse() {
        sut.email           = "invalidemail"
        sut.password        = "password123"
        sut.confirmPassword = "password123"
        sut.selectedRole    = .customer

        XCTAssertFalse(sut.validate())
        XCTAssertEqual(sut.errorMessage, AuthError.invalidEmail.errorDescription)
    }

    /// Password shorter than 6 characters should fail validation.
    func test_validate_shortPassword_returnsFalse() {
        sut.email           = "test@cakelab.com"
        sut.password        = "abc"
        sut.confirmPassword = "abc"
        sut.selectedRole    = .customer

        XCTAssertFalse(sut.validate())
        XCTAssertEqual(sut.errorMessage, AuthError.passwordTooShort.errorDescription)
    }

    /// Mismatched passwords should fail validation.
    func test_validate_passwordMismatch_returnsFalse() {
        sut.email           = "test@cakelab.com"
        sut.password        = "password123"
        sut.confirmPassword = "differentPass"
        sut.selectedRole    = .customer

        XCTAssertFalse(sut.validate())
        XCTAssertEqual(sut.errorMessage, AuthError.passwordMismatch.errorDescription)
    }

    /// No role selected should fail validation.
    func test_validate_noRole_returnsFalse() {
        sut.email           = "test@cakelab.com"
        sut.password        = "password123"
        sut.confirmPassword = "password123"
        sut.selectedRole    = nil

        XCTAssertFalse(sut.validate())
        XCTAssertEqual(sut.errorMessage, AuthError.roleNotSelected.errorDescription)
    }

    /// All valid customer inputs should pass validation.
    func test_validate_validCustomer_returnsTrue() {
        sut.email           = "cake@example.com"
        sut.password        = "securePass1"
        sut.confirmPassword = "securePass1"
        sut.selectedRole    = .customer

        XCTAssertTrue(sut.validate())
        XCTAssertNil(sut.errorMessage)
    }

    /// All valid baker inputs should pass validation.
    func test_validate_validBaker_returnsTrue() {
        sut.email           = "baker@cakelab.com"
        sut.password        = "bakeSecure9"
        sut.confirmPassword = "bakeSecure9"
        sut.selectedRole    = .baker

        XCTAssertTrue(sut.validate())
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - Sign Up Tests

    /// Successful sign-up should set createdUser and navigate to Face ID.
    func test_signUp_success_setsCreatedUser() async {
        sut.email           = "new@cakelab.com"
        sut.password        = "password123"
        sut.confirmPassword = "password123"
        sut.selectedRole    = .customer
        mockService.shouldFail = false

        sut.signUp()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(mockService.signUpCalled)
        XCTAssertNotNil(sut.createdUser)
        XCTAssertTrue(sut.navigateToFaceID)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    /// Failed sign-up (e.g. email already exists) should set errorMessage.
    func test_signUp_failure_setsErrorMessage() async {
        sut.email           = "existing@cakelab.com"
        sut.password        = "password123"
        sut.confirmPassword = "password123"
        sut.selectedRole    = .baker
        mockService.shouldFail   = true
        mockService.errorToThrow = AuthError.networkError("Email already in use")

        sut.signUp()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(mockService.signUpCalled)
        XCTAssertNil(sut.createdUser)
        XCTAssertFalse(sut.navigateToFaceID)
        XCTAssertNotNil(sut.errorMessage)
    }

    /// Sign-up with invalid inputs should NOT call the auth service.
    func test_signUp_invalidInputs_doesNotCallService() async {
        sut.email = ""

        sut.signUp()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertFalse(mockService.signUpCalled)
    }

    /// Exactly 6-character password should pass the minimum check.
    func test_validate_exactlyMinPasswordLength_passes() {
        sut.email           = "test@cakelab.com"
        sut.password        = "abc123"
        sut.confirmPassword = "abc123"
        sut.selectedRole    = .customer

        XCTAssertTrue(sut.validate())
    }
}
