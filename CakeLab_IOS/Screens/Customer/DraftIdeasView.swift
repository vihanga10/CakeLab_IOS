import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Draft Ideas View (Customer's saved but unpublished cake requests)
@MainActor
struct DraftIdeasView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var drafts: [CakeRequestRecord] = []
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.97, blue: 0.97).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.cakeBrown)
                    }
                    Spacer()
                    Text("Draft Ideas")
                        .font(.urbanistBold(18))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    Spacer()
                    Color.clear.frame(width: 24)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 2)

                if isLoading {
                    Spacer()
                    ProgressView("Loading drafts...")
                        .tint(.cakeBrown)
                    Spacer()
                } else if drafts.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "pencil.and.scribble")
                            .font(.system(size: 44))
                            .foregroundColor(.cakeGrey)
                        Text("No draft ideas yet")
                            .font(.urbanistSemiBold(15))
                            .foregroundColor(.cakeGrey)
                        Text("Save a cake request as draft to see it here")
                            .font(.urbanistRegular(13))
                            .foregroundColor(.cakeGrey)
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(drafts) { draft in
                                DraftRequestCard(draft: draft)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 30)
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
    
    private func fetchDrafts() async {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await Firestore.firestore()
                .collection("draftRequests")
                .whereField("customerID", isEqualTo: userID)
                .getDocuments()
            
            drafts = snapshot.documents
                .compactMap(CakeRequestRecord.init(document:))
                .sorted { $0.sortDate > $1.sortDate }
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
    NavigationStack { DraftIdeasView() }
}
