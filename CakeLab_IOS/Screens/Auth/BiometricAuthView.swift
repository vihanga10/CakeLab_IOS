import SwiftUI

// MARK: - Biometric Auth View (Face ID / Touch ID screen)
struct BiometricAuthView: View {

    let user: AppUser

    @State private var email           = ""
    @State private var authState: AuthState = .idle
    @State private var navigateToMain  = false
    @State private var showEmailLogin  = false

    private let biometric = BiometricManager()
    private let bgImage   = "language"
    private let cardHeight: CGFloat = 400

    enum AuthState {
        case idle, authenticating, success, failed(String)
    }

    var body: some View {
        if navigateToMain {
            ContentView()
        } else {
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
                        cardContent(geo: geo)
                            .frame(maxWidth: .infinity)
                            .frame(height: cardHeight)
                            .background(Color.white)
                            .clipShape(TopRoundedRectangle2(cornerRadius: 40))

                        Color.white.frame(height: geo.safeAreaInsets.bottom)
                    }
                }
                .ignoresSafeArea()
            }
            .ignoresSafeArea()
            .navigationBarHidden(true)
            .onAppear {
                // Automatically trigger Face ID when screen appears
                Task {
                    await triggerBiometric()
                }
            }
        }
    }

    // MARK: - Card content
    @ViewBuilder
    private func cardContent(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {

            Spacer().frame(height: 32)

            // ── Heading ───────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text("HI , WELCOME BACK")
                    .font(.urbanistBold(22))
                    .foregroundColor(.cakeBrown)

                Text("Sign In with Face ID")
                    .font(.urbanistRegular(13))
                    .foregroundColor(.cakeGrey)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)

            Spacer().frame(height: 36)

            // ── Face ID frame icon ────────────────────────────────────
            faceIDIcon

            Spacer().frame(height: 12)

            Text("Position your face on the box")
                .font(.urbanistRegular(13))
                .foregroundColor(.cakeGrey)

            Spacer().frame(height: 32)

            // ── Email field (optional pre-fill) ───────────────────────
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 2) {
                    Text("Email Address")
                        .font(.urbanistSemiBold(14))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    Text("*").font(.urbanistBold(14)).foregroundColor(.red)
                }
                AuthTextField(placeholder: "you@example.com",
                              text: $email,
                              keyboardType: .emailAddress)
            }
            .padding(.horizontal, 28)

            // ── Error message ─────────────────────────────────────────
            if case .failed(let msg) = authState {
                Text(msg)
                    .font(.urbanistRegular(12))
                    .foregroundColor(.red)
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
            }

            Spacer()

            // ── OR + Login with Email divider ─────────────────────────
            VStack(spacing: 16) {
                ORDivider()
                    .padding(.horizontal, 28)

                Button {
                    showEmailLogin = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Login with")
                            .font(.urbanistRegular(14))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        Text("Email & Password")
                            .font(.urbanistSemiBold(14))
                            .foregroundColor(.cakeBrown)
                    }
                }
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Face ID icon (custom drawn to match design)
    private var faceIDIcon: some View {
        ZStack {
            // Corner brackets
            FaceIDBrackets()
                .stroke(Color(red: 0.3, green: 0.65, blue: 0.35), lineWidth: 2.5)
                .frame(width: 100, height: 100)

            // Face icon fill
            Image(systemName: "face.smiling")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
        }
        // Pulse animation while authenticating
        .scaleEffect(authState == .authenticating ? 1.08 : 1.0)
        .animation(authState == .authenticating
            ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
            : .default, value: authState == .authenticating)
        .onTapGesture {
            Task { await triggerBiometric() }
        }
    }

    // MARK: - Trigger Face ID
    private func triggerBiometric() async {
        authState = .authenticating
        do {
            let success = try await biometric.authenticate(reason: "Sign in to CakeLab")
            if success {
                authState       = .success
                navigateToMain  = true
            } else {
                authState = .failed("Face ID authentication failed. Tap the icon to retry.")
            }
        } catch {
            authState = .failed(error.localizedDescription)
        }
    }
}

// MARK: - Face ID Bracket Shape
private struct FaceIDBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 14   // corner radius of bracket
        let l: CGFloat = 26   // length of each bracket arm
        var p = Path()

        // Top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))

        // Top-right
        p.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))

        // Bottom-right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))

        // Bottom-left
        p.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))

        return p
    }
}

// MARK: - Equatable conformance for authState (animation)
extension BiometricAuthView.AuthState: Equatable {
    static func == (lhs: BiometricAuthView.AuthState, rhs: BiometricAuthView.AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.authenticating, .authenticating), (.success, .success): return true
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        BiometricAuthView(user: .mock)
    }
}
