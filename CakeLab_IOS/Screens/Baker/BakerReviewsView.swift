import SwiftUI
import FirebaseFirestore
import UIKit

struct BakerReviewsView: View {
    let user: AppUser
    @State private var reviews: [Review] = []
    @State private var customerProfiles: [String: ReviewCustomerProfile] = [:]
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss
    
    var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        return Double(reviews.reduce(0) { $0 + $1.rating }) / Double(reviews.count)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                content
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadReviews()
        }
        .refreshable {
            await loadReviews()
        }
        .asBakerSubScreen()
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
                Text("Reviews")
                    .font(.urbanistBold(18))
                    .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
            }
            Spacer()
            Color.white.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.white)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.cakeBrown)
                Text("Loading reviews...")
                    .font(.urbanistRegular(14))
                    .foregroundColor(.cakeGrey)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    .padding(.horizontal, 36)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    averageRatingHeader

                    VStack(spacing: 12) {
                        ForEach(reviews) { review in
                            reviewRow(review)
                        }
                    }
                    .padding(16)

                    Spacer().frame(height: 104)
                }
            }
        }
    }

    private var averageRatingHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    Image(systemName: index < Int(averageRating.rounded()) ? "star.fill" : "star")
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
    }

    private func reviewRow(_ review: Review) -> some View {
        let customer = resolvedCustomer(for: review)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                customerAvatar(name: customer.name, imageReference: customer.imageReference)

                Text(customer.name)
                    .font(.urbanistSemiBold(14))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !review.comment.isEmpty {
                Text(review.comment)
                    .font(.urbanistRegular(13))
                    .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
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

                Spacer()

                Text(review.formattedDate)
                    .font(.urbanistRegular(11))
                    .foregroundColor(.cakeGrey)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private func customerAvatar(name: String, imageReference: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.cakeBrown.opacity(0.12))
                .frame(width: 40, height: 40)

            if let image = decodedCustomerImage(imageReference) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else if let url = URL(string: imageReference) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    default:
                        Text(String(name.prefix(1)).uppercased())
                            .font(.urbanistSemiBold(16))
                            .foregroundColor(.cakeBrown)
                    }
                }
            } else {
                Text(String(name.prefix(1)).uppercased())
                    .font(.urbanistSemiBold(16))
                    .foregroundColor(.cakeBrown)
            }
        }
        .frame(width: 40, height: 40)
    }
    
    private func loadReviews() async {
        isLoading = true
        defer { isLoading = false }
        
        let db = Firestore.firestore()
        
        var reviewsByID: [String: Review] = [:]

        for key in ["bakerID", "bakerId", "artisanId"] {
            do {
                let snapshot = try await db.collection("reviews")
                    .whereField(key, isEqualTo: user.id)
                    .getDocuments()

                for document in snapshot.documents {
                    if let review = Review(document: document) {
                        reviewsByID[review.id] = review
                    }
                }
            } catch {
                print("Error loading reviews by \(key): \(error.localizedDescription)")
            }
        }

        let loadedReviews = reviewsByID.values.sorted { $0.createdAt > $1.createdAt }
        reviews = loadedReviews
        customerProfiles = await loadCustomerProfiles(for: loadedReviews, db: db)
    }

    private func loadCustomerProfiles(for reviews: [Review], db: Firestore) async -> [String: ReviewCustomerProfile] {
        var profiles: [String: ReviewCustomerProfile] = [:]
        let customerIDs = Set(reviews.map(\.customerID).filter { !$0.isEmpty })

        for customerID in customerIDs {
            do {
                let document = try await db.collection("users").document(customerID).getDocument()
                let data = document.data() ?? [:]
                profiles[customerID] = ReviewCustomerProfile(
                    name: firstString(data["name"], data["fullName"], data["displayName"], data["email"]),
                    imageReference: firstString(
                        data["profileImageBase64"],
                        data["avatarBase64"],
                        data["photoBase64"],
                        data["imageURL"],
                        data["avatarURL"],
                        data["photoURL"]
                    )
                )
            } catch {
                print("Error loading review customer \(customerID): \(error.localizedDescription)")
            }
        }

        return profiles
    }

    private func resolvedCustomer(for review: Review) -> ReviewCustomerProfile {
        let profile = customerProfiles[review.customerID]
        return ReviewCustomerProfile(
            name: firstString(profile?.name, review.customerName, "Customer"),
            imageReference: firstString(profile?.imageReference, review.customerImage)
        )
    }

    private func decodedCustomerImage(_ rawImage: String?) -> UIImage? {
        guard let rawImage else { return nil }
        let trimmed = rawImage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let payload: String
        if let commaIndex = trimmed.firstIndex(of: ",") {
            payload = String(trimmed[trimmed.index(after: commaIndex)...])
        } else {
            payload = trimmed
        }

        guard let data = Data(base64Encoded: payload) else { return nil }
        return UIImage(data: data)
    }

    private func firstString(_ values: Any?...) -> String {
        values.compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }
}

private struct ReviewCustomerProfile {
    let name: String
    let imageReference: String
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
