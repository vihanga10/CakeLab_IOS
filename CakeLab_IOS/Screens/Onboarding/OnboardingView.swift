import SwiftUI

// MARK: - Brand Colours
extension Color {
    static let cakeBrown = Color(red: 93 / 255, green: 55 / 255, blue: 20 / 255)   // #5D3714
    static let cakeGrey  = Color(red: 115 / 255, green: 115 / 255, blue: 115 / 255) // #737373
    static let cakeDot   = Color(red: 212 / 255, green: 196 / 255, blue: 176 / 255) // inactive dot
}

// MARK: - Data Model
struct OnboardingPage {
    /// [(text, isBrown)] segments that compose the title.
    let titleSegments: [(String, Bool)]
    let subtitle: String
    let imageName: String

    var titleText: Text {
        titleSegments.reduce(Text("")) { result, segment in
            result + Text(segment.0)
                .font(Font.custom("Urbanist-Bold", size: 26))
                .foregroundColor(segment.1 ? .cakeBrown : Color(red: 0.1, green: 0.1, blue: 0.1))
        }
    }
}

// MARK: - Onboarding Container
struct OnboardingView: View {

    @State private var currentPage = 0
    @State private var showMain = false

    private let pages: [OnboardingPage] = [
        // Page 1
        OnboardingPage(
            titleSegments: [
                ("Dream ",    false),
                ("Cakes,",    true),
                (" Real ",    false),
                ("Crafters",  true)
            ],
            subtitle: "Connecting Cake Cravers with Sri Lanka's finest Cake Crafters",
            imageName: "splash1"
        ),
        // Page 2
        OnboardingPage(
            titleSegments: [
                ("Sweet ",       false),
                ("Everything,",  true),
                (" One ",        false),
                ("App",          true)
            ],
            subtitle: "One App. One post. Real bakers. Instant joy",
            imageName: "splash2"
        ),
        // Page 3
        OnboardingPage(
            titleSegments: [
                ("Track Every ",   false),
                ("Delicious",      true),
                (" Moment",        false)
            ],
            subtitle: "From 'Request Sent' to 'Cake Delivered' see live updates in real time",
            imageName: "splash3"
        )
    ]

    var body: some View {
        if showMain {
            ContentView()
        } else {
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(
                        page: pages[index],
                        currentPage: currentPage,
                        totalPages: pages.count,
                        onNext: {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                if currentPage < pages.count - 1 {
                                    currentPage += 1
                                } else {
                                    showMain = true
                                }
                            }
                        },
                        onPrev: {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                if currentPage > 0 { currentPage -= 1 }
                            }
                        }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
    }
}

#Preview {
    OnboardingView()
}
