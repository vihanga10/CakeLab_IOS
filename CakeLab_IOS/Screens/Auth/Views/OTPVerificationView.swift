import SwiftUI


struct OTPVerificationView: View {
    let email: String
    let onVerified: () -> Void

    @StateObject private var vm = OTPVerificationViewModel()
    @State private var otpDigits: [String] = ["", "", "", "", ""]
    @State private var secondsRemaining: Int = 45
    @State private var showResetPassword = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
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

                            Text("VERIFICATION")
                                .font(.urbanistBold(24))
                                .foregroundColor(Color(red: 93/255, green: 55/255, blue: 20/255))
                                .padding(.bottom, 5)
                                .padding(.horizontal, 20)

                            Text("Keep your account safe and secure")
                                .font(.urbanistRegular(13))
                                .foregroundColor(.cakeGrey)
                                .padding(.bottom, 20)
                                .padding(.horizontal, 20)

                            VStack(alignment: .leading, spacing: 0) {
                                Text("Enter the OTP created for \(email)")
                                    .font(.urbanistRegular(13))
                                    .foregroundColor(.cakeGrey)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                            }
                            .padding(.bottom, 28)
                            .padding(.horizontal, 20)

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

                            if let error = vm.errorMessage {
                                Text(error)
                                    .font(.urbanistRegular(12))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else if let successMessage = vm.successMessage {
                                Text(successMessage)
                                    .font(.urbanistRegular(12))
                                    .foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.3))
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if secondsRemaining > 0 {
                                Text("we will resend the code in \(secondsRemaining)s")
                                    .font(.urbanistRegular(12))
                                    .foregroundColor(.cakeGrey)
                                    .padding(.bottom, 3)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Button { resetOTP() } label: {
                                    Text("Resend OTP")
                                        .font(.urbanistSemiBold(13))
                                        .foregroundColor(Color(red: 93/255, green: 55/255, blue: 20/255))
                                }
                                .padding(.bottom, 3)
                                .frame(maxWidth: .infinity)
                            }

                            Spacer().frame(height: 20)

                            Button {
                                verifyOTP()
                            } label: {
                                ZStack {
                                    if vm.isVerifying {
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
                            .disabled(vm.isVerifying || otpCode.isEmpty || otpCode.count != 5)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear { startCountdown() }
        .fullScreenCover(isPresented: $showResetPassword) {
            ResetPasswordView(email: email) {
                onVerified()
                dismiss()
            }
        }
    }



    private var otpCode: String { otpDigits.joined() }

    

    private func handleOTPChange(_ index: Int) {
        if !otpDigits[index].isEmpty && index < 4 { }
    }

    private func verifyOTP() {
        vm.verifyOTP(email: email, otpCode: otpCode) {
            showResetPassword = true
        }
    }

    private func resetOTP() {
        otpDigits = ["", "", "", "", ""]
        secondsRemaining = 45
        vm.errorMessage = nil
        vm.successMessage = nil
        startCountdown()
        vm.resendOTP(email: email)
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

// MARK: - OTP Digit Box 
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
                .foregroundColor(.cakePrimaryText)
                .focused($isFocused)
                .onChange(of: text) { oldVal, newVal in
                    if newVal.count > 1 { text = String(newVal.suffix(1)) }
                    let filtered = newVal.filter { $0.isNumber }
                    if filtered != newVal { text = filtered }
                    onChanged()
                }
        }
        .frame(height: 56)
    }
}

#Preview {
    OTPVerificationView(email: "user@example.com", onVerified: {})
        .presentationDetents([.fraction(0.60)])
}
