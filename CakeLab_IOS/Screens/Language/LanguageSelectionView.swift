import SwiftUI

// MARK: - Language Model
private struct Language: Identifiable {
    let id = UUID()
    let native: String
    let english: String
}

// MARK: - Language Selection View
struct LanguageSelectionView: View {

    @State private var selectedLanguage: String = "English"
    @State private var showSignIn = false

    private let languages: [Language] = [
        Language(native: "English",   english: "British English"),
        Language(native: "සිංහල",     english: "Sinhala"),
        Language(native: "தமிழ்",     english: "Tamil")
    ]

    private let cardHeight: CGFloat = 460

    var body: some View {
        if showSignIn {
            NavigationStack { BiometricAuthView() }
        } else {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {

                    // ── Full-screen background photo ─────────────────────
                    Image("language")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()

                    // ── Gradient fade: photo into card ───────────────────
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, Color.white.opacity(0.18), Color.white]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: cardHeight + 80)
                    .frame(maxWidth: .infinity)

                    // ── White card + safe-area filler ────────────────────
                    VStack(spacing: 0) {

                        VStack(spacing: 0) {

                            Spacer().frame(height: 32)

                            // ── Heading ───────────────────────────────────
                            VStack(alignment: .leading, spacing: 4) {
                                Text("WELCOME !")
                                    .font(.urbanistBold(26))
                                    .foregroundColor(.cakeBrown)

                                Text("Select Your Language")
                                    .font(.urbanistRegular(14))
                                    .foregroundColor(.cakeGrey)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 32)

                            Spacer().frame(height: 28)

                            // ── Language Buttons ──────────────────────────
                            VStack(spacing: 12) {
                                ForEach(languages) { lang in
                                    LanguageButton(
                                        language: lang.native,
                                        subtitle: lang.english,
                                        isSelected: selectedLanguage == lang.native
                                    ) {
                                        selectedLanguage = lang.native
                                    }
                                }
                            }
                            .padding(.horizontal, 24)

                            Spacer()

                            // ── Continue Button ───────────────────────────
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    showSignIn = true
                                }
                            }) {
                                Text("Continue")
                                    .font(.urbanistSemiBold(17))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(Color.cakeBrown)
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 36)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: cardHeight)
                        .background(Color.white)
                        .clipShape(TopRoundedRectangle(cornerRadius: 40))

                        // Extend white below home indicator
                        Color.white
                            .frame(height: geo.safeAreaInsets.bottom)
                    }
                }
                .ignoresSafeArea()
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Language Button
private struct LanguageButton: View {
    let language: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(language)
                    .font(.urbanistSemiBold(17))
                    .foregroundColor(isSelected ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color(red: 0.3, green: 0.3, blue: 0.3))

                Text(subtitle)
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeGrey)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(
                isSelected
                    ? Color(red: 212/255, green: 196/255, blue: 176/255).opacity(0.45)
                    : Color(red: 0.93, green: 0.93, blue: 0.93)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
    }
}

// MARK: - TopRoundedRectangle reuse note
// TopRoundedRectangle is defined in OnboardingPageView.swift (private).
// We redeclare it here for this standalone screen.
private struct TopRoundedRectangle: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addArc(
            center: CGPoint(x: rect.minX + r, y: rect.minY + r),
            radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
            radius: r, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    LanguageSelectionView()
}
