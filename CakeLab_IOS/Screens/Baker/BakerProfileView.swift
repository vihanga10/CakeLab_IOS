import SwiftUI
import Charts
import FirebaseFirestore
import FirebaseAuth
import UIKit

// MARK: - Baker Profile View (Tab 3 — Portfolio)
@MainActor
struct BakerProfileView: View {
    let user: AppUser
    @Binding var parentTabSelection: Int
    @State private var navigateToSignIn = false
    @State private var profileData = BakerProfileData.empty
    @State private var isLoading = true
    @State private var monthlyOrders: [MonthlyOrderData] = []
    @State private var earningsData: EarningsData = .empty
    @State private var reviews: [Review] = []

    private var completedOrdersText: String { "\(profileData.completedOrders)" }
    private var reviewsText: String { "\(profileData.reviewCount)" }
    private var avgRatingText: String { String(format: "%.1f", profileData.rating) }
    private var locationText: String {
        let address = profileData.address.trimmingCharacters(in: .whitespacesAndNewlines)
        let city = profileData.city.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = [address, city].filter { !$0.isEmpty }
        return parts.isEmpty ? "No address added" : parts.joined(separator: ", ")
    }
    private var memberSinceText: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: profileData.createdAt)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                VStack(spacing: 0) {
                    Text("My Profile")
                        .font(.urbanistBold(18))
                        .foregroundColor(Color(hex: "5D3714"))
                        .padding(.top, 18)
                        .padding(.bottom, 10)

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

                            // MARK: Profile Menu
                            profileMenuSection
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)

                            // MARK: Settings
                            settingsSection
                                .padding(.horizontal, 20)
                                .padding(.bottom, 100)
                        }
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .task {
            await loadProfileData()
            await loadMonthlyOrdersData()
            await loadEarningsData()
            await loadReviewsData()
        }
        .onAppear {
            // Refresh profile data when returning from Edit Profile
            Task {
                await loadProfileData()
            }
        }
        .navigationDestination(isPresented: $navigateToSignIn) {
            SignInView()
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
                    Text(locationText)
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
            if let coverImage = decodeBase64Image(profileData.coverImageBase64) {
                Image(uiImage: coverImage)
                    .resizable()
                    .scaledToFill()
            } else if let url = URL(string: profileData.coverImageURL) {
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

            if let profileImage = decodeBase64Image(profileData.profileImageBase64) {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 102, height: 102)
                    .clipShape(Circle())
            } else if let url = URL(string: profileData.profileImageURL) {
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
            // Completed Orders - Clickable
            Button(action: { parentTabSelection = 2 }) {
                profileStatItem(value: completedOrdersText, label: "Completed \n   Orders")
            }
            Divider().frame(height: 40)
            
            // Reviews - Clickable
            NavigationLink(destination: BakerReviewsView(user: user)) {
                profileStatItem(value: reviewsText, label: "Reviews")
            }
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
            Text("About Me")
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

            if profileData.specialties.isEmpty {
                Text("No specialties added yet")
                    .font(.urbanistRegular(13))
                    .foregroundColor(.cakeGrey)
            } else {
                PastelTagFlowLayout(tags: profileData.specialties)
            }
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
                Text("My Portfolio")
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
                city: resolveCity(artisanData: artisanData),
                isOnline: artisanData["isOnline"] as? Bool ?? true,
                rating: artisanData["rating"] as? Double ?? 0,
                reviewCount: artisanData["reviewCount"] as? Int ?? 0,
                completedOrders: completedCount,
                about: resolveAbout(artisanData: artisanData),
                createdAt: resolveCreatedAt(artisanData: artisanData),
                specialties: resolveSpecialties(artisanData: artisanData),
                profileImageURL: resolveProfileImageURL(artisanData: artisanData),
                profileImageBase64: artisanData["profileImageBase64"] as? String ?? "",
                coverImageURL: artisanData["coverImageURL"] as? String ?? "",
                coverImageBase64: artisanData["coverImageBase64"] as? String ?? "",
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
        let options = [artisanData["location"] as? String, artisanData["address"] as? String, user.address]
        return options.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first(where: { !$0.isEmpty }) ?? "No address added"
    }

    private func resolveCity(artisanData: [String: Any]) -> String {
        let options = [artisanData["city"] as? String, user.city]
        return options.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first(where: { !$0.isEmpty }) ?? ""
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

    private func decodeBase64Image(_ rawBase64: String) -> UIImage? {
        let trimmed = rawBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Supports both plain Base64 and data URL format.
        let payload: String
        if let commaIndex = trimmed.firstIndex(of: ",") {
            payload = String(trimmed[trimmed.index(after: commaIndex)...])
        } else {
            payload = trimmed
        }

        guard let data = Data(base64Encoded: payload) else { return nil }
        return UIImage(data: data)
    }

    private var ratingBreakdown: [RatingData] {
        let totalReviews = reviews.count
        guard totalReviews > 0 else { return [] }
        
        var breakdown: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
        for review in reviews {
            breakdown[review.rating, default: 0] += 1
        }
        
        return (1...5).reversed().map { stars in
            let count = breakdown[stars] ?? 0
            let fraction = CGFloat(count) / CGFloat(totalReviews)
            return RatingData(stars: stars, count: count, fraction: fraction)
        }
    }

    private func loadMonthlyOrdersData() async {
        let db = Firestore.firestore()
        
        do {
            let statuses = ["completed", "delivered", "done"]
            var allOrders: [CakeOrder] = []
            
            for key in ["bakerID", "bakerId", "artisanId"] {
                let query = db.collection("orders")
                    .whereField(key, isEqualTo: user.id)
                    .whereField("status", in: statuses)
                
                let snapshot = try await query.getDocuments()
                for doc in snapshot.documents {
                    if let order = CakeOrder(document: doc), !allOrders.contains(where: { $0.id == order.id }) {
                        allOrders.append(order)
                    }
                }
            }
            
            // Group by month
            let calendar = Calendar.current
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM"
            
            var monthCounts: [String: Int] = [:]
            for order in allOrders {
                let month = dateFormatter.string(from: order.deliveryDate)
                monthCounts[month, default: 0] += 1
            }
            
            monthlyOrders = monthCounts.map { MonthlyOrderData(month: $0.key, count: $0.value) }
                .sorted { (a, b) -> Bool in
                    let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
                    return (months.firstIndex(of: a.month) ?? 0) < (months.firstIndex(of: b.month) ?? 0)
                }
        } catch {
            print("Error loading monthly orders: \(error.localizedDescription)")
            monthlyOrders = []
        }
    }

    private func loadEarningsData() async {
        let db = Firestore.firestore()
        
        do {
            let statuses = ["completed", "delivered", "done"]
            var allOrders: [CakeOrder] = []
            
            for key in ["bakerID", "bakerId", "artisanId"] {
                let query = db.collection("orders")
                    .whereField(key, isEqualTo: user.id)
                    .whereField("status", in: statuses)
                
                let snapshot = try await query.getDocuments()
                for doc in snapshot.documents {
                    if let order = CakeOrder(document: doc), !allOrders.contains(where: { $0.id == order.id }) {
                        allOrders.append(order)
                    }
                }
            }
            
            // Calculate earnings by period
            let calendar = Calendar.current
            let now = Date()
            
            let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart)!
            let lastMonthEnd = calendar.date(byAdding: .day, value: -1, to: thisMonthStart)!
            let thisYearStart = calendar.date(from: calendar.dateComponents([.year], from: now))!
            
            var thisMonthEarnings: Double = 0
            var lastMonthEarnings: Double = 0
            var thisYearEarnings: Double = 0
            
            for order in allOrders {
                // Parse amount from artisanRating or estimate based on order (for demo, using fixed values)
                let amount: Double = 3500 // Default amount per order
                
                thisYearEarnings += amount
                
                if order.deliveryDate >= thisMonthStart {
                    thisMonthEarnings += amount
                } else if order.deliveryDate >= lastMonthStart && order.deliveryDate <= lastMonthEnd {
                    lastMonthEarnings += amount
                }
            }
            
            let avgPerOrder = allOrders.isEmpty ? 0 : thisYearEarnings / Double(allOrders.count)
            
            earningsData = EarningsData(
                totalEarningsThisMonth: thisMonthEarnings,
                totalEarningsLastMonth: lastMonthEarnings,
                totalEarningsThisYear: thisYearEarnings,
                avgPerOrder: avgPerOrder
            )
        } catch {
            print("Error loading earnings data: \(error.localizedDescription)")
            earningsData = .empty
        }
    }

    private func loadReviewsData() async {
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

    // MARK: - Performance Charts
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance")
                .font(.urbanistBold(16))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

            if monthlyOrders.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 32))
                        .foregroundColor(.cakeBrown.opacity(0.3))
                    VStack(spacing: 6) {
                        Text("No Performance Data")
                            .font(.urbanistBold(14))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        Text("Complete orders to see your performance metrics.")
                            .font(.urbanistRegular(12))
                            .foregroundColor(.cakeGrey)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color(red: 0.97, green: 0.96, blue: 0.94))
                .cornerRadius(12)
            } else {
                // Monthly orders chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("Monthly Orders")
                        .font(.urbanistSemiBold(13))
                        .foregroundColor(.cakeGrey)

                    Chart(monthlyOrders) { item in
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
                if !reviews.isEmpty {
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
            Text("Earnings Summary")
                .font(.urbanistBold(16))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

            if earningsData.totalEarningsThisMonth == 0 && earningsData.totalEarningsLastMonth == 0 {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "banknote")
                        .font(.system(size: 32))
                        .foregroundColor(.cakeBrown.opacity(0.3))
                    VStack(spacing: 6) {
                        Text("No Earnings Data")
                            .font(.urbanistBold(14))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        Text("Complete orders to start earning and see your earnings summary.")
                            .font(.urbanistRegular(12))
                            .foregroundColor(.cakeGrey)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color(red: 0.97, green: 0.96, blue: 0.94))
                .cornerRadius(12)
            } else {
                HStack(spacing: 12) {
                    earningCard(title: "This Month", value: earningsData.thisMonthFormatted, icon: "calendar", color: Color.cakeBrown)
                    earningCard(title: "Last Month", value: earningsData.lastMonthFormatted, icon: "clock.arrow.circlepath", color: Color(red: 0.3, green: 0.45, blue: 0.8))
                }
                HStack(spacing: 12) {
                    earningCard(title: "This Year", value: earningsData.thisYearFormatted, icon: "chart.line.uptrend.xyaxis", color: Color(red: 0.2, green: 0.6, blue: 0.4))
                    earningCard(title: "Avg Per Order", value: earningsData.avgPerOrderFormatted, icon: "equal.circle.fill", color: Color(red: 0.7, green: 0.45, blue: 0.1))
                }
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

    // MARK: - Profile Menu
    private var profileMenuSection: some View {
        VStack(spacing: 0) {
            NavigationLink(destination: BakerEditProfileView(user: user)) {
                menuRow(icon: "person.fill", label: "Edit Profile", color: Color(red: 0.5, green: 0.5, blue: 0.5))
            }
            Divider().padding(.leading, 52)
            menuRow(icon: "chart.bar.fill", label: "Performance Analysis", color: Color(red: 0.3, green: 0.45, blue: 0.8))
            Divider().padding(.leading, 52)
            menuRow(icon: "banknote.fill", label: "Earnings Summary", color: Color(red: 0.2, green: 0.6, blue: 0.4))
            Divider().padding(.leading, 52)
            menuRow(icon: "lock.fill", label: "Change Password", color: Color(red: 0.7, green: 0.45, blue: 0.1))
            Divider().padding(.leading, 52)
            menuRow(icon: "globe", label: "Language", color: Color(red: 0.2, green: 0.5, blue: 0.8))
            Divider().padding(.leading, 52)
            menuRow(icon: "photo.stack.fill", label: "Edit Portfolio", color: Color.cakeBrown)
        }
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func menuRow(icon: String, label: String, color: Color) -> some View {
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
        }
        .padding(14)
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
                do {
                    try Auth.auth().signOut()
                    WidgetDataSyncManager.shared.clearWidgetData()
                    navigateToSignIn = true
                } catch {
                    print("Logout failed: \(error.localizedDescription)")
                }
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
        VStack(alignment: .leading, spacing: 8) {
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

    let pastelPalette: [Color] = [
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

// MARK: - Helper Data Structures
private struct RatingData: Identifiable {
    let id = UUID()
    let stars: Int
    let count: Int
    let fraction: CGFloat
}

struct MonthlyOrderData: Identifiable {
    let id = UUID()
    let month: String
    let count: Int
}

struct EarningsData {
    let totalEarningsThisMonth: Double
    let totalEarningsLastMonth: Double
    let totalEarningsThisYear: Double
    let avgPerOrder: Double
    
    var thisMonthFormatted: String {
        return String(format: "LKR %.0f", totalEarningsThisMonth)
    }
    
    var lastMonthFormatted: String {
        return String(format: "LKR %.0f", totalEarningsLastMonth)
    }
    
    var thisYearFormatted: String {
        return String(format: "LKR %.0f", totalEarningsThisYear)
    }
    
    var avgPerOrderFormatted: String {
        return String(format: "LKR %.0f", avgPerOrder)
    }
    
    static let empty = EarningsData(
        totalEarningsThisMonth: 0,
        totalEarningsLastMonth: 0,
        totalEarningsThisYear: 0,
        avgPerOrder: 0
    )
}

private struct BakerProfileData {
    let shopName: String
    let address: String
    let city: String
    let isOnline: Bool
    let rating: Double
    let reviewCount: Int
    let completedOrders: Int
    let about: String
    let createdAt: Date
    let specialties: [String]
    let profileImageURL: String
    let profileImageBase64: String
    let coverImageURL: String
    let coverImageBase64: String
    let portfolioImages: [String]

    static let empty = BakerProfileData(
        shopName: "Baker Shop",
        address: "No address added",
        city: "",
        isOnline: true,
        rating: 0,
        reviewCount: 0,
        completedOrders: 0,
        about: "No profile description added yet.",
        createdAt: Date(),
        specialties: ["Custom Cakes"],
        profileImageURL: "",
        profileImageBase64: "",
        coverImageURL: "",
        coverImageBase64: "",
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

    let allCategories = ["Wedding Cakes", "Birthday Cakes", "Fondant Art", "Custom Orders",
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

#Preview {
    @State var tabSelection = 0
    return BakerProfileView(user: AppUser.mockBaker, parentTabSelection: $tabSelection)
}
