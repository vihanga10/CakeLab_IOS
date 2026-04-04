import Foundation
import Combine

// MARK: - Forgot Password ViewModel
@MainActor
final class ForgotPasswordViewModel: ObservableObject {
    
    @Published var email: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var otpSent: Bool = false
    @Published var generatedOTP: String = ""  // 5-digit OTP
    
    private let authService: AuthServiceProtocol
    
    init(authService: AuthServiceProtocol = AuthService()) {
        self.authService = authService
    }
    
    // MARK: - Generate and Send OTP
    func sendOTP() {
        guard validateEmail() else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                print("🔐 DEBUG: Generating OTP for \(email)")
                
                // Generate 5-digit OTP
                let otp = String(Int.random(in: 10000...99999))
                self.generatedOTP = otp
                
                print("✅ DEBUG: Generated OTP: \(otp)")
                
                // Save OTP to database
                try await authService.saveOTP(email: email, otp: otp)
                
                print("✅ DEBUG: OTP saved to Firebase")
                
                otpSent = true
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                print("❌ ERROR: Failed to send OTP - \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Verify OTP
    func verifyOTP(_ userOTP: String) async -> Bool {
        do {
            print("🔐 DEBUG: Verifying OTP for \(email)")
            let isValid = try await authService.verifyOTP(email: email, userOTP: userOTP)
            
            if isValid {
                print("✅ DEBUG: OTP verification successful")
            } else {
                print("❌ DEBUG: OTP verification failed - invalid code")
            }
            
            return isValid
        } catch {
            errorMessage = error.localizedDescription
            print("❌ ERROR: OTP verification error - \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Validation
    private func validateEmail() -> Bool {
        errorMessage = nil
        
        if email.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "Email address is required"
            return false
        }
        
        if !isValidEmail(email) {
            errorMessage = "Please enter a valid email address"
            return false
        }
        
        return true
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailPattern)
        return predicate.evaluate(with: email)
    }
}
