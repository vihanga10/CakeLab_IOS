import Foundation
import Combine

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

    init(authService: AuthServiceProtocol = AuthService()) {
        self.authService = authService
    }

    // MARK: - Sign In
    func signIn() {
        guard validate() else { return }
        Task {
            isLoading = true
            errorMessage = nil
            do {
                let user = try await authService.signIn(email: email.trimmingCharacters(in: .whitespaces),
                                                        password: password)
                signedInUser    = user
                navigateToFaceID = true
            } catch {
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
}
