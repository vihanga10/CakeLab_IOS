import LocalAuthentication
import Foundation

// MARK: - Biometric Manager
/// Wraps LocalAuthentication to provide Face ID / Touch ID authentication.
/// Uses a protocol-based context so it can be mocked in unit tests.
final class BiometricManager {

    // MARK: - Protocol for testability
    protocol LAContextProtocol {
        func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool
        func evaluatePolicy(_ policy: LAPolicy, localizedReason: String) async throws -> Bool
    }

    // MARK: - Biometry availability
    enum BiometryType {
        case faceID, touchID, none
    }

    private let context: LAContextProtocol

    init(context: LAContextProtocol = LAContext()) {
        self.context = context
    }

    /// Returns the type of biometry available on this device.
    var biometryType: BiometryType {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch ctx.biometryType {
        case .faceID:  return .faceID
        case .touchID: return .touchID
        default:       return .none
        }
    }

    /// Returns true if Face ID or Touch ID is available and enrolled.
    var isBiometryAvailable: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Triggers the Face ID / Touch ID prompt.
    /// - Parameter reason: Message shown to the user in the system prompt.
    /// - Returns: `true` if authentication succeeded.
    func authenticate(reason: String = "Sign in to CakeLab") async throws -> Bool {
        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
    }
}

// MARK: - LAContext conformance extension
extension LAContext: BiometricManager.LAContextProtocol {
    func evaluatePolicy(_ policy: LAPolicy, localizedReason: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            evaluatePolicy(policy, localizedReason: localizedReason) { success, error in
                if let error { continuation.resume(throwing: error) }
                else         { continuation.resume(returning: success) }
            }
        }
    }
}
