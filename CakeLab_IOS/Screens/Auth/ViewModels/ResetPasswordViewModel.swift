import Foundation
import Combine


@MainActor
final class ResetPasswordViewModel: ObservableObject {
    @Published var currentPassword   = ""
    @Published var newPassword      = ""
    @Published var confirmPassword  = ""
    @Published var isLoading        = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var didReset         = false
    @Published var email: String = ""

    private let authService = AuthService()

    // Validates all three password fields, then calls `AuthService.updatePassword`.
    func changePassword() {
        errorMessage = nil
        successMessage = nil
        guard !currentPassword.isEmpty else { errorMessage = "Please enter your current password."; return }
        guard !newPassword.isEmpty else { errorMessage = "Please enter a new password."; return }
        guard newPassword.count >= 6 else { errorMessage = "Password must be at least 6 characters."; return }
        guard newPassword == confirmPassword else { errorMessage = "Passwords do not match."; return }

        isLoading = true

        Task {
            do {
                print(" DEBUG: Changing password for email: \(email)")
                try await authService.updatePassword(
                    newPassword: newPassword,
                    currentEmail: email,
                    currentPassword: currentPassword
                )
                print(" DEBUG: Password updated successfully")
                successMessage = "Password changed. Please sign in again."
                didReset = true
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                print(" ERROR: Password update failed - \(error.localizedDescription)")
            }
        }
    }
}
