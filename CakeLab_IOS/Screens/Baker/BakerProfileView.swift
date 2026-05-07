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
    @State private var profileData = BakerProfileData.empty
    @State private var isLoading = true
    @State private var completedOrders: [CakeOrder] = []
    @State private var monthlyOrders: [MonthlyOrderData] = []
    @State private var earningsData: EarningsData = .empty
    @State private var reviews: [Review] = []
    @State private var paymentRecords: [BakerPaymentRecord] = []

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
    private var performanceSnapshot: BakerPerformanceSnapshot {
        BakerPerformanceSnapshot.build(orders: completedOrders, reviews: reviews)
    }
    private var earningsSnapshot: BakerEarningsSnapshot {
        BakerEarningsSnapshot.build(orders: completedOrders, payments: paymentRecords)
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
            await loadAnalyticsData()
        }
        .onAppear {
            Task {
                await loadProfileData()
                await loadAnalyticsData()
            }
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
                Text("\(profileData.portfolioWorks.count)/6 selected")
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeGrey)
            }

            if profileData.portfolioWorks.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 24))
                        .foregroundColor(.cakeBrown.opacity(0.7))
                    Text("No portfolio works published yet")
                        .font(.urbanistSemiBold(14))
                        .foregroundColor(Color(hex: "5D3714"))
                    Text("Use Edit Portfolio to add your previous work and choose what appears here.")
                        .font(.urbanistRegular(12))
                        .foregroundColor(.cakeGrey)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .padding(.horizontal, 8)
                .background(Color(red: 0.98, green: 0.96, blue: 0.94))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(profileData.portfolioWorks.prefix(6)) { work in
                        PortfolioThumbnail(work: work)
                    }
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
                portfolioWorks: resolvePortfolioWorks(artisanData: artisanData)
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

    private func resolvePortfolioWorks(artisanData: [String: Any]) -> [PortfolioPreviewWork] {
        let publishedWorks = artisanData["portfolioPublishedWorks"] as? [[String: Any]] ?? []
        let resolvedPublishedWorks = publishedWorks.compactMap(PortfolioPreviewWork.init(dictionary:))
        if !resolvedPublishedWorks.isEmpty {
            return Array(resolvedPublishedWorks.prefix(6))
        }

        let legacyImages = artisanData["portfolioImages"] as? [String] ?? artisanData["portfolioURLs"] as? [String] ?? []
        return legacyImages.prefix(6).enumerated().map { index, imageRef in
            PortfolioPreviewWork(
                id: "legacy-\(index)",
                title: "Portfolio Work",
                imageReference: imageRef
            )
        }
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

    private func loadAnalyticsData() async {
        let db = Firestore.firestore()

        do {
            async let ordersTask = fetchCompletedOrders(db: db)
            async let paymentsTask = fetchPayments(db: db)
            async let reviewsTask = db.collection("reviews")
                .whereField("bakerID", isEqualTo: user.id)
                .order(by: "createdAt", descending: true)

            let (orders, payments, reviewSnapshot) = try await (ordersTask, paymentsTask, reviewsTask.getDocuments())
            completedOrders = orders
            paymentRecords = payments
            reviews = reviewSnapshot.documents.compactMap { Review(document: $0) }
            monthlyOrders = performanceSnapshot.monthlyOrders.map { MonthlyOrderData(month: $0.label, count: Int($0.value)) }

            let summary = earningsSnapshot
            earningsData = EarningsData(
                totalEarningsThisMonth: summary.totalEarningsThisMonth,
                totalEarningsLastMonth: summary.totalEarningsLastMonth,
                totalEarningsThisYear: summary.totalEarningsThisYear,
                avgPerOrder: summary.avgPerOrder
            )
        } catch {
            print("Error loading analytics data: \(error.localizedDescription)")
            completedOrders = []
            paymentRecords = []
            reviews = []
            monthlyOrders = []
            earningsData = .empty
        }
    }

    private func fetchCompletedOrders(db: Firestore) async throws -> [CakeOrder] {
        let statuses = ["completed", "delivered", "done"]
        var orders: [CakeOrder] = []

        for key in ["bakerID", "bakerId", "artisanId"] {
            let snapshot = try await db.collection("orders")
                .whereField(key, isEqualTo: user.id)
                .whereField("status", in: statuses)
                .getDocuments()

            for doc in snapshot.documents {
                if let order = CakeOrder(document: doc), !orders.contains(where: { $0.id == order.id }) {
                    orders.append(order)
                }
            }
        }

        return orders.sorted { $0.deliveryDate < $1.deliveryDate }
    }

    private func fetchPayments(db: Firestore) async throws -> [BakerPaymentRecord] {
        let snapshot = try await db.collection("payments")
            .whereField("bakerId", isEqualTo: user.id)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            return BakerPaymentRecord(
                id: doc.documentID,
                orderID: data["orderID"] as? String ?? "",
                amount: parseDouble(data["amount"]),
                total: parseDouble(data["total"]),
                method: data["method"] as? String ?? "",
                status: data["status"] as? String ?? "success",
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        .sorted { $0.createdAt < $1.createdAt }
    }

    private func parseDouble(_ value: Any?) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String {
            let cleaned = value.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(cleaned) ?? 0
        }
        return 0
    }

    // MARK: - Performance Charts
    private var performanceSection: some View {
        NavigationLink(destination: BakerPerformanceAnalyticsView(snapshot: performanceSnapshot)) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Performance")
                            .font(.urbanistBold(16))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        Text("Completed orders, review trends, and category mix")
                            .font(.urbanistRegular(12))
                            .foregroundColor(.cakeGrey)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.cakeGrey)
                }

                if monthlyOrders.isEmpty {
                    analyticsPlaceholder(
                        icon: "chart.bar",
                        title: "No Performance Data",
                        message: "Complete orders to see your performance charts."
                    )
                } else {
                    Chart(monthlyOrders) { item in
                        BarMark(
                            x: .value("Month", item.month),
                            y: .value("Orders", item.count)
                        )
                        .foregroundStyle(Color.cakeBrown.gradient)
                        .cornerRadius(6)
                    }
                    .frame(height: 150)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }

                    HStack(spacing: 12) {
                        profileInsightChip(title: "Orders", value: "\(performanceSnapshot.completedOrders)")
                        profileInsightChip(title: "Rating", value: performanceSnapshot.averageRatingText)
                        profileInsightChip(title: "Reviews", value: "\(performanceSnapshot.totalReviews)")
                    }
                }
            }
            .padding(18)
            .background(Color.white)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Earnings Summary
    private var earningsSection: some View {
        NavigationLink(destination: BakerEarningsAnalyticsView(snapshot: earningsSnapshot)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Earnings Summary")
                            .font(.urbanistBold(16))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        Text("Revenue by month, category, and payment method")
                            .font(.urbanistRegular(12))
                            .foregroundColor(.cakeGrey)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.cakeGrey)
                }

                if earningsData.totalEarningsThisMonth == 0 && earningsData.totalEarningsLastMonth == 0 && earningsData.totalEarningsThisYear == 0 {
                    analyticsPlaceholder(
                        icon: "banknote",
                        title: "No Earnings Data",
                        message: "Successful paid orders will appear in your earnings charts."
                    )
                } else {
                    let monthlyRevenuePreview = earningsSnapshot.monthlyEarnings.filter { $0.value > 0 }
                    if !monthlyRevenuePreview.isEmpty {
                        Chart(monthlyRevenuePreview) { item in
                            LineMark(
                                x: .value("Month", item.label),
                                y: .value("Earnings", item.value)
                            )
                            .foregroundStyle(Color(red: 0.2, green: 0.6, blue: 0.4))
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                            AreaMark(
                                x: .value("Month", item.label),
                                y: .value("Earnings", item.value)
                            )
                            .foregroundStyle(Color(red: 0.2, green: 0.6, blue: 0.4).opacity(0.18))
                        }
                        .frame(height: 150)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                    }

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
        .buttonStyle(.plain)
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
            NavigationLink(destination: BakerPerformanceAnalyticsView(snapshot: performanceSnapshot)) {
                menuRow(icon: "chart.bar.fill", label: "Performance Analysis", color: Color(red: 0.3, green: 0.45, blue: 0.8))
            }
            Divider().padding(.leading, 52)
            NavigationLink(destination: BakerEarningsAnalyticsView(snapshot: earningsSnapshot)) {
                menuRow(icon: "banknote.fill", label: "Earnings Summary", color: Color(red: 0.2, green: 0.6, blue: 0.4))
            }
            Divider().padding(.leading, 52)
            menuRow(icon: "lock.fill", label: "Change Password", color: Color(red: 0.7, green: 0.45, blue: 0.1))
            Divider().padding(.leading, 52)
            menuRow(icon: "globe", label: "Language", color: Color(red: 0.2, green: 0.5, blue: 0.8))
            Divider().padding(.leading, 52)
            NavigationLink(destination: BakerPortfolioManagerView(user: user)) {
                menuRow(icon: "photo.stack.fill", label: "Edit Portfolio", color: Color.cakeBrown)
            }
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

    private func analyticsPlaceholder(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.cakeBrown.opacity(0.5))
            Text(title)
                .font(.urbanistBold(14))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            Text(message)
                .font(.urbanistRegular(12))
                .foregroundColor(.cakeGrey)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(Color(red: 0.97, green: 0.96, blue: 0.94))
        .cornerRadius(12)
    }

    private func profileInsightChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.urbanistRegular(10))
                .foregroundColor(.cakeGrey)
            Text(value)
                .font(.urbanistBold(14))
                .foregroundColor(Color(hex: "5D3714"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(red: 0.97, green: 0.96, blue: 0.94))
        .cornerRadius(12)
    }

    // MARK: - Settings
    private var settingsSection: some View {
        VStack(spacing: 0) {
            NavigationLink(destination: BakerBidHistoryView(user: user)) {
                settingsRow(icon: "tray.full.fill", label: "Bid History", color: Color(red: 0.3, green: 0.45, blue: 0.8))
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 52)
            settingsRow(icon: "lock.fill", label: "Privacy & Security", color: Color.cakeBrown)
            Divider().padding(.leading, 52)
            settingsRow(icon: "creditcard.fill", label: "Payment Details", color: Color(red: 0.2, green: 0.6, blue: 0.4))
            Divider().padding(.leading, 52)
            settingsRow(icon: "questionmark.circle.fill", label: "Help & Support", color: Color(red: 0.7, green: 0.45, blue: 0.1))
            Divider().padding(.leading, 52)
            Button {
                do {
                    try AppSessionManager.shared.signOutCompletely()
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
    let work: PortfolioPreviewWork

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let image = decodeBase64Image(work.imageReference) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if work.imageReference.hasPrefix("http://") || work.imageReference.hasPrefix("https://") {
                    AsyncImage(url: URL(string: work.imageReference)) { phase in
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

            Text(work.title)
                .font(.urbanistMedium(11))
                .foregroundColor(Color(hex: "5D3714"))
                .lineLimit(1)
        }
    }

    private func decodeBase64Image(_ rawBase64: String) -> UIImage? {
        let trimmed = rawBase64.trimmingCharacters(in: .whitespacesAndNewlines)
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

private struct PortfolioPreviewWork: Identifiable {
    let id: String
    let title: String
    let imageReference: String

    init(id: String, title: String, imageReference: String) {
        self.id = id
        self.title = title
        self.imageReference = imageReference
    }

    init?(dictionary: [String: Any]) {
        let id = (dictionary["workID"] as? String ?? UUID().uuidString).trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (dictionary["title"] as? String ?? "Portfolio Work").trimmingCharacters(in: .whitespacesAndNewlines)
        let imageReference = (dictionary["imageBase64"] as? String ?? dictionary["imageURL"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !imageReference.isEmpty else { return nil }

        self.id = id
        self.title = title.isEmpty ? "Portfolio Work" : title
        self.imageReference = imageReference
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
    let portfolioWorks: [PortfolioPreviewWork]

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
        portfolioWorks: []
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
