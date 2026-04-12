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
                                DraftRequestCard(draft: draft)
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
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                Text("Saved for later")
                    .font(.urbanistRegular(11))
                    .foregroundColor(.cakeGrey)
            }
            Spacer()
            Color.clear.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
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
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.96, blue: 0.94), Color(red: 0.97, green: 0.97, blue: 0.97)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.cakeBrown.opacity(0.06))
                .frame(width: 220, height: 220)
                .offset(x: 140, y: -120)
        }
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
    let draft: CakeRequestRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(draft.displayTitle)
                            .font(.urbanistSemiBold(15))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        Text("Draft")
                            .font(.urbanistSemiBold(10))
                            .foregroundColor(Color(red: 0.55, green: 0.45, blue: 0.35))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.93, green: 0.88, blue: 0.82))
                            .cornerRadius(8)
                    }
                    Text(draft.displayCategory)
                        .font(.urbanistRegular(12))
                        .foregroundColor(.cakeGrey)
                }
                Spacer()
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
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack { DraftIdeasView(user: .mock) }
}
