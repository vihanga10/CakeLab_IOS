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
    @Environment(\.dismiss) private var dismiss
    
    private let authService = AuthService()
    
    var body: some View {
        VStack(spacing: 0) {
            // ── Header ────────────────────────────────────────────────
            HStack {
                Text("VERIFICATION")
                    .font(.urbanistBold(18))
                    .foregroundColor(.cakeBrown)
                    .padding(.top, 4)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.cakeBrown)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // ── Message ───────────────────────────────────────────────
            VStack(spacing: 4) {
                Text("Enter the OTP sent to")
                    .font(.urbanistRegular(13))
                    .foregroundColor(.cakeGrey)
                
                Text(email)
                    .font(.urbanistSemiBold(13))
                    .foregroundColor(.cakeBrown)
            }
            .padding(.bottom, 24)
            
            // ── OTP Input Boxes ───────────────────────────────────────
            HStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { index in
                    OTPDigitBox(
                        text: $otpDigits[index],
                        index: index,
                        onChanged: { handleOTPChange(index) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            
            // ── Error message ─────────────────────────────────────────
            if let error = errorMessage {
                Text(error)
                    .font(.urbanistRegular(12))
                    .foregroundColor(.red)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
            
            // ── Resend OTP Timer ──────────────────────────────────────
            if secondsRemaining > 0 {
                HStack(spacing: 4) {
                    Text("We will resend the code in")
                        .font(.urbanistRegular(12))
                        .foregroundColor(.cakeGrey)
                    Text("\(secondsRemaining)s")
                        .font(.urbanistSemiBold(12))
                        .foregroundColor(.cakeBrown)
                }
                .padding(.bottom, 24)
            } else {
                Button {
                    resetOTP()
                } label: {
                    Text("Resend OTP")
                        .font(.urbanistSemiBold(13))
                        .foregroundColor(.cakeBrown)
                }
                .padding(.bottom, 24)
            }
            
            Spacer()
            
            // ── Verify button ─────────────────────────────────────────
            Button {
                verifyOTP()
            } label: {
                ZStack {
                    if isVerifying {
                        ProgressView().tint(.white)
                    } else {
                        Text("Verify")
                            .font(.urbanistSemiBold(16))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.cakeBrown)
                .clipShape(Capsule())
            }
            .disabled(isVerifying || otpCode.isEmpty || otpCode.count != 5)
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
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
                    print("✅ OTP verified successfully")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onVerified()
                        dismiss()
                    }
                } else {
                    errorMessage = "Invalid OTP. Please try again."
                    isVerifying = false
                }
            } catch {
                errorMessage = error.localizedDescription
                isVerifying = false
                print("❌ OTP verification failed: \(error)")
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
                print("🔐 Resending OTP to \(email)")
                let otp = String(Int.random(in: 10000...99999))
                try await authService.saveOTP(email: email, otp: otp)
                print("✅ OTP resent successfully")
            } catch {
                errorMessage = "Failed to resend OTP. Please try again."
                print("❌ Resend OTP failed: \(error)")
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
        VStack {
            TextField("", text: $text)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.urbanistBold(20))
                .foregroundColor(.cakeBrown)
                .frame(height: 50)
                .background(Color(red: 0.98, green: 0.95, blue: 0.90))  // Light beige
                .cornerRadius(8)
                .border(isFocused ? Color.cakeBrown : Color.clear, width: 2)
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
                    
                    // Auto-advance to next field
                    if !text.isEmpty && index < 4 {
                        // Signal to move focus (parent handles this)
                    }
                }
        }
    }
}

// MARK: - Preview
#Preview {
    OTPVerificationView(email: "user@example.com", onVerified: {})
        .presentationDetents([.fraction(0.60)])
}
