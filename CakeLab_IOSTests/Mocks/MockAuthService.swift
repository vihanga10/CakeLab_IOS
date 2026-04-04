import Foundation
import LocalAuthentication
@testable import CakeLab_IOS

// MARK: - Mock Auth Service
/// Injectable mock that simulates Firebase Auth without network calls.
/// Set `shouldFail = true` or `errorToThrow` to test failure paths.
final class MockAuthService: AuthServiceProtocol {

    // MARK: - Control properties
    var shouldFail     = false
    var errorToThrow: Error = AuthError.networkError("Mock network error")
    var mockUser: AppUser  = .mock

    // MARK: - Call tracking (verify ViewModel calls the right methods)
    private(set) var signInCalled    = false
    private(set) var signUpCalled    = false
    private(set) var resetCalled     = false
    private(set) var signOutCalled   = false

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

    func sendPasswordReset(email: String) async throws {
        resetCalled = true
        if shouldFail { throw errorToThrow }
    }

    func signOut() throws {
        signOutCalled = true
        if shouldFail { throw errorToThrow }
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
