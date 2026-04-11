import SwiftUI

// MARK: - Sign Up View
@MainActor
struct SignUpView: View {

    @StateObject private var vm = SignUpViewModel()
    @State private var showPassword        = false
    @State private var showConfirmPassword = false
    @State private var showSignUpSuccessAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {

                    // ── Background photo ─────────────────────────────────
                    Image("Signin_up")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()

                    // ── Gradient fade photo → card ───────────────────────
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.15), .white],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.55)
                    .frame(maxWidth: .infinity)

                    // ── White card (fixed, no scroll) ────────────────────
                    VStack(spacing: 0) {
                        cardContent
                            .frame(maxWidth: .infinity)
                            .frame(height: geo.size.height * 0.78)
                            .background(Color.white)
                            .clipShape(TopRoundedRectangle2(cornerRadius: 36))

                        Color.white.frame(height: geo.safeAreaInsets.bottom)
                    }

                    // ── Back chevron (under status bar) ──────────────────
                    VStack(spacing: 0) {
                        HStack {
                            Button { dismiss() } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, geo.safeAreaInsets.top + 79)
                        Spacer()
                    }
                }
                .ignoresSafeArea()
            }
            .ignoresSafeArea()
            .navigationBarHidden(true)
            .onChange(of: vm.navigateToFaceID) { _, newVal in
                if newVal {
                    showSignUpSuccessAlert = true
                    vm.navigateToFaceID = false
                }
            }
            .alert("Registration Successful", isPresented: $showSignUpSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your account has been created successfully. Please sign in to continue.")
            }
        }
    }

    // MARK: - Card content (fixed layout — no ScrollView)
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {

            Spacer().frame(height: 24)

            // ── Heading ───────────────────────────────────────────────
            Text("CREATE YOUR ACCOUNT")
                .font(.urbanistBold(24))
                .foregroundColor(.cakeBrown)

            Spacer().frame(height: 3)

            Text("Start your cake journey today")
                .font(.urbanistRegular(13))
                .foregroundColor(.cakeGrey)

            Spacer().frame(height: 20)

            // ── Email ─────────────────────────────────────────────────
            fieldLabel("Email Address")
            AuthTextField(placeholder: "you@example.com",
                          text: $vm.email,
                          keyboardType: .emailAddress)

            Spacer().frame(height: 12)

            // ── Password ──────────────────────────────────────────────
            fieldLabel("Password")
            AuthTextField(placeholder: "••••••••••",
                          text: $vm.password,
                          isSecure: !showPassword,
                          trailingIcon: showPassword ? "eye" : "eye.slash") {
                showPassword.toggle()
            }

            Spacer().frame(height: 12)

            // ── Confirm Password ──────────────────────────────────────
            fieldLabel("Confirm Password")
            AuthTextField(placeholder: "••••••••••",
                          text: $vm.confirmPassword,
                          isSecure: !showConfirmPassword,
                          trailingIcon: showConfirmPassword ? "eye" : "eye.slash") {
                showConfirmPassword.toggle()
            }

            Spacer().frame(height: 12)

            // ── Role selector ─────────────────────────────────────────
            fieldLabel("Who are you?")
            Spacer().frame(height: 8)
            RoleSelector(selected: $vm.selectedRole)

            Spacer().frame(height: 14)

            // ── Error ─────────────────────────────────────────────────
            if let err = vm.errorMessage {
                Text(err)
                    .font(.urbanistRegular(11))
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }

            Spacer().frame(height: 16)

            // ── Sign Up button ────────────────────────────────────────
            Button { vm.signUp() } label: {
                ZStack {
                    if vm.isLoading { ProgressView().tint(.white) }
                    else {
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

            Spacer().frame(height: 14)

            // ── OR divider ────────────────────────────────────────────
            ORDivider()

            Spacer().frame(height: 12)

            // ── Social buttons ────────────────────────────────────────
            SocialButtons()

            Spacer().frame(height: 12)

            // ── Sign In link ──────────────────────────────────────────
            HStack(spacing: 4) {
                Spacer()
                Text("Already have an account?")
                    .font(.urbanistRegular(13))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                Button { dismiss() } label: {
                    Text("Sign In")
                        .font(.urbanistSemiBold(13))
                        .foregroundColor(.cakeBrown)
                }
                Spacer()
            }

            Spacer()
        }
        .padding(.horizontal, 26)
    }

    private func fieldLabel(_ text: String) -> some View {
        HStack(spacing: 2) {
            Text(text)
                .font(.urbanistSemiBold(14))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            Text("*")
                .font(.urbanistBold(14))
                .foregroundColor(.red)
        }
        .padding(.bottom, 7)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack { SignUpView() }
}
