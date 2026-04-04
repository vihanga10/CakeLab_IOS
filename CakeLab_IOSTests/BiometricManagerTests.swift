import XCTest
@testable import CakeLab_IOS

// MARK: - BiometricManager Unit Tests
/// Tests Face ID / Touch ID authentication paths using a mock LAContext.
final class BiometricManagerTests: XCTestCase {

    private var mockContext: MockBiometricContext!
    private var sut: BiometricManager!

    override func setUp() {
        super.setUp()
        mockContext = MockBiometricContext()
        sut = BiometricManager(context: mockContext)
    }

    override func tearDown() {
        sut = nil
        mockContext = nil
        super.tearDown()
    }

    // MARK: - Availability Tests

    /// When mock context returns true, biometry should be available.
    func test_isBiometryAvailable_whenContextReturnsTrue_isTrue() {
        mockContext.canEvaluate = true
        XCTAssertTrue(sut.isBiometryAvailable)
    }

    /// When mock context returns false (e.g., no Face ID enrolled), biometry is unavailable.
    func test_isBiometryAvailable_whenContextReturnsFalse_isFalse() {
        mockContext.canEvaluate = false
        XCTAssertFalse(sut.isBiometryAvailable)
    }

    // MARK: - Authentication Tests

    /// Successful biometric evaluation should return true.
    func test_authenticate_success_returnsTrue() async throws {
        mockContext.shouldSucceed = true

        let result = try await sut.authenticate(reason: "Test auth")

        XCTAssertTrue(result)
    }

    /// Failed biometric evaluation should return false.
    func test_authenticate_failure_returnsFalse() async throws {
        mockContext.shouldSucceed = false

        let result = try await sut.authenticate(reason: "Test auth")

        XCTAssertFalse(result)
    }

    /// When the context throws an error, authenticate should propagate it.
    func test_authenticate_throwsError_propagatesError() async {
        let expectedError = NSError(domain: "LAError", code: -1, userInfo: nil)
        mockContext.errorToThrow = expectedError

        do {
            _ = try await sut.authenticate(reason: "Test auth")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual((error as NSError).code, expectedError.code)
        }
    }
}
