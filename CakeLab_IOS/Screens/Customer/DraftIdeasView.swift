import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Draft Ideas View (Customer's saved but unpublished cake requests)
@MainActor
struct DraftIdeasView: View {
    let user: AppUser
    @Environment(\.dismiss) private var dismiss
    
    @State private var drafts: [CakeRequestRecord] = []
    @State private var isLoading = false
    private let requestStore = CustomerRequestStore()

    var body: some View {
        ZStack(alignment: .top) {
            backgroundLayer

            VStack(spacing: 0) {
                headerBar

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.cakeBrown)
                        Text("Loading drafts...")
                            .font(.urbanistRegular(13))
                            .foregroundColor(.cakeGrey)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if drafts.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            ForEach(drafts) { draft in
                                DraftRequestCard(user: user, draft: draft)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 28)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await fetchDrafts()
        }
        .refreshable {
            await fetchDrafts()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("customerRequestDidChange"))) { _ in
            Task {
                await fetchDrafts()
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cakeBrown)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("Draft Ideas")
                    .font(.urbanistBold(18))
                    .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
            }
            Spacer()
            Color.clear.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.white)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.cakeBrown.opacity(0.12))
                    .frame(width: 70, height: 70)
                Image(systemName: "pencil.and.scribble")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.cakeBrown)
            }
            Text("No draft ideas yet")
                .font(.urbanistSemiBold(16))
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
            Text("Save a cake request as draft to see it here")
                .font(.urbanistRegular(13))
                .foregroundColor(.cakeGrey)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var backgroundLayer: some View {
        Color.white.ignoresSafeArea()
    }
    
    private func fetchDrafts() async {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("Error fetching draft requests: no authenticated Firebase session")
            drafts = []
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            drafts = try await requestStore.fetchRequests(for: userID, from: .draft)
        } catch {
            print("Error fetching draft requests: \(error)")
        }
    }
}

// MARK: - Draft Request Card
private struct DraftRequestCard: View {
    let user: AppUser
    let draft: CakeRequestRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.displayTitle)
                        .font(.urbanistSemiBold(15))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .lineLimit(2)
                    Text(draft.displayCategory)
                        .font(.urbanistMedium(11))
                        .foregroundColor(categoryTextColor(for: draft.displayCategory))
                        .frame(height: 22)
                        .padding(.horizontal, 10)
                        .background(categoryBackgroundColor(for: draft.displayCategory))
                        .clipShape(Capsule())
                }
                Spacer()
                Text("Draft")
                    .font(.urbanistSemiBold(10))
                    .foregroundColor(Color(red: 0.55, green: 0.45, blue: 0.35))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(red: 0.93, green: 0.88, blue: 0.82))
                    .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Completion")
                        .font(.urbanistRegular(11))
                        .foregroundColor(.cakeGrey)
                    Spacer()
                    Text("\(draft.completionPercent)%")
                        .font(.urbanistSemiBold(11))
                        .foregroundColor(.cakeBrown)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(red: 0.88, green: 0.88, blue: 0.88))
                            .frame(height: 5)
                        Capsule()
                            .fill(Color.cakeBrown)
                            .frame(width: geo.size.width * CGFloat(draft.completionPercent) / 100,
                                   height: 5)
                    }
                }
                .frame(height: 5)
            }

            Divider()

            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.cakeGrey)
                    Text("Last saved: \(formattedDate(draft.sortDate))")
                        .font(.urbanistRegular(11))
                        .foregroundColor(.cakeGrey)
                }
                Spacer()
                NavigationLink(destination: CreateCakeRequestView(user: user, initialDraft: draft)) {
                    Text("Continue Editing")
                        .font(.urbanistSemiBold(12))
                        .foregroundColor(.cakeBrown)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(
                            Capsule().stroke(Color.cakeBrown, lineWidth: 1.5)
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Category Color Mapping
    private func categoryBackgroundColor(for category: String) -> Color {
        let categoryLower = category.lowercased()
        switch categoryLower {
        case let cat where cat.contains("wedding"):
            return Color(red: 1.0, green: 0.95, blue: 0.97) // Pink pastel
        case let cat where cat.contains("birthday"):
            return Color(red: 0.99, green: 0.95, blue: 0.90) // Peach pastel
        case let cat where cat.contains("anniversary"):
            return Color(red: 0.95, green: 0.99, blue: 0.95) // Mint pastel
        case let cat where cat.contains("baby"):
            return Color(red: 0.98, green: 0.96, blue: 1.0) // Lavender pastel
        case let cat where cat.contains("cupcake"):
            return Color(red: 1.0, green: 0.98, blue: 0.94) // Cream pastel
        case let cat where cat.contains("buttercream"):
            return Color(red: 0.99, green: 1.0, blue: 0.95) // Light yellow pastel
        case let cat where cat.contains("corporate"):
            return Color(red: 0.95, green: 0.98, blue: 1.0) // Sky blue pastel
        case let cat where cat.contains("engagement"):
            return Color(red: 1.0, green: 0.96, blue: 0.92) // Coral pastel
        case let cat where cat.contains("graduation"):
            return Color(red: 0.94, green: 0.97, blue: 1.0) // Light blue pastel
        case let cat where cat.contains("baptism"):
            return Color(red: 0.96, green: 0.99, blue: 1.0) // Ice blue pastel
        case let cat where cat.contains("retirement"):
            return Color(red: 1.0, green: 0.96, blue: 0.94) // Salmon pastel
        case let cat where cat.contains("farewell"):
            return Color(red: 0.98, green: 0.97, blue: 1.0) // Soft purple pastel
        case let cat where cat.contains("vegan"):
            return Color(red: 0.96, green: 1.0, blue: 0.96) // Pale green pastel
        case let cat where cat.contains("sculpted"):
            return Color(red: 0.98, green: 0.95, blue: 0.99) // Lilac pastel
        default:
            return Color(red: 0.96, green: 0.96, blue: 0.96) // Gray pastel
        }
    }
    
    private func categoryTextColor(for category: String) -> Color {
        let categoryLower = category.lowercased()
        switch categoryLower {
        case let cat where cat.contains("wedding"):
            return Color(red: 0.8, green: 0.3, blue: 0.6) // Rose
        case let cat where cat.contains("birthday"):
            return Color(red: 0.85, green: 0.5, blue: 0.25) // Burnt orange
        case let cat where cat.contains("anniversary"):
            return Color(red: 0.2, green: 0.6, blue: 0.4) // Teal
        case let cat where cat.contains("baby"):
            return Color(red: 0.6, green: 0.3, blue: 0.8) // Purple
        case let cat where cat.contains("cupcake"):
            return Color(red: 0.8, green: 0.5, blue: 0.2) // Orange
        case let cat where cat.contains("buttercream"):
            return Color(red: 0.7, green: 0.6, blue: 0.1) // Golden
        case let cat where cat.contains("corporate"):
            return Color(red: 0.2, green: 0.5, blue: 0.8) // Blue
        case let cat where cat.contains("engagement"):
            return Color(red: 0.85, green: 0.35, blue: 0.3) // Red
        case let cat where cat.contains("graduation"):
            return Color(red: 0.3, green: 0.5, blue: 0.7) // Slate blue
        case let cat where cat.contains("baptism"):
            return Color(red: 0.2, green: 0.6, blue: 0.7) // Cyan
        case let cat where cat.contains("retirement"):
            return Color(red: 0.8, green: 0.4, blue: 0.3) // Terracotta
        case let cat where cat.contains("farewell"):
            return Color(red: 0.5, green: 0.3, blue: 0.7) // Plum
        case let cat where cat.contains("vegan"):
            return Color(red: 0.2, green: 0.7, blue: 0.2) // Forest green
        case let cat where cat.contains("sculpted"):
            return Color(red: 0.7, green: 0.2, blue: 0.7) // Magenta
        default:
            return Color(red: 0.4, green: 0.4, blue: 0.4) // Dark gray
        }
    }
}

#Preview {
    NavigationStack { DraftIdeasView(user: .mock) }
}
