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
    private let context = LAContext()
    private let credentialStore = CredentialStore()
    
    init(authService: AuthServiceProtocol = AuthService()) {
        self.authService = authService
        checkFaceIDAvailability()
    }
    
    // MARK: - Check Face ID Availability
    private func checkFaceIDAvailability() {
        var error: NSError?
        faceIDAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        if !faceIDAvailable {
            // Don't show error message immediately - users can still use email/password
            print("⚠️ Face ID not available: \(error?.localizedDescription ?? "Unknown error")")
            print("💡 User can still authenticate using Email & Password")
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
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch user by email from Firestore
            let user = try await authService.fetchUserByEmail(email.trimmingCharacters(in: .whitespaces))
            print("✅ DEBUG: User verified - Email: \(user.email), Role: \(user.role.rawValue)")

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
            print("❌ User verification error: \(error.localizedDescription)")
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
        
        guard faceIDAvailable else {
            errorMessage = "Face ID is not enrolled on this device. Please use 'Login with Email & Password' instead."
            print("⚠️ Face ID not enrolled - redirecting user to email/password login")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔐 DEBUG: Attempting Face ID authentication for \(email)")
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate to sign in to CakeLab"
            )
            
            if success {
                let savedPassword = try credentialStore.password(for: normalizedEmail)
                let signedInUser = try await authService.signIn(email: normalizedEmail, password: savedPassword)
                authenticatedUser = signedInUser

                print("✅ DEBUG: Face ID authentication successful for \(email)")
                print("✅ DEBUG: User role: \(signedInUser.role.rawValue)")
                // Successfully authenticated - the view will handle navigation via binding
                isLoading = false
            } else {
                errorMessage = "Face ID authentication was cancelled"
                isLoading = false
                print("❌ DEBUG: Face ID authentication cancelled")
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            print("❌ DEBUG: Face ID authentication failed - \(error.localizedDescription)")
        }
    }
}
