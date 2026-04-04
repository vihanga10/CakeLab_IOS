import SwiftUI

// MARK: - Sign Up View
struct SignUpView: View {

    @StateObject private var vm = SignUpViewModel()
    @State private var showPassword        = false
    @State private var showConfirmPassword = false
    @State private var showFaceID          = false
    @Environment(\.dismiss) private var dismiss

    private let bgImage    = "language"
    private let cardHeight: CGFloat = 610

    var body: some View {
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
                    scrollContent
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
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, geo.safeAreaInsets.top + 4)
                    Spacer()
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showFaceID) {
            if let user = vm.createdUser {
                BiometricAuthView(user: user)
            }
        }
        .onChange(of: vm.navigateToFaceID) { val in
            if val { showFaceID = true }
        }
    }

    // MARK: - Scrollable card content
    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                Spacer().frame(height: 28)

                // ── Heading ───────────────────────────────────────────────
                Text("CREATE YOUR ACCOUNT")
                    .font(.urbanistBold(24))
                    .foregroundColor(.cakeBrown)

                Spacer().frame(height: 4)

                Text("Start your cake journey today")
                    .font(.urbanistRegular(13))
                    .foregroundColor(.cakeGrey)

                Spacer().frame(height: 28)

                // ── Email ─────────────────────────────────────────────────
                requiredLabel("Email Address")
                AuthTextField(placeholder: "you@example.com",
                              text: $vm.email,
                              keyboardType: .emailAddress)

                Spacer().frame(height: 16)

                // ── Password ──────────────────────────────────────────────
                requiredLabel("Password")
                AuthTextField(placeholder: "••••••••••",
                              text: $vm.password,
                              isSecure: !showPassword,
                              trailingIcon: showPassword ? "eye" : "eye.slash") {
                    showPassword.toggle()
                }

                Spacer().frame(height: 16)

                // ── Confirm Password ──────────────────────────────────────
                requiredLabel("Confirm Password")
                AuthTextField(placeholder: "••••••••••",
                              text: $vm.confirmPassword,
                              isSecure: !showConfirmPassword,
                              trailingIcon: showConfirmPassword ? "eye" : "eye.slash") {
                    showConfirmPassword.toggle()
                }

                Spacer().frame(height: 16)

                // ── Role selector ─────────────────────────────────────────
                Text("Who are you?")
                    .font(.urbanistSemiBold(14))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    .padding(.bottom, 10)

                RoleSelector(selected: $vm.selectedRole)

                // ── Error ─────────────────────────────────────────────────
                if let err = vm.errorMessage {
                    Text(err)
                        .font(.urbanistRegular(12))
                        .foregroundColor(.red)
                        .padding(.top, 8)
                }

                Spacer().frame(height: 24)

                // ── Sign Up button ────────────────────────────────────────
                Button {
                    vm.signUp()
                } label: {
                    ZStack {
                        if vm.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Sign Up")
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

                Spacer().frame(height: 20)

                // ── OR divider ────────────────────────────────────────────
                ORDivider()

                Spacer().frame(height: 20)

                // ── Social buttons ────────────────────────────────────────
                SocialButtons()

                Spacer().frame(height: 20)

                // ── Sign In link ──────────────────────────────────────────
                HStack(spacing: 4) {
                    Spacer()
                    Text("Already have an account?")
                        .font(.urbanistRegular(14))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    Button { dismiss() } label: {
                        Text("Sign In")
                            .font(.urbanistSemiBold(14))
                            .foregroundColor(.cakeBrown)
                    }
                    Spacer()
                }

                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 28)
        }
    }

    /// Label with a red asterisk for required fields
    private func requiredLabel(_ text: String) -> some View {
        HStack(spacing: 2) {
            Text(text)
                .font(.urbanistSemiBold(14))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            Text("*")
                .font(.urbanistBold(14))
                .foregroundColor(.red)
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack { SignUpView() }
}
