import XCTest
@testable import CakeLab_IOS

// MARK: - SignInViewModel Unit Tests
/// Tests input validation and sign-in logic in SignInViewModel.
/// Uses MockAuthService so no Firebase calls are made.
@MainActor
final class SignInViewModelTests: XCTestCase {

    private var sut: SignInViewModel!
    private var mockService: MockAuthService!

    override func setUp() {
        super.setUp()
        mockService = MockAuthService()
        sut = SignInViewModel(authService: mockService)
    }

    override func tearDown() {
        sut = nil
        mockService = nil
        super.tearDown()
    }

    // MARK: - Validation Tests

    /// Empty email should produce an invalidEmail error and return false.
    func test_validate_emptyEmail_returnsFalse() {
        sut.email    = ""
        sut.password = "password123"
        sut.selectedRole = .customer

        let result = sut.validate()

        XCTAssertFalse(result)
        XCTAssertEqual(sut.errorMessage, AuthError.invalidEmail.errorDescription)
    }

    /// A malformed email should fail validation.
    func test_validate_invalidEmail_returnsFalse() {
        sut.email    = "notanemail"
        sut.password = "password123"
        sut.selectedRole = .customer

        let result = sut.validate()

        XCTAssertFalse(result)
        XCTAssertEqual(sut.errorMessage, AuthError.invalidEmail.errorDescription)
    }

    /// Empty password should produce an emptyPassword error.
    func test_validate_emptyPassword_returnsFalse() {
        sut.email    = "test@cakelab.com"
        sut.password = ""
        sut.selectedRole = .customer

        let result = sut.validate()

        XCTAssertFalse(result)
        XCTAssertEqual(sut.errorMessage, AuthError.emptyPassword.errorDescription)
    }

    /// No role selected should produce a roleNotSelected error.
    func test_validate_noRole_returnsFalse() {
        sut.email    = "test@cakelab.com"
        sut.password = "password123"
        sut.selectedRole = nil

        let result = sut.validate()

        XCTAssertFalse(result)
        XCTAssertEqual(sut.errorMessage, AuthError.roleNotSelected.errorDescription)
    }

    /// All valid inputs should pass validation with no error.
    func test_validate_validInputs_returnsTrue() {
        sut.email        = "test@cakelab.com"
        sut.password     = "password123"
        sut.selectedRole = .customer

        let result = sut.validate()

        XCTAssertTrue(result)
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - Sign In Tests

    /// Successful sign-in should set signedInUser and navigateToFaceID.
    func test_signIn_success_setsUser() async {
        sut.email        = "test@cakelab.com"
        sut.password     = "password123"
        sut.selectedRole = .customer
        mockService.shouldFail = false

        sut.signIn()

        // Allow async task to complete
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(mockService.signInCalled)
        XCTAssertNotNil(sut.signedInUser)
        XCTAssertTrue(sut.navigateToFaceID)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    /// Failed sign-in should set errorMessage and not navigate.
    func test_signIn_failure_setsErrorMessage() async {
        sut.email        = "test@cakelab.com"
        sut.password     = "password123"
        sut.selectedRole = .customer
        mockService.shouldFail   = true
        mockService.errorToThrow = AuthError.networkError("Invalid credentials")

        sut.signIn()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(mockService.signInCalled)
        XCTAssertNil(sut.signedInUser)
        XCTAssertFalse(sut.navigateToFaceID)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    /// Sign-in with invalid inputs should NOT call the auth service.
    func test_signIn_invalidInputs_doesNotCallService() async {
        sut.email    = ""
        sut.password = ""

        sut.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertFalse(mockService.signInCalled)
    }

    // MARK: - Password Reset Tests

    /// Valid email triggers sendPasswordReset on the service.
    func test_sendPasswordReset_validEmail_callsService() async {
        sut.email = "test@cakelab.com"
        mockService.shouldFail = false

        sut.sendPasswordReset()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(mockService.resetCalled)
        XCTAssertNil(sut.errorMessage)
    }

    /// Invalid email should not call the service and set error.
    func test_sendPasswordReset_invalidEmail_doesNotCallService() {
        sut.email = "bademail"

        sut.sendPasswordReset()

        XCTAssertFalse(mockService.resetCalled)
        XCTAssertNotNil(sut.errorMessage)
    }

    /// Email with whitespace trimming should still be valid.
    func test_validate_emailWithWhitespace_passesAfterTrim() {
        sut.email        = "  test@cakelab.com  "
        sut.password     = "password123"
        sut.selectedRole = .baker

        let result = sut.validate()

        XCTAssertTrue(result)
    }
}
