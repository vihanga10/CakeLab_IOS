import Foundation
import Combine
import LocalAuthentication

// MARK: - Biometric Auth ViewModel
@MainActor
final class BiometricAuthViewModel: ObservableObject {
    
    @Published var email: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isUserValid: Bool = false
    @Published var faceIDAvailable: Bool = false
    @Published var authenticatedUser: AppUser?
    
    private let authService: AuthServiceProtocol
    private let credentialStore = CredentialStore()
    
    init(authService: AuthServiceProtocol = AuthService()) {
        self.authService = authService
        checkFaceIDAvailability()
    }
    
    // MARK: - Check Face ID Availability
    func checkFaceIDAvailability() {
        let context = LAContext()
        context.localizedFallbackTitle = ""
        var error: NSError?
        faceIDAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        if !faceIDAvailable {
            // Don't show error message immediately - users can still use email/password
            print("Face ID not available: \(error?.localizedDescription ?? "Unknown error")")
            print("User can still authenticate using Email & Password")
        }
    }
    
    // MARK: - Validate Email Format
    func validateEmail() -> Bool {
        errorMessage = nil
        
        if email.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "Email address is required"
            return false
        }
        
        if !isValidEmailFormat(email) {
            errorMessage = "Please enter a valid email address"
            return false
        }
        
        return true
    }
    
    private func isValidEmailFormat(_ email: String) -> Bool {
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailPattern)
        return predicate.evaluate(with: email)
    }
    
    // MARK: - Check if User Exists in Firebase
    func checkUserExists() async {
        guard validateEmail() else {
            isUserValid = false
            return
        }
        
        authenticatedUser = nil
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch user by email from Firestore
            let user = try await authService.fetchUserByEmail(email.trimmingCharacters(in: .whitespaces))
            print("DEBUG: User verified - Email: \(user.email), Role: \(user.role.rawValue)")

            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard credentialStore.hasPassword(for: normalizedEmail) else {
                errorMessage = "No saved credentials for this email. Sign in once with Email & Password and enable Remember Me."
                isUserValid = false
                isLoading = false
                return
            }

            authenticatedUser = user
            isUserValid = true
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isUserValid = false
            isLoading = false
            print("User verification error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Authenticate with Face ID
    func authenticateWithFaceID() async {
        guard isUserValid else {
            errorMessage = "Please enter a valid email first"
            return
        }
        
        guard authenticatedUser != nil else {
            errorMessage = "User information not found"
            return
        }

        let context = LAContext()
        context.localizedFallbackTitle = ""
        var availabilityError: NSError?
        let canUseBiometrics = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &availabilityError)
        faceIDAvailable = canUseBiometrics

        guard canUseBiometrics else {
            errorMessage = biometricUnavailableMessage(for: availabilityError)
            print("Biometric authentication unavailable: \(availabilityError?.localizedDescription ?? "Unknown error")")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            print("DEBUG: Attempting Face ID authentication for \(email)")
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate to sign in to CakeLab"
            )
            
            if success {
                let savedPassword = try credentialStore.password(for: normalizedEmail)
                let signedInUser = try await authService.signIn(email: normalizedEmail, password: savedPassword)
                authenticatedUser = signedInUser
                AppSessionManager.shared.registerAuthenticatedSession(for: signedInUser)
                WidgetDataSyncManager.shared.refreshFromCurrentSession()

                print("DEBUG: Face ID authentication successful for \(email)")
                print("DEBUG: User role: \(signedInUser.role.rawValue)")
                // Successfully authenticated - the view will handle navigation via binding
                isLoading = false
            } else {
                authenticatedUser = nil
                errorMessage = "Face ID authentication was cancelled"
                isLoading = false
                print("DEBUG: Face ID authentication cancelled")
            }
        } catch {
            isLoading = false
            authenticatedUser = nil
            errorMessage = biometricFailureMessage(for: error)
            print("DEBUG: Face ID authentication failed - \(error.localizedDescription)")
        }
    }

    private func biometricUnavailableMessage(for error: NSError?) -> String {
        guard let error else {
            return "Face ID is not available right now. Please try again or use Login with Email & Password."
        }

        switch LAError.Code(rawValue: error.code) {
        case .biometryNotEnrolled:
            return "Face ID is not enrolled on this device yet. Enroll Face ID in Settings and try again."
        case .biometryNotAvailable:
            return "Face ID is not available on this device. Please use Login with Email & Password."
        case .passcodeNotSet:
            return "Set a device passcode first, then enable Face ID and try again."
        case .biometryLockout:
            return "Face ID is temporarily locked. Unlock your device and try again."
        default:
            return error.localizedDescription
        }
    }

    private func biometricFailureMessage(for error: Error) -> String {
        let nsError = error as NSError
        guard let code = LAError.Code(rawValue: nsError.code) else {
            return error.localizedDescription
        }

        switch code {
        case .userCancel, .systemCancel, .appCancel:
            return "Face ID authentication was cancelled"
        case .biometryLockout:
            return "Face ID is temporarily locked. Unlock your device and try again."
        case .biometryNotEnrolled:
            return "Face ID is not enrolled on this device yet. Enroll Face ID in Settings and try again."
        default:
            return error.localizedDescription
        }
    }

    func resetSessionState() {
        authenticatedUser = nil
        isUserValid = false
        isLoading = false
        errorMessage = nil
    }
}
