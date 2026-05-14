import SwiftUI
import UIKit

// MARK: - BakerReviewsView
struct BakerReviewsView: View {
    let user: AppUser
    @StateObject private var vm = BakerReviewsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.cakeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                content
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await vm.loadReviews(for: user)
        }
        .refreshable {
            await vm.loadReviews(for: user)
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
        .background(Color.cakeSurface)
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.cakeBrown)
                Text("Loading reviews...")
                    .font(.urbanistRegular(14))
                    .foregroundColor(.cakeGrey)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.reviews.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "star.slash")
                    .font(.system(size: 48))
                    .foregroundColor(.cakeBrown.opacity(0.3))
                Text("No Reviews Yet")
                    .font(.urbanistBold(18))
                    .foregroundColor(.cakePrimaryText)
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
                        ForEach(vm.reviews) { review in
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
                    Image(systemName: index < Int(vm.averageRating.rounded()) ? "star.fill" : "star")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.2))
                }
            }

            Text(String(format: "%.1f", vm.averageRating))
                .font(.urbanistBold(32))
                .foregroundColor(Color.cakeBrown)

            Text("Based on \(vm.reviews.count) review\(vm.reviews.count == 1 ? "" : "s")")
                .font(.urbanistRegular(13))
                .foregroundColor(.cakeGrey)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }

    private func reviewRow(_ review: Review) -> some View {
        let customer = vm.resolvedCustomer(for: review)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                customerAvatar(name: customer.name, imageReference: customer.imageReference)

                Text(customer.name)
                    .font(.urbanistSemiBold(14))
                    .foregroundColor(.cakePrimaryText)
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
        .background(Color.cakeSurface)
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
