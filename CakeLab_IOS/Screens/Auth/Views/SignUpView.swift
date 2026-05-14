import SwiftUI


@MainActor
struct SignUpView: View {

    @StateObject private var vm = SignUpViewModel()
    @State private var showPassword        = false
    @State private var showConfirmPassword = false
    @State private var showSignIn = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {

                     
                    Image("Signin_up")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()

                     
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.15), .white],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.55)
                    .frame(maxWidth: .infinity)

                     
                    VStack(spacing: 0) {
                        cardContent
                            .frame(maxWidth: .infinity)
                            .frame(height: geo.size.height * 0.78)
                            .background(Color.cakeSurface)
                            .clipShape(TopRoundedRectangle2(cornerRadius: 36))

                        Color.white.frame(height: geo.safeAreaInsets.bottom)
                    }

                     
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
            .navigationDestination(isPresented: $showSignIn) {
                SignInView()
            }
            .onChange(of: vm.navigateToFaceID) { _, newVal in
                if newVal {
                    vm.navigateToFaceID = false
                    Task {
                        await scheduleAccountCreatedNotification()
                        dismiss()
                    }
                }
            }
        }
    }

    private func scheduleAccountCreatedNotification() async {
        await NotificationManager.scheduleLocalNotification(
            title: "Registration Successful",
            body: "Your account has been created successfully. Please sign in to continue.",
            identifier: "account-created-\(UUID().uuidString)"
        )
    }

    // MARK: - Card content
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {

            Spacer().frame(height: 24)

             
            Text("CREATE YOUR ACCOUNT")
                .font(.urbanistBold(24))
                .foregroundColor(.cakeBrown)

            Spacer().frame(height: 3)

            Text("Start your cake journey today")
                .font(.urbanistRegular(13))
                .foregroundColor(.cakeGrey)

            Spacer().frame(height: 20)

             
            fieldLabel("Email Address")
            AuthTextField(placeholder: "you@example.com",
                          text: $vm.email,
                          keyboardType: .emailAddress)

            Spacer().frame(height: 12)

            
            fieldLabel("Password")
            AuthTextField(placeholder: "••••••••••",
                          text: $vm.password,
                          isSecure: !showPassword,
                          trailingIcon: showPassword ? "eye" : "eye.slash") {
                showPassword.toggle()
            }

            Spacer().frame(height: 12)

            
            fieldLabel("Confirm Password")
            AuthTextField(placeholder: "••••••••••",
                          text: $vm.confirmPassword,
                          isSecure: !showConfirmPassword,
                          trailingIcon: showConfirmPassword ? "eye" : "eye.slash") {
                showConfirmPassword.toggle()
            }

            Spacer().frame(height: 12)

            //  Role selector 
            fieldLabel("Who are you?")
            Spacer().frame(height: 8)
            RoleSelector(selected: $vm.selectedRole)

            Spacer().frame(height: 14)

            //  Error 
            if let err = vm.errorMessage {
                Text(err)
                    .font(.urbanistRegular(11))
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }

            Spacer().frame(height: 16)

            //  Sign Up button 
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

             
            ORDivider()

            Spacer().frame(height: 12)

            //  Social buttons 
            SocialButtons(
                onGoogleTap: {
                    guard let presentingViewController = UIApplication.shared.authTopViewController else {
                        vm.errorMessage = "Unable to open Google Sign-In."
                        return
                    }
                    vm.signUpWithGoogle(presentingViewController: presentingViewController)
                },
                onAppleTap: {
                    guard let presentationAnchor = UIApplication.shared.authPresentationAnchor else {
                        vm.errorMessage = "Unable to open Apple Sign-In."
                        return
                    }
                    vm.signUpWithApple(presentationAnchor: presentationAnchor)
                }
            )

            Spacer().frame(height: 12)

            //  Sign In  
            HStack(spacing: 4) {
                Spacer()
                Text("Already have an account?")
                    .font(.urbanistRegular(13))
                    .foregroundColor(.cakePrimaryText)
                Button { showSignIn = true } label: {
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
                .foregroundColor(.cakePrimaryText)
            Text("*")
                .font(.urbanistBold(14))
                .foregroundColor(.red)
        }
        .padding(.bottom, 7)
    }
}


#Preview {
    NavigationStack { SignUpView() }
}
