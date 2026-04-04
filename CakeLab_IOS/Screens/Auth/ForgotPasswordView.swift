import SwiftUI
import Combine

// MARK: - Forgot Password View
struct ForgotPasswordView: View {

    @StateObject private var vm = ForgotPasswordViewModel()
    @State private var showOTPSheet = false
    @Environment(\.dismiss) private var dismiss

    private let bgImage    = "language"
    private let cardHeight: CGFloat = 360

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {

                    // ── Background photo ─────────────────────────────────
                    Image(bgImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()

                    // ── Gradient fade ────────────────────────────────────
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.2), .white],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: cardHeight + 80)
                    .frame(maxWidth: .infinity)

                    // ── White card ───────────────────────────────────────
                    VStack(spacing: 0) {
                        cardContent
                            .frame(maxWidth: .infinity)
                            .frame(height: cardHeight)
                            .background(Color.white)
                            .clipShape(TopRoundedRectangle2(cornerRadius: 40))

                        Color.white.frame(height: geo.safeAreaInsets.bottom)
                    }

                    // ── Back chevron ─────────────────────────────────────
                    VStack {
                        HStack {
                            Button { dismiss() } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, geo.safeAreaInsets.top + 20)
                        Spacer()
                    }
                }
                .ignoresSafeArea()
            }
            .ignoresSafeArea()
            .navigationBarHidden(true)
            .sheet(isPresented: $showOTPSheet) {
                OTPVerificationView(email: vm.email, onVerified: {
                    dismiss()
                })
                .presentationDetents([.fraction(0.60)])
                .presentationCornerRadius(32)
            }
        }
    }

    // MARK: - Card content
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {

            Spacer().frame(height: 28)

            // ── Heading ───────────────────────────────────────────────
            Text("FORGOT PASSWORD ?")
                .font(.urbanistBold(22))
                .foregroundColor(.cakeBrown)

            Spacer().frame(height: 2)

            Text("Keep your account safe and secure")
                .font(.urbanistRegular(13))
                .foregroundColor(.cakeGrey)

            Spacer().frame(height: 24)

            // ── Email field ───────────────────────────────────────────
            HStack(spacing: 2) {
                Text("Email Address")
                    .font(.urbanistSemiBold(14))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                Text("*")
                    .font(.urbanistBold(14))
                    .foregroundColor(.red)
            }
            .padding(.bottom, 8)

            AuthTextField(
                placeholder: "you@example.com",
                text: $vm.email,
                keyboardType: .emailAddress
            )

            // ── Error / Success message ───────────────────────────────
            if let err = vm.errorMessage {
                Text(err)
                    .font(.urbanistRegular(12))
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }

            if vm.otpSent {
                Text("OTP sent! Check your email.")
                    .font(.urbanistRegular(12))
                    .foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.3))
                    .padding(.top, 8)
            }

            Spacer()

            // ── Hint text ────────────────────────────────────────────
            Text("Enter your email address and click 'Send OTP'. You will receive a one-time password (OTP) in your email to reset your password.")
                .font(.urbanistRegular(12))
                .foregroundColor(.cakeGrey)
                .lineLimit(4)
                .padding(.bottom, 16)

            // ── Send OTP button ──────────────────────────────────────
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
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 28)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack { ForgotPasswordView() }
}
