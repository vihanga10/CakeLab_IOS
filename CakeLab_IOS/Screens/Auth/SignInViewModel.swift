import Foundation
import AuthenticationServices //apple
import Combine
import UIKit

// MARK: - Sign In ViewModel
@MainActor
final class SignInViewModel: ObservableObject {

    // MARK: - Inputs
    @Published var email        = ""
    @Published var password     = ""
    @Published var selectedRole: UserRole? = nil
    @Published var rememberMe   = false

    // MARK: - Outputs
    @Published var isLoading    = false
    @Published var errorMessage: String?
    @Published var signedInUser: AppUser?
    @Published var navigateToFaceID = false

    private let authService: AuthServiceProtocol
    private let credentialStore = CredentialStore()

    init(authService: AuthServiceProtocol = AuthService()) {
        self.authService = authService
    }

    // MARK: - Sign In
    func signIn() {
        guard validate() else { return }
        Task {
            signedInUser = nil
            navigateToFaceID = false
            isLoading = true
            errorMessage = nil
            do {
                let user = try await authService.signIn(email: email.trimmingCharacters(in: .whitespaces),
                                                        password: password)
                
                // Validate that selected role matches database role
                guard let selectedRole = selectedRole else {
                    errorMessage = AuthError.roleNotSelected.errorDescription
                    isLoading = false
                    return
                }
                
                if user.role != selectedRole {
                    print("ERROR: Role mismatch - Selected: \(selectedRole.rawValue), Database: \(user.role.rawValue)")
                    AppSessionManager.shared.discardAuthenticatedSession()
                    errorMessage = "Role mismatch. Please select '\(user.role.rawValue.capitalized)' to continue."
                    isLoading = false
                    return
                }

                let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if rememberMe {
                    do {
                        try credentialStore.save(email: normalizedEmail, password: password)
                    } catch {
                        print("WARNING: Failed to save credentials for Face ID: \(error.localizedDescription)")
                    }
                } else {
                    credentialStore.delete(email: normalizedEmail)
                }
                
                print("DEBUG: Role validation passed - User is: \(user.role.rawValue)")
                signedInUser    = user
                AppSessionManager.shared.registerAuthenticatedSession(for: user)
                navigateToFaceID = true
                WidgetDataSyncManager.shared.refreshFromCurrentSession()
            } catch {
                signedInUser = nil
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func signInWithGoogle(presentingViewController: UIViewController) {
        guard let selectedRole else {
            errorMessage = AuthError.roleNotSelected.errorDescription
            return
        }

        Task {
            signedInUser = nil
            navigateToFaceID = false
            isLoading = true
            errorMessage = nil
            do {
                let user = try await authService.signInWithGoogle(
                    presentingViewController: presentingViewController
                )

                if user.role != selectedRole {
                    print("ERROR: Google role mismatch - Selected: \(selectedRole.rawValue), Database: \(user.role.rawValue)")
                    AppSessionManager.shared.discardAuthenticatedSession()
                    errorMessage = "Role mismatch. Please select '\(user.role.rawValue.capitalized)' to continue."
                    isLoading = false
                    return
                }

                signedInUser = user
                AppSessionManager.shared.registerAuthenticatedSession(for: user)
                navigateToFaceID = true
                WidgetDataSyncManager.shared.refreshFromCurrentSession()
            } catch {
                signedInUser = nil
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func signInWithApple(presentationAnchor: ASPresentationAnchor) { //apple
        guard let selectedRole else {
            errorMessage = AuthError.roleNotSelected.errorDescription
            return
        }

        Task {
            signedInUser = nil
            navigateToFaceID = false
            isLoading = true
            errorMessage = nil
            do {
                let user = try await authService.signInWithApple(presentationAnchor: presentationAnchor)

                if user.role != selectedRole {
                    print("ERROR: Apple role mismatch - Selected: \(selectedRole.rawValue), Database: \(user.role.rawValue)")
                    AppSessionManager.shared.discardAuthenticatedSession()
                    errorMessage = "Role mismatch. Please select '\(user.role.rawValue.capitalized)' to continue."
                    isLoading = false
                    return
                }

                signedInUser = user
                AppSessionManager.shared.registerAuthenticatedSession(for: user)
                navigateToFaceID = true
                WidgetDataSyncManager.shared.refreshFromCurrentSession()
            } catch {
                signedInUser = nil
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - Input Validation
    func validate() -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)

        if trimmedEmail.isEmpty || !isValidEmail(trimmedEmail) {
            errorMessage = AuthError.invalidEmail.errorDescription
            return false
        }
        if password.isEmpty {
            errorMessage = AuthError.emptyPassword.errorDescription
            return false
        }
        if selectedRole == nil {
            errorMessage = AuthError.roleNotSelected.errorDescription
            return false
        }
        errorMessage = nil
        return true
    }

    // MARK: - Forgot Password
    func sendPasswordReset() {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, isValidEmail(trimmed) else {
            errorMessage = AuthError.invalidEmail.errorDescription
            return
        }
        Task {
            isLoading = true
            do {
                try await authService.sendPasswordReset(email: trimmed)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - Helpers
    private func isValidEmail(_ email: String) -> Bool {
        let regex = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: regex, options: .regularExpression) != nil
    }

    func resetSessionState() {
        signedInUser = nil
        navigateToFaceID = false
        isLoading = false
        errorMessage = nil
    }
}
