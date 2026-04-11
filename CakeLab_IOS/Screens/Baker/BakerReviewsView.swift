import SwiftUI
import FirebaseFirestore

struct BakerReviewsView: View {
    let user: AppUser
    @State private var reviews: [Review] = []
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss
    
    var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        return Double(reviews.reduce(0) { $0 + $1.rating }) / Double(reviews.count)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.cakeBrown)
                        Text("Loading reviews...")
                            .font(.urbanistRegular(14))
                            .foregroundColor(.cakeGrey)
                    }
                } else if reviews.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "star.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.cakeBrown.opacity(0.3))
                        Text("No Reviews Yet")
                            .font(.urbanistBold(18))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        Text("You haven't received any reviews yet. Complete orders to get reviews from customers.")
                            .font(.urbanistRegular(14))
                            .foregroundColor(.cakeGrey)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Average rating header
                            VStack(spacing: 12) {
                                HStack(spacing: 4) {
                                    ForEach(0..<5, id: \.self) { index in
                                        Image(systemName: index < Int(averageRating) ? "star.fill" : "star")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.2))
                                    }
                                }
                                
                                Text(String(format: "%.1f", averageRating))
                                    .font(.urbanistBold(32))
                                    .foregroundColor(Color.cakeBrown)
                                
                                Text("Based on \(reviews.count) review\(reviews.count == 1 ? "" : "s")")
                                    .font(.urbanistRegular(13))
                                    .foregroundColor(.cakeGrey)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(Color(red: 0.97, green: 0.96, blue: 0.94))
                            
                            VStack(spacing: 12) {
                                ForEach(reviews) { review in
                                    reviewRow(review)
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.urbanistMedium(15))
                        }
                        .foregroundColor(.cakeBrown)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Reviews")
                        .font(.urbanistBold(18))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                }
            }
        }
        .task {
            await loadReviews()
        }
    }
    
    private func reviewRow(_ review: Review) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Customer info and rating
            HStack(spacing: 10) {
                // Customer avatar
                ZStack {
                    Circle()
                        .fill(Color.cakeBrown.opacity(0.12))
                        .frame(width: 40, height: 40)
                    
                    if let imageURL = review.customerImage, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            default:
                                Text(String(review.customerName.prefix(1)).uppercased())
                                    .font(.urbanistSemiBold(16))
                                    .foregroundColor(.cakeBrown)
                            }
                        }
                    } else {
                        Text(String(review.customerName.prefix(1)).uppercased())
                            .font(.urbanistSemiBold(16))
                            .foregroundColor(.cakeBrown)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.customerName)
                        .font(.urbanistSemiBold(13))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    
                    HStack(spacing: 3) {
                        ForEach(0..<review.rating, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.2))
                        }
                        ForEach(review.rating..<5, id: \.self) { _ in
                            Image(systemName: "star")
                                .font(.system(size: 11))
                                .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.2))
                        }
                    }
                }
                
                Spacer()
                
                Text(review.formattedDate)
                    .font(.urbanistRegular(11))
                    .foregroundColor(.cakeGrey)
            }
            
            // Review comment
            if !review.comment.isEmpty {
                Text(review.comment)
                    .font(.urbanistRegular(13))
                    .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .background(Color(red: 0.97, green: 0.96, blue: 0.94))
        .cornerRadius(12)
    }
    
    private func loadReviews() async {
        isLoading = true
        defer { isLoading = false }
        
        let db = Firestore.firestore()
        
        do {
            let query = db.collection("reviews")
                .whereField("bakerID", isEqualTo: user.id)
                .order(by: "createdAt", descending: true)
            
            let snapshot = try await query.getDocuments()
            reviews = snapshot.documents.compactMap { Review(document: $0) }
        } catch {
            print("Error loading reviews: \(error.localizedDescription)")
            reviews = []
        }
    }
}

#Preview {
    BakerReviewsView(user: AppUser(
        id: "123",
        email: "baker@test.com",
        name: "Test Baker",
        role: .baker,
        avatarURL: nil,
        createdAt: Date(),
        address: "123 Main St",
        city: "Colombo"
    ))
}
