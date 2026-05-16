import SwiftUI
import FirebaseFirestore
import UIKit
import Combine

// MARK: - Customer Public Baker Profile View
@MainActor
struct CustomerPublicBakerProfileView: View {
    let bakerID: String
    let fallbackName: String
    let fallbackProfileImageBase64: String
    let fallbackImageURL: String
    let fallbackAddress: String
    let fallbackCity: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CustomerPublicBakerProfileViewModel()
    @State private var selectedPortfolioWork: PortfolioPreviewWork?
    @State private var showReviews = false

    init(
        bakerID: String,
        fallbackName: String = "",
        fallbackProfileImageBase64: String = "",
        fallbackImageURL: String = "",
        fallbackAddress: String = "",
        fallbackCity: String = ""
    ) {
        self.bakerID = bakerID
        self.fallbackName = fallbackName
        self.fallbackProfileImageBase64 = fallbackProfileImageBase64
        self.fallbackImageURL = fallbackImageURL
        self.fallbackAddress = fallbackAddress
        self.fallbackCity = fallbackCity
    }

    private var profile: BakerProfileData { viewModel.profileData }
    private var locationText: String {
        let display = SriLankaDistricts.displayLocation(address: profile.address, city: profile.city)
        return display.isEmpty ? "No address added" : display
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cakeBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    profileHeaderBar

                    if viewModel.isLoading {
                        ProgressView("Loading baker profile...")
                            .tint(.cakeBrown)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 18) {
                                headerSection
                                statsSection
                                specialtiesSection
                                aboutSection
                                portfolioSection
                            }
                            .padding(.bottom, 28)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            await viewModel.load(
                bakerID: bakerID,
                fallbackName: fallbackName,
                fallbackProfileImageBase64: fallbackProfileImageBase64,
                fallbackImageURL: fallbackImageURL,
                fallbackAddress: fallbackAddress,
                fallbackCity: fallbackCity
            )
        }
        .sheet(item: $selectedPortfolioWork) { work in
            // Portfolio detail sheet opened from portfolio photo.
            CustomerPortfolioPreviewDetailSheet(work: work)
        }
        .sheet(isPresented: $showReviews) {
            // Reviews sheet opened from Reviews stat.
            CustomerPublicBakerReviewsSheet(
                bakerName: profile.shopName.isEmpty ? fallbackName : profile.shopName,
                reviews: viewModel.reviews,
                customerProfiles: viewModel.customerProfiles
            )
        }
    }

    // MARK: - Header
    private var profileHeaderBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cakeBrown)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Baker Profile")
                .font(.urbanistBold(18))
                .foregroundColor(Color(hex: "5D3714"))

            Spacer()

            Color.clear.frame(width: 24, height: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.cakeSurface)
    }

    // MARK: - Baker Cover and Profile Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                coverImage
                    .frame(height: 190)
                    .clipped()

                HStack(alignment: .bottom) {
                    profileImage
                    Spacer()
                    statusBadge
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 22)
                .offset(y: 42)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(profile.shopName.isEmpty ? fallbackName : profile.shopName)
                    .font(.urbanistBold(22))
                    .foregroundColor(.cakePrimaryText)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 11, weight: .medium))
                    Text(locationText)
                        .font(.urbanistRegular(12))
                        .lineLimit(2)
                }
                .foregroundColor(.cakeGrey)
            }
            .padding(.horizontal, 22)
            .padding(.top, 52)
            .padding(.bottom, 6)
        }
        .background(Color.cakeSurface)
    }

    // MARK: - Cover Image
    private var coverImage: some View {
        Group {
            if let image = decodeBase64Image(profile.coverImageBase64) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let url = URL(string: profile.coverImageURL), !profile.coverImageURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: coverFallback
                    }
                }
            } else {
                coverFallback
            }
        }
    }

    private var coverFallback: some View {
        LinearGradient(
            colors: [Color.cakeBrown.opacity(0.16), Color(red: 0.96, green: 0.93, blue: 0.89)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "photo")
                .font(.system(size: 30, weight: .medium))
                .foregroundColor(.cakeBrown.opacity(0.35))
        )
    }

    // MARK: - Profile Image
    private var profileImage: some View {
        ZStack {
            Circle()
                .fill(Color.cakeSurface)
                .frame(width: 110, height: 110)
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)

            Group {
                if let image = decodeBase64Image(profile.profileImageBase64) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else if let url = URL(string: profile.profileImageURL), !profile.profileImageURL.isEmpty {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        default: avatarFallback
                        }
                    }
                } else {
                    avatarFallback
                }
            }
            .frame(width: 98, height: 98)
            .clipShape(Circle())
        }
    }

    private var avatarFallback: some View {
        Circle()
            .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 34))
                    .foregroundColor(.cakeBrown.opacity(0.55))
            )
    }

    private var statusBadge: some View {
        Text(profile.isOnline ? "Active" : "Inactive")
            .font(.urbanistMedium(12))
            .foregroundColor(profile.isOnline ? Color(red: 0.12, green: 0.58, blue: 0.29) : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(profile.isOnline ? Color(red: 0.82, green: 0.95, blue: 0.86) : Color(hex: "D22B2B"))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Profile Stats Card
    private var statsSection: some View {
        HStack(spacing: 0) {
            publicStat(value: "\(profile.completedOrders)", label: "Completed\nOrders")
            Divider().frame(height: 40)
            Button {
                showReviews = true
            } label: {
                publicStat(value: "\(profile.reviewCount)", label: "Reviews")
            }
            .buttonStyle(.plain)
            Divider().frame(height: 40)
            publicStat(value: String(format: "%.1f", profile.rating), label: "Avg Rating")
            Divider().frame(height: 40)
            publicStat(value: "98%", label: "On-Time")
        }
        .padding(.vertical, 16)
        .background(Color.cakeSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
        .padding(.horizontal, 20)
    }

    private func publicStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.urbanistBold(18))
                .foregroundColor(Color.cakeBrown)
                .frame(height: 22)
            Text(label)
                .font(.urbanistRegular(11))
                .foregroundColor(.cakeGrey)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 28, alignment: .top)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Specialities Card
    private var specialtiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Specialities")
                .font(.urbanistBold(16))
                .foregroundColor(.cakePrimaryText)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(profile.specialties, id: \.self) { specialty in
                    Text(specialty)
                        .font(.urbanistMedium(12))
                        .foregroundColor(Color(hex: "5D3714"))
                        .lineLimit(2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "F8F6F3"))
                        .clipShape(Capsule())
                }
            }
        }
        .sectionCard()
    }

    // MARK: - About Card
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About Me")
                .font(.urbanistBold(16))
                .foregroundColor(.cakePrimaryText)
            Text(profile.about)
                .font(.urbanistRegular(14))
                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                .lineSpacing(4)
        }
        .sectionCard()
    }

    // MARK: - Portfolio Card
    private var portfolioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Portfolio")
                .font(.urbanistBold(16))
                .foregroundColor(.cakePrimaryText)

            if profile.portfolioWorks.isEmpty {
                Text("No portfolio works added yet.")
                    .font(.urbanistRegular(13))
                    .foregroundColor(.cakeGrey)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                    ForEach(profile.portfolioWorks) { work in
                        Button {
                            // Open portfolio work details.
                            selectedPortfolioWork = work
                        } label: {
                            portfolioImage(work)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sectionCard()
    }

    private func portfolioImage(_ work: PortfolioPreviewWork) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let image = decodeBase64Image(work.imageReference) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let url = URL(string: work.imageReference), !work.imageReference.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: portfolioFallback
                    }
                }
            } else {
                portfolioFallback
            }

            Text(work.title)
                .font(.urbanistSemiBold(11))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.35))
        }
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var portfolioFallback: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
            .overlay(
                Image(systemName: "birthday.cake.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.cakeBrown.opacity(0.45))
            )
    }

    private func decodeBase64Image(_ rawBase64: String) -> UIImage? {
        let trimmed = rawBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let payload = trimmed.components(separatedBy: ",").last ?? trimmed
        guard let data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters) else { return nil }
        return UIImage(data: data)
    }
}

private extension View {
    func sectionCard() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cakeSurface)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 20)
    }
}

// MARK: - Portfolio Detail Sheet
private struct CustomerPortfolioPreviewDetailSheet: View {
    let work: PortfolioPreviewWork
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.cakeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Portfolio image, title, description, and traits.
                        CustomerPortfolioWorkImageView(imageReference: work.imageReference, height: 170)

                        Text(work.title)
                            .font(.urbanistBold(17))
                            .foregroundColor(Color(hex: "5D3714"))

                        if !work.description.isEmpty {
                            Text(work.description)
                                .font(.urbanistRegular(13))
                                .foregroundColor(.cakeGrey)
                                .lineSpacing(3)
                        }

                        if !work.traits.isEmpty {
                            VStack(spacing: 10) {
                                ForEach(work.traits) { trait in
                                    PortfolioTraitBar(trait: trait)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(18)
                    .background(Color.cakeSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                    .padding(20)
                }
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

            Text("Portfolio Work")
                .font(.urbanistBold(18))
                .foregroundColor(Color(hex: "5D3714"))

            Spacer()

            Color.clear.frame(width: 24, height: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.cakeSurface)
    }
}

// MARK: - Portfolio Image View
private struct CustomerPortfolioWorkImageView: View {
    let imageReference: String
    let height: CGFloat

    var body: some View {
        Group {
            if let image = decodeBase64Image(imageReference) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = URL(string: imageReference), !imageReference.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var fallback: some View {
        LinearGradient(
            colors: [
                Color(red: 0.94, green: 0.88, blue: 0.82),
                Color(red: 0.88, green: 0.80, blue: 0.73)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "birthday.cake.fill")
                .font(.system(size: 34))
                .foregroundColor(.white.opacity(0.9))
        )
    }

    private func decodeBase64Image(_ rawBase64: String) -> UIImage? {
        let trimmed = rawBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let payload = trimmed.components(separatedBy: ",").last ?? trimmed
        guard let data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - Public Baker Reviews Sheet
private struct CustomerPublicBakerReviewsSheet: View {
    let bakerName: String
    let reviews: [Review]
    let customerProfiles: [String: ReviewCustomerProfile]
    @Environment(\.dismiss) private var dismiss

    private var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        return Double(reviews.reduce(0) { $0 + $1.rating }) / Double(reviews.count)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.cakeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                content
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
            .buttonStyle(.plain)

            Spacer()

            Text("Reviews")
                .font(.urbanistBold(18))
                .foregroundColor(Color(hex: "5D3714"))

            Spacer()

            Color.clear.frame(width: 24, height: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.cakeSurface)
    }

    @ViewBuilder
    private var content: some View {
        if reviews.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "star.slash")
                    .font(.system(size: 48))
                    .foregroundColor(.cakeBrown.opacity(0.3))

                Text("No Reviews Yet")
                    .font(.urbanistBold(18))
                    .foregroundColor(.cakePrimaryText)

                Text("\(bakerName.isEmpty ? "This baker" : bakerName) has not received customer reviews yet.")
                    .font(.urbanistRegular(14))
                    .foregroundColor(.cakeGrey)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    averageRatingHeader

                    VStack(spacing: 12) {
                        ForEach(reviews) { review in
                            reviewRow(review)
                        }
                    }
                    .padding(16)

                    Spacer().frame(height: 24)
                }
            }
        }
    }

    private var averageRatingHeader: some View {
        // Average rating summary at top of reviews sheet.
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
        // Individual customer review card.
        let customer = resolvedCustomer(for: review)
        let rating = min(max(review.rating, 0), 5)

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
                    ForEach(0..<rating, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.2))
                    }
                    ForEach(rating..<5, id: \.self) { _ in
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

    private func resolvedCustomer(for review: Review) -> ReviewCustomerProfile {
        let profile = customerProfiles[review.customerID]
        return ReviewCustomerProfile(
            name: firstString(profile?.name, review.customerName, "Customer"),
            imageReference: firstString(profile?.imageReference, review.customerImage)
        )
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
            } else if let url = URL(string: imageReference), !imageReference.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    default:
                        customerInitial(name)
                    }
                }
            } else {
                customerInitial(name)
            }
        }
    }

    private func customerInitial(_ name: String) -> some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.urbanistSemiBold(16))
            .foregroundColor(.cakeBrown)
    }

    private func decodedCustomerImage(_ rawBase64: String) -> UIImage? {
        let trimmed = rawBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let payload = trimmed.components(separatedBy: ",").last ?? trimmed
        guard let data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters) else { return nil }
        return UIImage(data: data)
    }

    private func firstString(_ values: Any?...) -> String {
        values.compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }
}

// MARK: - Customer Public Baker Profile ViewModel
@MainActor
final class CustomerPublicBakerProfileViewModel: ObservableObject {
    @Published var profileData: BakerProfileData = .empty
    @Published var isLoading = true
    @Published var reviews: [Review] = []
    @Published var customerProfiles: [String: ReviewCustomerProfile] = [:]

    private let db = Firestore.firestore()

    func load(
        bakerID: String,
        fallbackName: String,
        fallbackProfileImageBase64: String = "",
        fallbackImageURL: String = "",
        fallbackAddress: String = "",
        fallbackCity: String = ""
    ) async {
        // Load public profile, portfolio, reviews, and completed order count.
        isLoading = true
        defer { isLoading = false }

        let trimmedID = bakerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else {
            profileData = fallbackProfile(
                name: fallbackName,
                profileImageBase64: fallbackProfileImageBase64,
                imageURL: fallbackImageURL,
                address: fallbackAddress,
                city: fallbackCity
            )
            reviews = []
            customerProfiles = [:]
            return
        }

        do {
            let artisanSnapshot = try await loadArtisanDocument(bakerID: trimmedID)
            let artisanData = artisanSnapshot.data() ?? [:]
            let resolvedUserID = firstString(artisanData["uid"], artisanData["userID"], artisanData["userId"], trimmedID)
            let userSnapshot = try? await db.collection("users").document(resolvedUserID).getDocument()
            let userData = userSnapshot?.data() ?? [:]
            let lookupIDs = Array(Set([trimmedID, resolvedUserID].filter { !$0.isEmpty }))
            let portfolioWorks = try await fetchPublishedPortfolioWorks(
                artisanDocumentID: artisanSnapshot.documentID,
                fallbackBakerID: trimmedID,
                artisanData: artisanData
            )
            let reviews = try await fetchReviews(bakerIDs: lookupIDs)
            self.reviews = reviews
            self.customerProfiles = await loadCustomerProfiles(for: reviews)
            let completedCount = await fetchCompletedOrdersCount(bakerIDs: lookupIDs)
            let averageRating = reviews.isEmpty
                ? parseDouble(artisanData["rating"])
                : Double(reviews.reduce(0) { $0 + $1.rating }) / Double(reviews.count)
            let reviewCount = reviews.isEmpty ? parseInt(artisanData["reviewCount"]) : reviews.count
            let rawCity = firstString(artisanData["city"], userData["city"], fallbackCity)

            profileData = BakerProfileData(
                shopName: firstString(artisanData["shopName"], artisanData["name"], userData["name"], fallbackName, "Baker Shop"),
                address: firstString(artisanData["address"], artisanData["location"], userData["address"], fallbackAddress),
                city: SriLankaDistricts.canonical(rawCity) ?? rawCity,
                isOnline: artisanData["isOnline"] as? Bool ?? true,
                rating: averageRating,
                reviewCount: reviewCount,
                completedOrders: completedCount,
                about: firstString(artisanData["about"], artisanData["bio"], userData["about"], userData["bio"], "No profile description added yet."),
                createdAt: parseDate(artisanData["createdAt"]) ?? parseDate(userData["createdAt"]) ?? Date(),
                specialties: resolveSpecialties(artisanData: artisanData),
                profileImageURL: firstString(artisanData["profileImageURL"], artisanData["imageURL"], artisanData["avatarURL"], userData["imageURL"], userData["avatarURL"], fallbackImageURL),
                profileImageBase64: firstString(artisanData["profileImageBase64"], userData["profileImageBase64"], fallbackProfileImageBase64),
                coverImageURL: firstString(artisanData["coverImageURL"]),
                coverImageBase64: firstString(artisanData["coverImageBase64"]),
                portfolioWorks: portfolioWorks
            )
        } catch {
            print("ERROR CustomerPublicBakerProfileViewModel.load: \(error.localizedDescription)")
            profileData = fallbackProfile(
                name: fallbackName,
                profileImageBase64: fallbackProfileImageBase64,
                imageURL: fallbackImageURL,
                address: fallbackAddress,
                city: fallbackCity
            )
            reviews = []
            customerProfiles = [:]
        }
    }

    private func fallbackProfile(
        name: String,
        profileImageBase64: String,
        imageURL: String,
        address: String,
        city: String
    ) -> BakerProfileData {
        BakerProfileData(
            shopName: firstString(name, "Baker Shop"),
            address: firstString(address, "No address added"),
            city: SriLankaDistricts.canonical(city) ?? city,
            isOnline: true,
            rating: 0,
            reviewCount: 0,
            completedOrders: 0,
            about: "No profile description added yet.",
            createdAt: Date(),
            specialties: ["Custom Cakes"],
            profileImageURL: imageURL,
            profileImageBase64: profileImageBase64,
            coverImageURL: "",
            coverImageBase64: "",
            portfolioWorks: []
        )
    }

    private func loadArtisanDocument(bakerID: String) async throws -> DocumentSnapshot {
        let direct = try await db.collection("artisans").document(bakerID).getDocument()
        if direct.exists { return direct }

        let query = try await db.collection("artisans")
            .whereField("uid", isEqualTo: bakerID)
            .limit(to: 1)
            .getDocuments()

        return query.documents.first ?? direct
    }

    private func fetchCompletedOrdersCount(bakerIDs: [String]) async -> Int {
        let statuses = ["completed", "delivered", "done"]
        var ids = Set<String>()

        for bakerID in bakerIDs {
            for key in ["bakerID", "bakerId", "artisanId"] {
                do {
                    let snapshot = try await db.collection("orders")
                        .whereField(key, isEqualTo: bakerID)
                        .whereField("status", in: statuses)
                        .getDocuments()
                    ids.formUnion(snapshot.documents.map(\.documentID))
                } catch {
                    print("Unable to load public baker completed orders by \(key): \(error.localizedDescription)")
                }
            }
        }

        return ids.count
    }

    private func fetchReviews(bakerIDs: [String]) async throws -> [Review] {
        var reviewsByID: [String: Review] = [:]
        for bakerID in bakerIDs {
            for key in ["bakerID", "bakerId", "artisanId"] {
                do {
                    let snapshot = try await db.collection("reviews")
                        .whereField(key, isEqualTo: bakerID)
                        .getDocuments()
                    for document in snapshot.documents {
                        if let review = Review(document: document) {
                            reviewsByID[review.id] = review
                        }
                    }
                } catch {
                    print("Unable to load public baker reviews by \(key): \(error.localizedDescription)")
                }
            }
        }
        return reviewsByID.values.sorted { $0.createdAt > $1.createdAt }
    }

    private func loadCustomerProfiles(for reviews: [Review]) async -> [String: ReviewCustomerProfile] {
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
                print("Unable to load public review customer \(customerID): \(error.localizedDescription)")
            }
        }

        return profiles
    }

    private func fetchPublishedPortfolioWorks(artisanDocumentID: String, fallbackBakerID: String, artisanData: [String: Any]) async throws -> [PortfolioPreviewWork] {
        let profileDocumentID = artisanDocumentID.isEmpty ? fallbackBakerID : artisanDocumentID
        let publishedIDs = artisanData["portfolioPublishedWorkIDs"] as? [String] ?? []
        if !publishedIDs.isEmpty {
            var worksByID: [String: PortfolioPreviewWork] = [:]
            for workID in publishedIDs.prefix(6) {
                let document = try await db.collection("artisans")
                    .document(profileDocumentID)
                    .collection("portfolioWorks")
                    .document(workID)
                    .getDocument()
                if let work = PortfolioPreviewWork(document: document) {
                    worksByID[workID] = work
                }
            }
            let ordered = publishedIDs.compactMap { worksByID[$0] }
            if !ordered.isEmpty { return Array(ordered.prefix(6)) }
        }

        let snapshot = try await db.collection("artisans")
            .document(profileDocumentID)
            .collection("portfolioWorks")
            .whereField("isPublished", isEqualTo: true)
            .limit(to: 6)
            .getDocuments()

        let works = snapshot.documents.compactMap(PortfolioPreviewWork.init(document:))
        if !works.isEmpty { return works.sorted { $0.updatedAt > $1.updatedAt } }

        let legacyWorks = artisanData["publishedPortfolioWorks"] as? [[String: Any]] ?? []
        return legacyWorks.compactMap(PortfolioPreviewWork.init(dictionary:))
    }

    private func resolveSpecialties(artisanData: [String: Any]) -> [String] {
        let specialties = (artisanData["specialties"] as? [String] ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return specialties.isEmpty ? ["Custom Cakes"] : specialties
    }

    private func firstString(_ values: Any?...) -> String {
        values.compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    private func parseDouble(_ value: Any?) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0 }
        return 0
    }

    private func parseInt(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0 }
        return 0
    }

    private func parseDate(_ value: Any?) -> Date? {
        if let timestamp = value as? Timestamp { return timestamp.dateValue() }
        if let date = value as? Date { return date }
        return nil
    }
}
