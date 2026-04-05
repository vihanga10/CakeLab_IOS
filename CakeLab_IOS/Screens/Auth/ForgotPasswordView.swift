import SwiftUI
import Combine

// MARK: - Forgot Password View
struct ForgotPasswordView: View {

    @StateObject private var vm = ForgotPasswordViewModel()
    @State private var showOTPSheet = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // ── Back chevron ─────────────────────────────────
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.cakeBrown)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    
                    ScrollView {
                        VStack(alignment: .center, spacing: 0) {
                            
                            // ── Illustration Box (350 x 355) ──────────────────
                            ZStack {
                                
                                    
                                
                                Image("password")
                                    .resizable()
                                    .scaledToFit()
                                    .padding(20)
                            }
                            .frame(width: 350, height: 355)
                            .padding(.bottom, 32)
                            
                            // ── Heading ───────────────────────────────────────
                            VStack(alignment: .leading, spacing: 4) {
                                Text("FORGOT PASSWORD")
                                    .font(.urbanistBold(24))
                                    .foregroundColor(.cakeBrown)
                                
                                Text("Keep your account safe and secure")
                                    .font(.urbanistRegular(13))
                                    .foregroundColor(.cakeGrey)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 28)
                            .padding(.bottom, 28)
                            
                            // ── Email field ───────────────────────────────────
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 2) {
                                    Text("Email Address")
                                        .font(.urbanistSemiBold(14))
                                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                    Text("*")
                                        .font(.urbanistBold(14))
                                        .foregroundColor(.red)
                                }
                                
                                AuthTextField(
                                    placeholder: "you@example.com",
                                    text: $vm.email,
                                    keyboardType: .emailAddress
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 28)
                            .padding(.bottom, 12)
                            
                            // ── Error / Success message ───────────────────────
                            HStack {
                                if let err = vm.errorMessage {
                                    Text(err)
                                        .font(.urbanistRegular(12))
                                        .foregroundColor(.red)
                                } else if vm.otpSent {
                                    Text("OTP sent! Check your email.")
                                        .font(.urbanistRegular(12))
                                        .foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.3))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 28)
                            .padding(.bottom, 24)
                            
                            // ── Hint text (Centered) ──────────────────────────
                            Text("Enter your email address and click 'Send OTP'. You will receive a one-time password (OTP) in your email to reset your password.")
                                .font(.urbanistRegular(12))
                                .foregroundColor(.cakeGrey)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .padding(.horizontal, 28)
                                .padding(.bottom, 24)
                            
                            // ── Send OTP button ──────────────────────────────
                            Button {
                                vm.sendOTP()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    if vm.otpSent && vm.errorMessage == nil {
                                        showOTPSheet = true
                                    }
                                }
                            } label: {
                                ZStack {
                                    if vm.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Send OTP")
                                            .font(.urbanistSemiBold(17))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.cakeBrown)
                                .clipShape(Capsule())
                            }
                            .disabled(vm.isLoading)
                            .padding(.horizontal, 28)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showOTPSheet) {
                OTPVerificationView(email: vm.email, onVerified: {
                    dismiss()
                })
                .presentationDetents([.fraction(0.49)])
                .presentationCornerRadius(32)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack { ForgotPasswordView() }
}
