import SwiftUI

// MARK: - Sign In View
struct SignInView: View {

    @StateObject private var vm = SignInViewModel()
    @State private var showPassword   = false
    @State private var showSignUp     = false
    @State private var showForgot     = false
    @State private var showFaceID     = false
    @Environment(\.dismiss) private var dismiss

    // ─── background image name in Assets
    private let bgImage = "language"
    private let cardHeight: CGFloat = 590

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
            // Navigation destinations
            .navigationDestination(isPresented: $showSignUp)  { SignUpView() }
            .navigationDestination(isPresented: $showForgot)  { ForgotPasswordView() }
            .navigationDestination(isPresented: $showFaceID)  {
                if let user = vm.signedInUser {
                    BiometricAuthView(user: user)
                }
            }
            .navigationBarHidden(true)
            // Trigger Face ID navigation when VM signals
            .onChange(of: vm.navigateToFaceID) { val in
                if val { showFaceID = true }
            }
        }
    }

    // MARK: - Scrollable card content
    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                Spacer().frame(height: 28)

                // ── Heading ───────────────────────────────────────────────
                Text("HI , WELCOME BACK")
                    .font(.urbanistBold(24))
                    .foregroundColor(.cakeBrown)

                Spacer().frame(height: 4)

                Text("Kindly provide your credentials to sign in")
                    .font(.urbanistRegular(13))
                    .foregroundColor(.cakeGrey)

                Spacer().frame(height: 28)

                // ── Email ─────────────────────────────────────────────────
                fieldLabel("Email Address")
                AuthTextField(placeholder: "you@example.com",
                              text: $vm.email,
                              keyboardType: .emailAddress)

                Spacer().frame(height: 16)

                // ── Password ──────────────────────────────────────────────
                fieldLabel("Password")
                AuthTextField(placeholder: "••••••••••",
                              text: $vm.password,
                              isSecure: !showPassword,
                              trailingIcon: showPassword ? "eye" : "eye.slash") {
                    showPassword.toggle()
                }

                Spacer().frame(height: 16)

                // ── Role selector ─────────────────────────────────────────
                fieldLabel("Who are you?")
                Spacer().frame(height: 10)
                RoleSelector(selected: $vm.selectedRole)

                Spacer().frame(height: 16)

                // ── Remember me + Forgot password ─────────────────────────
                HStack {
                    Button {
                        vm.rememberMe.toggle()
                    } label: {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.cakeGrey.opacity(0.5), lineWidth: 1.5)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    vm.rememberMe
                                        ? Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.cakeBrown)
                                        : nil
                                )
                            Text("Remember Me")
                                .font(.urbanistRegular(13))
                                .foregroundColor(.cakeGrey)
                        }
                    }

                    Spacer()

                    Button { showForgot = true } label: {
                        Text("Forgot Password ?")
                            .font(.urbanistSemiBold(13))
                            .foregroundColor(.cakeBrown)
                    }
                }

                Spacer().frame(height: 8)

                // ── Error ─────────────────────────────────────────────────
                if let err = vm.errorMessage {
                    Text(err)
                        .font(.urbanistRegular(12))
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }

                Spacer().frame(height: 20)

                // ── Sign In button ────────────────────────────────────────
                Button {
                    vm.signIn()
                } label: {
                    ZStack {
                        if vm.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Sign In")
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

                // ── Create Account link ───────────────────────────────────
                HStack(spacing: 4) {
                    Spacer()
                    Text("Don't have an account ?")
                        .font(.urbanistRegular(14))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    Button { showSignUp = true } label: {
                        Text("Create Account")
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

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.urbanistSemiBold(14))
            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            .padding(.bottom, 8)
    }
}

// MARK: - Preview
#Preview {
    SignInView()
}
