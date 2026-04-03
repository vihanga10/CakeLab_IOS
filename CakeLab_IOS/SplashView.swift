import SwiftUI

struct SplashView: View {
    @State private var showOnboarding = false

    // Entry animation states
    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0.0

    // Floating animation state
    @State private var floatOffset: CGFloat = 0

    // Glow pulse state
    @State private var glowRadius: CGFloat = 0
    @State private var glowOpacity: Double = 0

    var body: some View {
        if showOnboarding {
            OnboardingView()
        } else {
            ZStack {
                // Clean white background matching the design
                Color.white
                    .ignoresSafeArea()

                ZStack {
                    // Soft glow ring behind logo that pulses
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.55, green: 0.27, blue: 0.07).opacity(0.12),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 60,
                                endRadius: 140
                            )
                        )
                        .frame(width: 280, height: 280)
                        .scaleEffect(glowRadius)
                        .opacity(glowOpacity)

                    // Logo image (contains cake + "CakeLab" text)
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 260, height: 260)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .offset(y: floatOffset)
                }
            }
            .onAppear {
                // Phase 1: Spring pop-in entrance
                withAnimation(.spring(response: 0.7, dampingFraction: 0.55, blendDuration: 0)) {
                    logoScale = 1.0
                    logoOpacity = 1.0
                }

                // Phase 2: Glow ring fades in shortly after
                withAnimation(.easeOut(duration: 0.9).delay(0.4)) {
                    glowRadius = 1.0
                    glowOpacity = 1.0
                }

                // Phase 3: Continuous subtle float after entry settles
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(
                        .easeInOut(duration: 1.6)
                        .repeatForever(autoreverses: true)
                    ) {
                        floatOffset = -10
                    }
                }

                // Navigate to onboarding after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showOnboarding = true
                    }
                }
            }
        }
    }
}

#Preview {
    SplashView()
}
