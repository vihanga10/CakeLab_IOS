import SwiftUI

// MARK: - Top-corners-only rounded rectangle (radius 40)
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

// MARK: - Onboarding Page View
struct OnboardingPageView: View {

    let page: OnboardingPage
    let currentPage: Int
    let totalPages: Int
    let onNext: () -> Void
    let onPrev: () -> Void

    private let cardHeight: CGFloat = 340

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {

                // ── Full-screen photo ────────────────────────────────────
                Image(page.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                // ── Gradient fade: photo into card ───────────────────────
                LinearGradient(
                    gradient: Gradient(colors: [.clear, Color.white.opacity(0.18), Color.white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: cardHeight + 80)
                .frame(maxWidth: .infinity)

                // ── White card + safe-area filler ────────────────────────
                VStack(spacing: 0) {

                    VStack(spacing: 0) {

                        Spacer().frame(height: 32)

                        // ── Progress bar (pill segments) ─────────────────
                        HStack(spacing: 6) {
                            ForEach(0..<totalPages, id: \.self) { index in
                                Capsule()
                                    .fill(index <= currentPage ? Color.cakeBrown : Color.cakeDot)
                                    .frame(width: index == currentPage ? 28 : 8, height: 5)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 32)

                        Spacer().frame(height: 48)

                        // ── Title ─────────────────────────────────────────
                        page.titleText
                            .font(.urbanistBold(20))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 32)

                        Spacer().frame(height: 12)

                        // ── Subtitle ──────────────────────────────────────
                        Text(page.subtitle)
                            .font(.urbanistRegular(15))
                            .foregroundColor(.cakeGrey)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineSpacing(4)
                            .padding(.horizontal, 32)

                        Spacer()

                        // ── Action row ────────────────────────────────────
                        HStack(alignment: .center) {

                            // Back button
                            Button(action: onPrev) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.cakeBrown)
                            }
                            .opacity(currentPage > 0 ? 1 : 0)
                            .disabled(currentPage == 0)

                            Spacer()

                            // Next button – chevron
                            Button(action: onNext) {
                                Image(systemName: currentPage == totalPages - 1 ? "checkmark" : "chevron.right")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.cakeBrown)
                            }
                        }
                        .padding(.horizontal, 32)
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

#Preview {
    OnboardingPageView(
        page: OnboardingPage(
            titleSegments: [
                ("Dream ",   false),
                ("Cakes,",   true),
                (" Real ",   false),
                ("Crafters", true)
            ],
            subtitle: "Connecting Cake Cravers with Sri Lanka's finest Cake Crafters",
            imageName: "splash1"
        ),
        currentPage: 0,
        totalPages: 3,
        onNext: {},
        onPrev: {}
    )
}

