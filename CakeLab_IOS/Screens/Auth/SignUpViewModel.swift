import Foundation
import Combine

// MARK: - Sign Up ViewModel
@MainActor
final class SignUpViewModel: ObservableObject {

    // MARK: - Inputs
    @Published var email           = ""
    @Published var password        = ""
    @Published var confirmPassword = ""
    @Published var selectedRole: UserRole? = nil

    // MARK: - Outputs
    @Published var isLoading    = false
    @Published var errorMessage: String?
    @Published var createdUser: AppUser?
    @Published var navigateToFaceID = false

    private let authService: AuthServiceProtocol

    init(authService: AuthServiceProtocol = AuthService()) {
        self.authService = authService
    }

    // MARK: - Sign Up
    func signUp() {
        guard validate() else { return }
        Task {
            isLoading = true
            errorMessage = nil
            do {
                let user = try await authService.signUp(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    role: selectedRole!
                )
                createdUser     = user
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
        if password.count < 6 {
            errorMessage = AuthError.passwordTooShort.errorDescription
            return false
        }
        if password != confirmPassword {
            errorMessage = AuthError.passwordMismatch.errorDescription
            return false
        }
        if selectedRole == nil {
            errorMessage = AuthError.roleNotSelected.errorDescription
            return false
        }
        errorMessage = nil
        return true
    }

    // MARK: - Helpers
    private func isValidEmail(_ email: String) -> Bool {
        let regex = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: regex, options: .regularExpression) != nil
    }
}
