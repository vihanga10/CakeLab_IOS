import SwiftUI
import Combine

// MARK: - OTP Verification View (Bottom Sheet)
struct OTPVerificationView: View {
    let email: String
    let onVerified: () -> Void
    
    @State private var otpDigits: [String] = ["", "", "", "", ""]
    @State private var secondsRemaining: Int = 45
    @State private var isVerifying: Bool = false
    @State private var errorMessage: String?
    @State private var navigateToReset: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    private let authService = AuthService()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // ── Header with Close Button ──────────────────────────────
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(red: 93/255, green: 55/255, blue: 20/255))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Spacer().frame(height: 24)
                            
                            // ── Title ─────────────────────────────────────────
                            Text("VERIFICATION")
                                .font(.urbanistBold(24))
                                .foregroundColor(Color(red: 93/255, green: 55/255, blue: 20/255))
                                .padding(.bottom, 5)
                                .padding(.horizontal, 20)
                            
                            // ── Subtitle ──────────────────────────────────────
                            Text("Keep your account safe and secure")
                                .font(.urbanistRegular(13))
                                .foregroundColor(.cakeGrey)
                                .padding(.bottom, 20)
                                .padding(.horizontal, 20)
                            
                            // ── Message ───────────────────────────────────────
                            VStack(alignment: .leading, spacing: 0) {
                                Text("We've sent an OTP code to your email, \(email)")
                                    .font(.urbanistRegular(13))
                                    .foregroundColor(.cakeGrey)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                            }
                            .padding(.bottom, 28)
                            .padding(.horizontal, 20)
                            
                            // ── OTP Input Boxes ───────────────────────────────────
                            HStack(spacing: 10) {
                                ForEach(0..<5, id: \.self) { index in
                                    OTPDigitBox(
                                        text: $otpDigits[index],
                                        index: index,
                                        onChanged: { handleOTPChange(index) }
                                    )
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                            
                            // ── Error message ─────────────────────────────────────
                            if let error = errorMessage {
                                Text(error)
                                    .font(.urbanistRegular(12))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // ── Resend OTP Timer ──────────────────────────────────
                            if secondsRemaining > 0 {
                                Text("we will resend the code in \(secondsRemaining)s")
                                    .font(.urbanistRegular(12))
                                    .foregroundColor(.cakeGrey)
                                    .padding(.bottom, 3)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Button {
                                    resetOTP()
                                } label: {
                                    Text("Resend OTP")
                                        .font(.urbanistSemiBold(13))
                                        .foregroundColor(Color(red: 93/255, green: 55/255, blue: 20/255))
                                }
                                .padding(.bottom, 3)
                                .frame(maxWidth: .infinity)
                            }

                            Spacer().frame(height: 20)

                            // ── Verify button ─────────────────────────────────────────
                            NavigationLink(destination: ResetPasswordView(email: email), isActive: $navigateToReset) {
                                Button {
                                    verifyOTP()
                                } label: {
                                    ZStack {
                                        if isVerifying {
                                            ProgressView().tint(.white)
                                        } else {
                                            Text("Verify")
                                                .font(.urbanistSemiBold(17))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(Color.cakeBrown)
                                    .clipShape(Capsule())
                                }
                                .disabled(isVerifying || otpCode.isEmpty || otpCode.count != 5)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            startCountdown()
        }
    }
    
    // MARK: - Helper Properties
    private var otpCode: String {
        otpDigits.joined()
    }
    
    // MARK: - Helper Methods
    private func handleOTPChange(_ index: Int) {
        // Auto-focus to next field when digit is entered
        if !otpDigits[index].isEmpty && index < 4 {
            // Move to next field (handled by the input field itself)
        }
    }
    
    private func verifyOTP() {
        errorMessage = nil
        isVerifying = true
        
        Task {
            do {
                print("🔐 Verifying OTP: \(otpCode)")
                let isValid = try await authService.verifyOTP(email: email, userOTP: otpCode)
                
                if isValid {
                    print("OTP verified successfully")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        navigateToReset = true
                    }
                } else {
                    errorMessage = "Invalid OTP. Please try again."
                    isVerifying = false
                }
            } catch {
                errorMessage = error.localizedDescription
                isVerifying = false
                print("OTP verification failed: \(error)")
            }
        }
    }
    
    private func resetOTP() {
        otpDigits = ["", "", "", "", ""]
        secondsRemaining = 45
        errorMessage = nil
        startCountdown()
        
        Task {
            do {
                print("Resending OTP to \(email)")
                let otp = String(Int.random(in: 10000...99999))
                try await authService.saveOTP(email: email, otp: otp)
                print("OTP resent successfully")
            } catch {
                errorMessage = "Failed to resend OTP. Please try again."
                print("Resend OTP failed: \(error)")
            }
        }
    }
    
    private func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            } else {
                timer.invalidate()
            }
        }
    }
}

// MARK: - OTP Digit Box Component
struct OTPDigitBox: View {
    @Binding var text: String
    let index: Int
    let onChanged: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 234/255, green: 226/255, blue: 218/255))
                .stroke(isFocused ? Color(red: 93/255, green: 55/255, blue: 20/255) : Color.clear, lineWidth: 2)
            
            TextField("", text: $text)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.urbanistBold(24))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                .focused($isFocused)
                .onChange(of: text) { oldVal, newVal in
                    // Only allow single digit
                    if newVal.count > 1 {
                        text = String(newVal.suffix(1))
                    }
                    
                    // Filter to digits only
                    let filtered = newVal.filter { $0.isNumber }
                    if filtered != newVal {
                        text = filtered
                    }
                    
                    onChanged()
                }
        }
        .frame(height: 56)
    }
}

// MARK: - Preview
#Preview {
    OTPVerificationView(email: "user@example.com", onVerified: {})
        .presentationDetents([.fraction(0.60)])
}
