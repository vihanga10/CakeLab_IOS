import SwiftUI
import Charts
import FirebaseFirestore
import FirebaseAuth

// MARK: - Baker Profile View (Tab 3 — Portfolio)
@MainActor
struct BakerProfileView: View {
    let user: AppUser
    @State private var profileData = BakerProfileData.empty
    @State private var isLoading = true

    private var completedOrdersText: String { "\(profileData.completedOrders)" }
    private var reviewsText: String { "\(profileData.reviewCount)" }
    private var avgRatingText: String { String(format: "%.1f", profileData.rating) }
    private var memberSinceText: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: profileData.createdAt)
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // MARK: Profile Header
                    profileHeaderSection
                        .padding(.bottom, 16)

                    // MARK: Stats Row
                    statsRow
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    // MARK: Category Tags
                    categoryTagsSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    // MARK: About / Bio
                    bioSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    // MARK: Portfolio Gallery
                    portfolioSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    // MARK: Performance Charts
                    performanceSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    // MARK: Earnings Summary
                    earningsSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    // MARK: Settings
                    settingsSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                }
            }
        }
        .task {
            await loadProfileData()
        }
    }

    // MARK: - Profile Header
    private var profileHeaderSection: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                coverImage
                    .frame(height: 210)
                    .clipped()

                HStack(alignment: .bottom) {
                    profileAvatar
                    Spacer()
                    activeBadge
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 24)
                .offset(y: 42)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(profileData.shopName)
                    .font(.urbanistSemiBold(30))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 11, weight: .medium))
                    Text(profileData.address)
                        .font(.urbanistRegular(12))
                        .lineLimit(2)
                }
                .foregroundColor(.cakeGrey)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 52)
        }
    }

    private var coverImage: some View {
        Group {
            if let url = URL(string: profileData.coverImageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: Image("splash1").resizable().scaledToFill()
                    }
                }
            } else {
                Image("splash1")
                    .resizable()
                    .scaledToFill()
            }
        }
    }

    private var profileAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 110, height: 110)
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)

            if let url = URL(string: profileData.profileImageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 102, height: 102)
                            .clipShape(Circle())
                    default:
                        avatarFallback
                    }
                }
            } else {
                avatarFallback
            }
        }
    }

    private var avatarFallback: some View {
        Circle()
            .fill(Color.cakeBrown.opacity(0.16))
            .frame(width: 102, height: 102)
            .overlay(
                Text(String(profileData.shopName.prefix(1)).uppercased())
                    .font(.urbanistBold(34))
                    .foregroundColor(.cakeBrown)
            )
    }

    private var activeBadge: some View {
        Text("Active")
            .font(.urbanistMedium(12))
            .foregroundColor(Color(red: 0.12, green: 0.58, blue: 0.29))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(red: 0.82, green: 0.95, blue: 0.86))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(profileData.isOnline ? 1 : 0.55)
    }

    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 0) {
            profileStatItem(value: completedOrdersText, label: "Completed \n   Orders")
            Divider().frame(height: 40)
            profileStatItem(value: reviewsText, label: "Reviews")
            Divider().frame(height: 40)
            profileStatItem(value: avgRatingText, label: "Avg Rating")
            Divider().frame(height: 40)
            profileStatItem(value: "98%", label: "On-Time")
        }
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
    }

    private func profileStatItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.urbanistBold(18))
                .foregroundColor(Color.cakeBrown)
            Text(label)
                .font(.urbanistRegular(11))
                .foregroundColor(.cakeGrey)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bio Section
    private var bioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About Me :")
                .font(.urbanistBold(16))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

            Text(profileData.about)
                .font(.urbanistRegular(14))
                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                .lineSpacing(4)

            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                Text("Member since \(memberSinceText)")
                    .font(.urbanistRegular(12))
                Spacer()
            }
            .foregroundColor(.cakeGrey)
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: - Category Tags
    private var categoryTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Specialities")
                    .font(.urbanistBold(16))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                Spacer()
            }

    

            PastelTagFlowLayout(tags: profileData.specialties)
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
    }

    // MARK: - Portfolio Gallery
    private var portfolioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Portfolio :")
                    .font(.urbanistBold(16))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                Spacer()
                Text("6 photos")
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeGrey)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(profileData.portfolioImages.prefix(6), id: \.self) { imageRef in
                    PortfolioThumbnail(imageRef: imageRef)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
    }

    private func loadProfileData() async {
        isLoading = true
        defer { isLoading = false }

        let db = Firestore.firestore()

        do {
            let artisanSnapshot = try await loadArtisanDocument(db: db, userID: user.id)
            let artisanData = artisanSnapshot.data() ?? [:]

            let statuses = ["completed", "delivered", "done"]
            var completedCount = 0
            for key in ["bakerID", "bakerId"] {
                if let count = try? await db.collection("orders")
                    .whereField(key, isEqualTo: user.id)
                    .whereField("status", in: statuses)
                    .count
                    .getAggregation(source: .server)
                    .count {
                    completedCount = max(completedCount, Int(truncating: count))
                }
            }

            profileData = BakerProfileData(
                shopName: resolveShopName(artisanData: artisanData),
                address: resolveAddress(artisanData: artisanData),
                isOnline: artisanData["isOnline"] as? Bool ?? true,
                rating: artisanData["rating"] as? Double ?? 0,
                reviewCount: artisanData["reviewCount"] as? Int ?? 0,
                completedOrders: completedCount,
                about: resolveAbout(artisanData: artisanData),
                createdAt: resolveCreatedAt(artisanData: artisanData),
                specialties: resolveSpecialties(artisanData: artisanData),
                profileImageURL: resolveProfileImageURL(artisanData: artisanData),
                coverImageURL: artisanData["coverImageURL"] as? String ?? "",
                portfolioImages: resolvePortfolioImages(artisanData: artisanData)
            )
        } catch {
            print("ERROR BakerProfileView.loadProfileData: \(error.localizedDescription)")
            profileData = BakerProfileData.empty
        }
    }

    private func loadArtisanDocument(db: Firestore, userID: String) async throws -> DocumentSnapshot {
        let direct = try await db.collection("artisans").document(userID).getDocument()
        if direct.exists { return direct }

        let query = try await db.collection("artisans")
            .whereField("uid", isEqualTo: userID)
            .limit(to: 1)
            .getDocuments()

        if let first = query.documents.first {
            return first
        }

        return direct
    }

    private func resolveShopName(artisanData: [String: Any]) -> String {
        let options = [artisanData["shopName"] as? String, artisanData["name"] as? String, user.name]
        return options.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first(where: { !$0.isEmpty }) ?? "Baker Shop"
    }

    private func resolveAddress(artisanData: [String: Any]) -> String {
        let options = [artisanData["location"] as? String, artisanData["address"] as? String, user.address, user.city]
        return options.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first(where: { !$0.isEmpty }) ?? "No address added"
    }

    private func resolveAbout(artisanData: [String: Any]) -> String {
        let options = [artisanData["about"] as? String, artisanData["bio"] as? String, artisanData["description"] as? String]
        return options.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first(where: { !$0.isEmpty }) ?? "No profile description added yet."
    }

    private func resolveCreatedAt(artisanData: [String: Any]) -> Date {
        if let ts = artisanData["createdAt"] as? Timestamp {
            return ts.dateValue()
        }
        return user.createdAt
    }

    private func resolveSpecialties(artisanData: [String: Any]) -> [String] {
        let values = artisanData["specialties"] as? [String] ?? []
        return values.isEmpty ? ["Custom Cakes"] : values
    }

    private func resolveProfileImageURL(artisanData: [String: Any]) -> String {
        if let imageURL = artisanData["imageURL"] as? String, !imageURL.isEmpty { return imageURL }
        return user.avatarURL ?? ""
    }

    private func resolvePortfolioImages(artisanData: [String: Any]) -> [String] {
        let urls = artisanData["portfolioImages"] as? [String] ?? artisanData["portfolioURLs"] as? [String] ?? []
        if urls.count >= 6 { return Array(urls.prefix(6)) }

        var output = urls
        let fallback = ["cake.portrait.1", "cake.portrait.2", "cake.portrait.3", "cake.portrait.4", "cake.portrait.5", "cake.portrait.6"]
        for item in fallback where output.count < 6 {
            output.append(item)
        }
        return output
    }

    // MARK: - Performance Charts
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Performance", systemImage: "chart.bar.fill")
                .font(.urbanistBold(16))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

            // Monthly orders chart
            VStack(alignment: .leading, spacing: 8) {
                Text("Monthly Orders")
                    .font(.urbanistSemiBold(13))
                    .foregroundColor(.cakeGrey)

                Chart(monthlyOrderData) { item in
                    BarMark(
                        x: .value("Month", item.month),
                        y: .value("Orders", item.count)
                    )
                    .foregroundStyle(Color.cakeBrown.gradient)
                    .cornerRadius(6)
                }
                .frame(height: 140)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(.urbanistRegular(10))
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                            .font(.urbanistRegular(10))
                    }
                }
            }

            // Rating breakdown
            VStack(alignment: .leading, spacing: 8) {
                Text("Rating Breakdown")
                    .font(.urbanistSemiBold(13))
                    .foregroundColor(.cakeGrey)

                ForEach(ratingBreakdown.reversed(), id: \.stars) { item in
                    HStack(spacing: 10) {
                        HStack(spacing: 2) {
                            Text("\(item.stars)")
                                .font(.urbanistMedium(12))
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.2))
                        }
                        .frame(width: 30)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.cakeBrown.opacity(0.1))
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.cakeBrown)
                                    .frame(width: geo.size.width * item.fraction, height: 8)
                            }
                        }
                        .frame(height: 8)
                        Text("\(item.count)")
                            .font(.urbanistRegular(12))
                            .foregroundColor(.cakeGrey)
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: - Earnings Summary
    private var earningsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Earnings Summary", systemImage: "banknote.fill")
                .font(.urbanistBold(16))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

            HStack(spacing: 12) {
                earningCard(title: "This Month", value: "LKR 48,500", icon: "calendar", color: Color.cakeBrown)
                earningCard(title: "Last Month", value: "LKR 38,200", icon: "clock.arrow.circlepath", color: Color(red: 0.3, green: 0.45, blue: 0.8))
            }
            HStack(spacing: 12) {
                earningCard(title: "This Year", value: "LKR 3,24,000", icon: "chart.line.uptrend.xyaxis", color: Color(red: 0.2, green: 0.6, blue: 0.4))
                earningCard(title: "Avg Per Order", value: "LKR 8,700", icon: "equal.circle.fill", color: Color(red: 0.7, green: 0.45, blue: 0.1))
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func earningCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.urbanistRegular(10))
                    .foregroundColor(.cakeGrey)
                Text(value)
                    .font(.urbanistBold(13))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(red: 0.97, green: 0.96, blue: 0.94))
        .cornerRadius(14)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Settings
    private var settingsSection: some View {
        VStack(spacing: 0) {
            settingsRow(icon: "bell.fill", label: "Notifications", color: Color(red: 0.3, green: 0.45, blue: 0.8))
            Divider().padding(.leading, 52)
            settingsRow(icon: "lock.fill", label: "Privacy & Security", color: Color.cakeBrown)
            Divider().padding(.leading, 52)
            settingsRow(icon: "creditcard.fill", label: "Payment Details", color: Color(red: 0.2, green: 0.6, blue: 0.4))
            Divider().padding(.leading, 52)
            settingsRow(icon: "questionmark.circle.fill", label: "Help & Support", color: Color(red: 0.7, green: 0.45, blue: 0.1))
            Divider().padding(.leading, 52)
            Button {
                // TODO: Sign out
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.red.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "rectangle.portrait.and.arrow.backward")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                    }
                    Text("Sign Out")
                        .font(.urbanistSemiBold(15))
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(14)
            }
        }
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func settingsRow(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }
            Text(label)
                .font(.urbanistMedium(15))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.cakeGrey)
        }
        .padding(14)
    }
}

// MARK: - Flow Layout for tags
struct FlowLayout: View {
    let tags: [String]

    var body: some View {
        var width: CGFloat = 0
        var rows: [[String]] = [[]]

        // Simple tag layout
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.urbanistMedium(12))
                        .foregroundColor(.cakeBrown)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.cakeBrown.opacity(0.1))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.cakeBrown.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .flipsForRightToLeftLayoutDirection(false)
        }
    }
}

private struct PortfolioThumbnail: View {
    let imageRef: String

    var body: some View {
        Group {
            if imageRef.hasPrefix("http://") || imageRef.hasPrefix("https://") {
                AsyncImage(url: URL(string: imageRef)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.95, green: 0.93, blue: 0.90))
                            .overlay(Image(systemName: "photo").foregroundColor(.cakeBrown.opacity(0.65)))
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.95, green: 0.93, blue: 0.90))
                    .overlay(
                        Image(systemName: "birthday.cake")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.cakeBrown.opacity(0.7))
                    )
            }
        }
        .frame(height: 92)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct PastelTagFlowLayout: View {
    let tags: [String]

    private let pastelPalette: [Color] = [
        Color(red: 0.95, green: 0.84, blue: 0.92),
        Color(red: 0.98, green: 0.86, blue: 0.82),
        Color(red: 0.97, green: 0.93, blue: 0.78),
        Color(red: 0.86, green: 0.93, blue: 0.98),
        Color(red: 0.87, green: 0.95, blue: 0.88),
        Color(red: 0.91, green: 0.88, blue: 0.98)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(Array(tags.enumerated()), id: \.element) { index, tag in
                    Text(tag)
                        .font(.urbanistRegular(11))
                        .foregroundColor(Color(red: 0.32, green: 0.23, blue: 0.16))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(pastelPalette[index % pastelPalette.count])
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .flipsForRightToLeftLayoutDirection(false)
        }
    }
}

private struct BakerProfileData {
    let shopName: String
    let address: String
    let isOnline: Bool
    let rating: Double
    let reviewCount: Int
    let completedOrders: Int
    let about: String
    let createdAt: Date
    let specialties: [String]
    let profileImageURL: String
    let coverImageURL: String
    let portfolioImages: [String]

    static let empty = BakerProfileData(
        shopName: "Baker Shop",
        address: "No address added",
        isOnline: true,
        rating: 0,
        reviewCount: 0,
        completedOrders: 0,
        about: "No profile description added yet.",
        createdAt: Date(),
        specialties: ["Custom Cakes"],
        profileImageURL: "",
        coverImageURL: "",
        portfolioImages: ["cake.portrait.1", "cake.portrait.2", "cake.portrait.3", "cake.portrait.4", "cake.portrait.5", "cake.portrait.6"]
    )
}

// MARK: - Baker Edit Profile Sheet
struct BakerEditProfileSheet: View {
    let user: AppUser
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var bio = "Passionate cake artist with 5+ years of experience crafting memorable cakes..."
    @State private var location = "Colombo, Sri Lanka"
    @State private var phone = "+94 77 123 4567"
    @State private var selectedTags: Set<String> = ["Wedding Cakes", "Birthday Cakes", "Fondant Art"]

    private let allCategories = ["Wedding Cakes", "Birthday Cakes", "Fondant Art", "Custom Orders",
                                  "Cupcakes", "Corporate Cakes", "Dessert Platters", "Cheesecakes",
                                  "Gluten-Free", "Vegan Cakes", "Kids Cakes", "Fruit Cakes"]

    init(user: AppUser) {
        self.user = user
        self._name = State(initialValue: user.name)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Avatar
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(Color.cakeBrown.opacity(0.18))
                            .frame(width: 90, height: 90)
                            .overlay(
                                Text(String(user.name.prefix(1)).uppercased())
                                    .font(.urbanistBold(32))
                                    .foregroundColor(.cakeBrown)
                            )
                        ZStack {
                            Circle().fill(Color.cakeBrown).frame(width: 28, height: 28)
                            Image(systemName: "camera.fill").font(.system(size: 13)).foregroundColor(.white)
                        }
                    }
                    .padding(.top, 8)

                    VStack(spacing: 14) {
                        editField(label: "Full Name", placeholder: "Your baker name", text: $name)
                        editField(label: "Phone", placeholder: "+94 XX XXX XXXX", text: $phone)
                        editField(label: "Location", placeholder: "City, Country", text: $location)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bio")
                                .font(.urbanistSemiBold(13))
                                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                            TextEditor(text: $bio)
                                .font(.urbanistRegular(14))
                                .frame(height: 100)
                                .padding(10)
                                .background(Color(red: 0.97, green: 0.96, blue: 0.94))
                                .cornerRadius(12)
                                .scrollContentBackground(.hidden)
                        }

                        // Category selection
                        VStack(alignment: .leading, spacing: 10) {
                            Text("My Specialities (select all that apply)")
                                .font(.urbanistSemiBold(13))
                                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(allCategories, id: \.self) { cat in
                                    Button {
                                        if selectedTags.contains(cat) {
                                            selectedTags.remove(cat)
                                        } else {
                                            selectedTags.insert(cat)
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: selectedTags.contains(cat) ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedTags.contains(cat) ? .cakeBrown : .cakeGrey)
                                            Text(cat)
                                                .font(.urbanistMedium(12))
                                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                            Spacer()
                                        }
                                        .padding(10)
                                        .background(selectedTags.contains(cat) ? Color.cakeBrown.opacity(0.08) : Color(red: 0.95, green: 0.95, blue: 0.95))
                                        .cornerRadius(10)
                                    }
                                }
                            }
                        }

                        Button {
                            dismiss()
                        } label: {
                            Text("Save Changes")
                                .font(.urbanistBold(16))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.cakeBrown)
                                .cornerRadius(16)
                        }
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.cakeGrey)
                }
            }
        }
    }

    private func editField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.urbanistSemiBold(13))
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
            TextField(placeholder, text: text)
                .font(.urbanistRegular(14))
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Color(red: 0.97, green: 0.96, blue: 0.94))
                .cornerRadius(12)
        }
    }
}

// MARK: - Chart Data Models
struct MonthlyOrder: Identifiable {
    let id = UUID()
    let month: String
    let count: Int
}

struct RatingItem {
    let stars: Int
    let count: Int
    let fraction: CGFloat
}

let monthlyOrderData: [MonthlyOrder] = [
    MonthlyOrder(month: "Nov", count: 4),
    MonthlyOrder(month: "Dec", count: 9),
    MonthlyOrder(month: "Jan", count: 7),
    MonthlyOrder(month: "Feb", count: 11),
    MonthlyOrder(month: "Mar", count: 14),
    MonthlyOrder(month: "Apr", count: 6),
]

let ratingBreakdown: [RatingItem] = [
    RatingItem(stars: 5, count: 38, fraction: 0.81),
    RatingItem(stars: 4, count: 6,  fraction: 0.13),
    RatingItem(stars: 3, count: 2,  fraction: 0.04),
    RatingItem(stars: 2, count: 1,  fraction: 0.02),
    RatingItem(stars: 1, count: 0,  fraction: 0.00),
]

#Preview {
    BakerProfileView(user: AppUser.mockBaker)
}
