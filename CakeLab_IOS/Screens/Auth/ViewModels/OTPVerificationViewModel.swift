import Foundation
import Combine


@MainActor
final class OTPVerificationViewModel: ObservableObject {
    @Published var isVerifying: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let authService = AuthService()

    // Verifies the entered OTP for the given email.
    func verifyOTP(email: String, otpCode: String, onSuccess: @escaping () -> Void) {
        errorMessage = nil
        successMessage = nil
        isVerifying = true

        Task {
            do {
                let isValid = try await authService.verifyOTP(email: email, userOTP: otpCode)

                guard isValid else {
                    errorMessage = "Invalid OTP. Please try again."
                    isVerifying = false
                    return
                }

                successMessage = "OTP verified. Create your new password."
                isVerifying = false
                onSuccess()
            } catch {
                errorMessage = error.localizedDescription
                isVerifying = false
                print("OTP verification failed: \(error)")
            }
        }
    }

    /// Generates and saves a new OTP for resend.
    func resendOTP(email: String) {
        Task {
            do {
                let otp = String(Int.random(in: 10000...99999))
                try await authService.saveOTP(email: email, otp: otp)
                print("OTP resent successfully")
            } catch {
                errorMessage = "Failed to resend OTP. Please try again."
                print("Resend OTP failed: \(error)")
            }
        }
    }
}
