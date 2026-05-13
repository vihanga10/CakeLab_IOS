import Foundation
import AuthenticationServices //apple
import LocalAuthentication
import UIKit
@testable import CakeLab_IOS

// MARK: - Mock Auth Service
/// Injectable mock that simulates Firebase Auth without network calls.
/// Set `shouldFail = true` or `errorToThrow` to test failure paths.
final class MockAuthService: AuthServiceProtocol {

    // MARK: - Control properties
    var shouldFail     = false
    var errorToThrow: Error = AuthError.networkError("Mock network error")
    var mockUser: AppUser  = .mock
    var mockOTPValid = true

    // MARK: - Call tracking (verify ViewModel calls the right methods)
    private(set) var signInCalled         = false
    private(set) var signUpCalled         = false
    private(set) var googleSignInCalled   = false
    private(set) var googleSignUpCalled   = false
    private(set) var appleSignInCalled    = false
    private(set) var appleSignUpCalled    = false
    private(set) var resetCalled          = false
    private(set) var signOutCalled        = false
    private(set) var saveOTPCalled        = false
    private(set) var verifyOTPCalled      = false
    private(set) var fetchUserByCalled    = false

    var currentUserID: String? { mockUser.id }

    // MARK: - Protocol conformance
    func signIn(email: String, password: String) async throws -> AppUser {
        signInCalled = true
        if shouldFail { throw errorToThrow }
        return mockUser
    }

    func signUp(email: String, password: String, role: UserRole) async throws -> AppUser {
        signUpCalled = true
        if shouldFail { throw errorToThrow }
        mockUser = AppUser(id: "new-uid", email: email, name: "", role: role,
                           avatarURL: nil, fcmToken: nil, createdAt: Date())
        return mockUser
    }

    func signUpWithGoogle(role: UserRole, presentingViewController: UIViewController) async throws -> AppUser {
        googleSignUpCalled = true
        if shouldFail { throw errorToThrow }
        mockUser = AppUser(id: "google-new-uid", email: "google@cakelab.com", name: "Google User", role: role,
                           avatarURL: nil, fcmToken: nil, createdAt: Date())
        return mockUser
    }

    func signInWithGoogle(presentingViewController: UIViewController) async throws -> AppUser {
        googleSignInCalled = true
        if shouldFail { throw errorToThrow }
        return mockUser
    }

    func signUpWithApple(role: UserRole, presentationAnchor: ASPresentationAnchor) async throws -> AppUser {
        appleSignUpCalled = true
        if shouldFail { throw errorToThrow }
        mockUser = AppUser(id: "apple-new-uid", email: "apple@cakelab.com", name: "Apple User", role: role,
                           avatarURL: nil, fcmToken: nil, createdAt: Date())
        return mockUser
    }

    func signInWithApple(presentationAnchor: ASPresentationAnchor) async throws -> AppUser {
        appleSignInCalled = true
        if shouldFail { throw errorToThrow }
        return mockUser
    }

    func sendPasswordReset(email: String) async throws {
        resetCalled = true
        if shouldFail { throw errorToThrow }
    }

    func saveOTP(email: String, otp: String) async throws {
        saveOTPCalled = true
        if shouldFail { throw errorToThrow }
    }

    func verifyOTP(email: String, userOTP: String) async throws -> Bool {
        verifyOTPCalled = true
        if shouldFail { throw errorToThrow }
        return mockOTPValid
    }

    func validatePasswordResetEligibility(email: String) async throws -> AppUser {
        fetchUserByCalled = true
        if shouldFail { throw errorToThrow }
        return mockUser
    }

    func fetchUserByEmail(_ email: String) async throws -> AppUser {
        fetchUserByCalled = true
        if shouldFail { throw errorToThrow }
        return mockUser
    }

    func signOut() throws {
        signOutCalled = true
        if shouldFail { throw errorToThrow }
    }

    func reauthenticate(email: String, password: String) async throws {
        if shouldFail { throw errorToThrow }
        // Mock implementation - just track the call
    }

    func updatePassword(newPassword: String, currentEmail: String, currentPassword: String) async throws {
        if shouldFail { throw errorToThrow }
        // Mock implementation - just track the call
    }

}

// MARK: - Mock Biometric Context
/// Simulates LAContext without requiring a real device.
final class MockBiometricContext: BiometricManager.LAContextProtocol {
    var canEvaluate = true
    var shouldSucceed = true
    var errorToThrow: Error?

    func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool {
        return canEvaluate
    }

    func evaluatePolicy(_ policy: LAPolicy, localizedReason: String) async throws -> Bool {
        if let err = errorToThrow { throw err }
        return shouldSucceed
    }
}
