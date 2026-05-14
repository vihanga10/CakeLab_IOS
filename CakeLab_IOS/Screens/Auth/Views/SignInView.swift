import SwiftUI


@MainActor
struct SignInView: View {

    @StateObject private var vm = SignInViewModel()
    @State private var showPassword   = false
    @State private var showSignUp     = false
    @State private var showForgot     = false
    @State private var showContentView = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationManager: NotificationManager

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
                            .frame(height: geo.size.height * 0.75)
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
            .navigationDestination(isPresented: $showSignUp)  { SignUpView() }
            .navigationDestination(isPresented: $showForgot)  { ForgotPasswordView() }
            .navigationDestination(isPresented: $showContentView)  {
                
                if let user = vm.signedInUser {
                    ContentViewWrapper(user: user)
                }
            }
            .navigationBarHidden(true)
            .onChange(of: vm.navigateToFaceID) { _, newVal in
                if newVal {
                    // Reload notifications on successful login with user type
                    if let user = vm.signedInUser {
                        notificationManager.reloadNotifications(for: user.role.rawValue, userID: user.id)
                        print(" Notifications reloaded for \(user.role.rawValue) after sign in")
                    }
                    showContentView = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .appUserDidSignOut)) { _ in
                showContentView = false
                vm.resetSessionState()
            }
        }
    }

    // MARK: - Card content
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {

            Spacer().frame(height: 28)

            
            Text("HI , WELCOME BACK")
                .font(.urbanistBold(24))
                .foregroundColor(.cakeBrown)

            Spacer().frame(height: 4)

            Text("Kindly provide your credentials to sign in")
                .font(.urbanistRegular(13))
                .foregroundColor(.cakeGrey)

            Spacer().frame(height: 26)

             
            fieldLabel("Email Address")
            AuthTextField(placeholder: "you@example.com",
                          text: $vm.email,
                          keyboardType: .emailAddress)

            Spacer().frame(height: 16)

             
            fieldLabel("Password")
            AuthTextField(placeholder: "••••••••••",
                          text: $vm.password,
                          isSecure: !showPassword,
                          trailingIcon: showPassword ? "eye" : "eye.slash") {
                showPassword.toggle()
            }

            Spacer().frame(height: 16)

            //  Role selector 
            fieldLabel("Who are you?")
            Spacer().frame(height: 10)
            RoleSelector(selected: $vm.selectedRole)

            Spacer().frame(height: 18)

            //  Remember me + Forgot password 
            HStack {
                Button { vm.rememberMe.toggle() } label: {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.cakeGrey.opacity(0.5), lineWidth: 1.5)
                            .frame(width: 18, height: 18)
                            .overlay(
                                vm.rememberMe
                                    ? Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
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

            //  Error 
            if let err = vm.errorMessage {
                Text(err)
                    .font(.urbanistRegular(11))
                    .foregroundColor(.red)
                    .padding(.top, 6)
            }

            Spacer().frame(height: 20)

            //  Sign In button 
            Button { vm.signIn() } label: {
                ZStack {
                    if vm.isLoading { ProgressView().tint(.white) }
                    else {
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

             
            ORDivider()

            Spacer().frame(height: 18)

            //  Social buttons
            SocialButtons(
                onGoogleTap: {
                    guard let presentingViewController = UIApplication.shared.authTopViewController else {
                        vm.errorMessage = "Unable to open Google Sign-In."
                        return
                    }
                    vm.signInWithGoogle(presentingViewController: presentingViewController)
                },
                onAppleTap: {
                    guard let presentationAnchor = UIApplication.shared.authPresentationAnchor else {
                        vm.errorMessage = "Unable to open Apple Sign-In."
                        return
                    }
                    vm.signInWithApple(presentationAnchor: presentationAnchor)
                }
            )

            Spacer().frame(height: 18)

            //  Create Account  
            HStack(spacing: 4) {
                Spacer()
                Text("Don't have an account ?")
                    .font(.urbanistRegular(13))
                    .foregroundColor(.cakePrimaryText)
                Button { showSignUp = true } label: {
                    Text("Create Account")
                        .font(.urbanistSemiBold(13))
                        .foregroundColor(.cakeBrown)
                }
                Spacer()
            }

            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.urbanistSemiBold(14))
            .foregroundColor(.cakePrimaryText)
            .padding(.bottom, 7)
    }
}


#Preview {
    SignInView()
}
