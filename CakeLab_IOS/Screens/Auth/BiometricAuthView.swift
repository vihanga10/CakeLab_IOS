import SwiftUI
import LocalAuthentication

// MARK: - Biometric Auth View (Face ID)
struct BiometricAuthView: View {
    
    @StateObject private var vm = BiometricAuthViewModel()
    @State private var navigateToSignIn = false
    @State private var navigateToSignUp = false
    @State private var navigateToHome = false
    @Environment(\.dismiss) private var dismiss
    
    private let bgImage = "Signin_up"
    
    var body: some View {
        NavigationStack {
            if let user = vm.authenticatedUser, navigateToHome {
                ContentViewWrapper(user: user)
            } else {
                GeometryReader { geo in
                    let cardHeight = geo.size.height * 0.70
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
                .navigationDestination(isPresented: $navigateToSignIn) {
                    SignInView()
                }
                .navigationDestination(isPresented: $navigateToSignUp) {
                    SignUpView()
                }
            }
        }
    }
    
    // MARK: - Card Content
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            Spacer().frame(height: 24)
            
            // ── Heading ───────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text("HI, WELCOME BACK")
                    .font(.urbanistBold(22))
                    .foregroundColor(.cakeBrown)
                
                Text("Sign In with Face ID")
                    .font(.urbanistRegular(13))
                    .foregroundColor(.cakeGrey)
            }
            .padding(.horizontal, 28)
            
            Spacer().frame(height: 20)
            
            // ── Email field ───────────────────────────────────────────
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
            .padding(.horizontal, 28)
            
            // ── Validation message ────────────────────────────────────
            if let error = vm.errorMessage {
                Text(error)
                    .font(.urbanistRegular(12))
                    .foregroundColor(.red)
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
            }
            
            Spacer().frame(height: 20)
            
            // ── Face ID Preview Box ────────────────────────────────────
            VStack(spacing: 16) {
                VStack(spacing: 0) {
                    // Face ID corner bracket frame
                    ZStack {
                        // Corner brackets (custom shape)
                        FaceIDFrame()
                            .stroke(Color(red: 0.3, green: 0.65, blue: 0.35), lineWidth: 2.5)
                            .frame(width: 140, height: 140)
                        
                        VStack(spacing: 12) {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 50))
                                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                        }
                    }
                    .frame(height: 160)
                    
                    Spacer().frame(height: 12)
                    
                    Text("Position with face on the box")
                        .font(.urbanistRegular(13))
                        .foregroundColor(.cakeGrey)
                }
                
                // ── Authentication Button ─────────────────────────────
                Button {
                    Task {
                        // Step 1: Verify email and fetch user
                        await vm.checkUserExists()
                        
                        // Only proceed to Face ID if user was found
                        if vm.isUserValid && vm.errorMessage == nil {
                            // Step 2: Authenticate with Face ID
                            await vm.authenticateWithFaceID()
                            
                            // Step 3: Navigate if Face ID successful
                            if vm.errorMessage == nil && vm.authenticatedUser != nil {
                                navigateToHome = true
                            }
                        }
                    }
                } label: {
                    ZStack {
                        if vm.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Verify with Face ID")
                                .font(.urbanistSemiBold(16))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.cakeBrown)
                    .clipShape(Capsule())
                }
                .disabled(vm.isLoading || vm.email.isEmpty)
                .padding(.horizontal, 28)
                
                // ── OR Divider (close to button) ───────────────────────
                ORDivider()
                    .padding(.horizontal, 28)
                    .padding(.top, 16)
            }
            
            // ── Login with Email & Password (Centered) ────────────────
            Button {
                navigateToSignIn = true
            } label: {
                HStack(spacing: 2) {
                    Text("Login with")
                        .font(.urbanistRegular(13))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    Text("Email & Password")
                        .font(.urbanistSemiBold(13))
                        .foregroundColor(.cakeBrown)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            
            // ── Create Account Link (Centered) ─────────────────────────
            HStack(spacing: 2) {
                Text("Don't have an account ?")
                    .font(.urbanistRegular(15))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                
                Button {
                    navigateToSignUp = true
                } label: {
                    Text("Create Account")
                        .font(.urbanistSemiBold(15))
                        .foregroundColor(.cakeBrown)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            .padding(.bottom, 15)
        }
    }
}

// MARK: - Face ID Frame Shape (Corner Brackets)
private struct FaceIDFrame: Shape {
    func path(in rect: CGRect) -> Path {
        let cornerLength: CGFloat = 28
        let cornerRadius: CGFloat = 8
        var path = Path()
        
        // Top-left corner
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY),
                         control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY))
        
        // Top-right corner
        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius),
                         control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerLength))
        
        // Bottom-right corner
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerLength))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY),
                         control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY))
        
        // Bottom-left corner
        path.move(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius),
                         control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerLength))
        
        return path
    }
}

// MARK: - Preview
#Preview {
    NavigationStack { BiometricAuthView() }
}

