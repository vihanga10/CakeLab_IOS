import SwiftUI
import Charts
import UIKit


@MainActor
struct BakerProfileView: View {
    let user: AppUser
    @Binding var parentTabSelection: Int
    @StateObject private var vm = BakerProfileViewModel()
    @State private var selectedPortfolioWork: PortfolioPreviewWork?
    @State private var showSignOutAlert = false

    private var completedOrdersText: String { "\(vm.profileData.completedOrders)" }
    private var reviewsText: String {
        let liveReviewCount = vm.reviews.count
        return "\(liveReviewCount > 0 ? liveReviewCount : vm.profileData.reviewCount)"
    }
    private var avgRatingText: String {
        if !vm.reviews.isEmpty {
            let average = vm.reviews.reduce(0.0) { $0 + Double($1.rating) } / Double(vm.reviews.count)
            return String(format: "%.1f", average)
        }
        return String(format: "%.1f", vm.profileData.rating)
    }
    private var locationText: String {
        let address = vm.profileData.address.trimmingCharacters(in: .whitespacesAndNewlines)
        let city = vm.profileData.city.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = [address, city].filter { !$0.isEmpty }
        return parts.isEmpty ? "No address added" : parts.joined(separator: ", ")
    }
    private var memberSinceText: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: vm.profileData.createdAt)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cakeBackground.ignoresSafeArea()
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

                            // MARK: Accessibility
                            AccessibilitySettingsSection()
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
            await vm.loadProfileData(user: user)
            await vm.loadAnalyticsData(user: user)
        }
        .onAppear {
            Task {
                await vm.loadProfileData(user: user)
                await vm.loadAnalyticsData(user: user)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("bakerPortfolioDidChange"))) { _ in
            Task { await vm.loadProfileData(user: user) }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("bakerProfileDidChange"))) { _ in
            Task { await vm.loadProfileData(user: user) }
        }
        .sheet(item: $selectedPortfolioWork) { work in
            PortfolioPreviewDetailSheet(work: work)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Sign Out?", isPresented: $showSignOutAlert) {
            Button("No", role: .cancel) {}
            Button("Yes, Sign Out", role: .destructive) {
                performSignOut()
            }
        } message: {
            Text("Are you sure you want to sign out of your CakeLab baker account?")
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
                Text(vm.profileData.shopName)
                    .font(.urbanistBold(22))
                    .foregroundColor(.cakePrimaryText)

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
            if let coverImage = decodeBase64Image(vm.profileData.coverImageBase64) {
                Image(uiImage: coverImage)
                    .resizable()
                    .scaledToFill()
            } else if let url = URL(string: vm.profileData.coverImageURL) {
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
        ZStack {
            LinearGradient(
                colors: [
                    Color.cakeBrown.opacity(0.14),
                    Color(red: 0.96, green: 0.93, blue: 0.89)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "photo")
                .font(.system(size: 30, weight: .medium))
                .foregroundColor(.cakeBrown.opacity(0.35))
        }
    }

    private var profileAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.cakeSurface)
                .frame(width: 110, height: 110)
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)

            if let profileImage = decodeBase64Image(vm.profileData.profileImageBase64) {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 102, height: 102)
                    .clipShape(Circle())
            } else if let url = URL(string: vm.profileData.profileImageURL) {
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
                Text(String(vm.profileData.shopName.prefix(1)).uppercased())
                    .font(.urbanistBold(34))
                    .foregroundColor(.cakeBrown)
            )
    }

    private var activeBadge: some View {
        Text(vm.profileData.isOnline ? "Active" : "Inactive")
            .font(.urbanistMedium(12))
            .foregroundColor(vm.profileData.isOnline ? Color(red: 0.12, green: 0.58, blue: 0.29) : Color(red: 0.78, green: 0.12, blue: 0.12))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(vm.profileData.isOnline ? Color(red: 0.82, green: 0.95, blue: 0.86) : Color(red: 1.0, green: 0.86, blue: 0.86))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 0) {
            // Completed Orders - Clickable
            Button(action: { parentTabSelection = 2 }) {
                profileStatItem(value: completedOrdersText, label: "Completed\nOrders")
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
        .background(Color.cakeSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
    }

    private func profileStatItem(value: String, label: String) -> some View {
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

    // MARK: - Bio Section
    private var bioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About Me")
                .font(.urbanistBold(16))
                .foregroundColor(.cakePrimaryText)

            Text(vm.profileData.about)
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
        .background(Color.cakeSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: - Category Tags
    private var categoryTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Specialities")
                    .font(.urbanistBold(16))
                    .foregroundColor(.cakePrimaryText)
                Spacer()
            }

            if vm.profileData.specialties.isEmpty {
                Text("No specialties added yet")
                    .font(.urbanistRegular(13))
                    .foregroundColor(.cakeGrey)
            } else {
                PastelTagFlowLayout(tags: vm.profileData.specialties)
            }
        }
        .padding(18)
        .background(Color.cakeSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
    }

    // MARK: - Portfolio Gallery
    private var portfolioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Portfolio")
                    .font(.urbanistBold(16))
                    .foregroundColor(.cakePrimaryText)
                Spacer()
                Text("\(vm.profileData.portfolioWorks.count)/6 selected")
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeGrey)
            }

            if vm.profileData.portfolioWorks.isEmpty {
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
                .background(Color.cakeInsetSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(vm.profileData.portfolioWorks.prefix(6)) { work in
                        Button {
                            selectedPortfolioWork = work
                        } label: {
                            PortfolioThumbnail(work: work)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.cakeSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
    }

    // MARK: - Image Decoder (view utility — decodes Base64 for display)
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

    // MARK: - Performance Charts
    private var performanceSection: some View {
        NavigationLink(destination: BakerPerformanceAnalyticsView(snapshot: vm.performanceSnapshot)) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Performance")
                            .font(.urbanistBold(16))
                            .foregroundColor(.cakePrimaryText)
                        Text("Completed orders, review trends, and category mix")
                            .font(.urbanistRegular(12))
                            .foregroundColor(.cakeGrey)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.cakeGrey)
                }

                if vm.monthlyOrders.isEmpty {
                    analyticsPlaceholder(
                        icon: "chart.bar",
                        title: "No Performance Data",
                        message: "Complete orders to see your performance charts."
                    )
                } else {
                    Chart(vm.monthlyOrders) { item in
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
                        profileInsightChip(title: "Orders", value: "\(vm.performanceSnapshot.completedOrders)")
                        profileInsightChip(title: "Rating", value: vm.performanceSnapshot.averageRatingText)
                        profileInsightChip(title: "Reviews", value: "\(vm.performanceSnapshot.totalReviews)")
                    }
                }
            }
            .padding(18)
            .background(Color.cakeSurface)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Earnings Summary
    private var earningsSection: some View {
        NavigationLink(destination: BakerEarningsAnalyticsView(snapshot: vm.earningsSnapshot)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Earnings Summary")
                            .font(.urbanistBold(16))
                            .foregroundColor(.cakePrimaryText)
                        Text("Revenue by month, category, and payment method")
                            .font(.urbanistRegular(12))
                            .foregroundColor(.cakeGrey)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.cakeGrey)
                }

                if vm.earningsData.totalEarningsThisMonth == 0 && vm.earningsData.totalEarningsLastMonth == 0 && vm.earningsData.totalEarningsThisYear == 0 {
                    analyticsPlaceholder(
                        icon: "banknote",
                        title: "No Earnings Data",
                        message: "Successful paid orders will appear in your earnings charts."
                    )
                } else {
                    let monthlyRevenuePreview = vm.earningsSnapshot.monthlyEarnings
                    if !monthlyRevenuePreview.isEmpty {
                        Chart(monthlyRevenuePreview) { item in
                            LineMark(
                                x: .value("Month", item.label),
                                y: .value("Earnings", item.value)
                            )
                            .foregroundStyle(Color(hex: "76604B"))
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                            AreaMark(
                                x: .value("Month", item.label),
                                y: .value("Earnings", item.value)
                            )
                            .foregroundStyle(Color(hex: "C8C4C1").opacity(0.28))

                            PointMark(
                                x: .value("Month", item.label),
                                y: .value("Earnings", item.value)
                            )
                            .foregroundStyle(Color(hex: "76604B"))
                        }
                        .frame(height: 150)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                    }

                    HStack(spacing: 12) {
                        earningCard(
                            title: "This Month",
                            value: vm.earningsData.thisMonthFormatted,
                            icon: "calendar",
                            iconColor: Color.cakeBrown,
                            cardBackground: Color(hex: "F8F6F3"),
                            valueColor: Color(hex: "5D3714")
                        )
                        earningCard(
                            title: "Last Month",
                            value: vm.earningsData.lastMonthFormatted,
                            icon: "clock.arrow.circlepath",
                            iconColor: Color(red: 0.30, green: 0.45, blue: 0.80),
                            cardBackground: Color(hex: "F4F9FE"),
                            valueColor: Color(red: 0.10, green: 0.28, blue: 0.60)
                        )
                    }
                    HStack(spacing: 12) {
                        earningCard(
                            title: "This Year",
                            value: vm.earningsData.thisYearFormatted,
                            icon: "chart.line.uptrend.xyaxis",
                            iconColor: Color(red: 0.20, green: 0.60, blue: 0.40),
                            cardBackground: Color(hex: "F5FEF5"),
                            valueColor: Color(red: 0.08, green: 0.38, blue: 0.18)
                        )
                        earningCard(
                            title: "Avg Per Order",
                            value: vm.earningsData.avgPerOrderFormatted,
                            icon: "equal.circle.fill",
                            iconColor: Color(red: 0.70, green: 0.45, blue: 0.10),
                            cardBackground: Color(hex: "FFF7EA"),
                            valueColor: Color(red: 0.58, green: 0.36, blue: 0.05)
                        )
                    }
                }
            }
            .padding(18)
            .background(Color.cakeSurface)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func earningCard(
        title: String,
        value: String,
        icon: String,
        iconColor: Color,
        cardBackground: Color,
        valueColor: Color
    ) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.urbanistRegular(10))
                    .foregroundColor(.cakeGrey)
                Text(value)
                    .font(.urbanistBold(13))
                    .foregroundColor(valueColor)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
        .background(cardBackground)
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
            NavigationLink(destination: BakerPerformanceAnalyticsView(snapshot: vm.performanceSnapshot)) {
                menuRow(icon: "chart.bar.fill", label: "Performance Analysis", color: Color(red: 0.3, green: 0.45, blue: 0.8))
            }
            Divider().padding(.leading, 52)
            NavigationLink(destination: BakerEarningsAnalyticsView(snapshot: vm.earningsSnapshot)) {
                menuRow(icon: "banknote.fill", label: "Earnings Summary", color: Color(red: 0.2, green: 0.6, blue: 0.4))
            }
            Divider().padding(.leading, 52)
            menuRow(icon: "lock.fill", label: "Change Password", color: Color(red: 0.7, green: 0.45, blue: 0.1))
            Divider().padding(.leading, 52)
            NavigationLink(destination: BakerProfileDetailView(kind: .language)) {
                menuRow(icon: "globe", label: "Language", color: Color(red: 0.2, green: 0.5, blue: 0.8))
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 52)
            NavigationLink(destination: BakerPortfolioManagerView(user: user)) {
                menuRow(icon: "photo.stack.fill", label: "Edit Portfolio", color: Color.cakeBrown)
            }
        }
        .background(Color.cakeSurface)
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
                .foregroundColor(.cakePrimaryText)
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
                .foregroundColor(.cakePrimaryText)
            Text(message)
                .font(.urbanistRegular(12))
                .foregroundColor(.cakeGrey)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(Color.cakeInsetSurface)
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
        .background(Color.cakeInsetSurface)
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
            NavigationLink(destination: BakerProfileDetailView(kind: .privacySecurity)) {
                settingsRow(icon: "lock.fill", label: "Privacy & Security", color: Color.cakeBrown)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 52)
            NavigationLink(destination: BakerPaymentDetailsView(user: user)) {
                settingsRow(icon: "creditcard.fill", label: "Payment Details", color: Color(red: 0.2, green: 0.6, blue: 0.4))
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 52)
            NavigationLink(destination: BakerProfileDetailView(kind: .helpSupport)) {
                settingsRow(icon: "questionmark.circle.fill", label: "Help & Support", color: Color(red: 0.7, green: 0.45, blue: 0.1))
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 52)
            Button {
                showSignOutAlert = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 1.0, green: 0.86, blue: 0.86))
                            .frame(width: 36, height: 36)
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.82, green: 0.08, blue: 0.08))
                    }
                    Text("Sign Out")
                        .font(.urbanistSemiBold(15))
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(14)
            }
        }
        .background(Color.cakeSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func performSignOut() {
        do {
            try AppSessionManager.shared.signOutCompletely()
        } catch {
            print("Logout failed: \(error.localizedDescription)")
        }
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
                .foregroundColor(.cakePrimaryText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.cakeGrey)
        }
        .padding(14)
    }
}

// MARK: - Baker Profile Detail Pages
enum BakerProfileDetailKind {
    case language
    case privacySecurity
    case helpSupport

    var title: String {
        switch self {
        case .language: return "Language"
        case .privacySecurity: return "Privacy & Security"
        case .helpSupport: return "Help & Support"
        }
    }

    var needsSaveButton: Bool {
        switch self {
        case .language, .privacySecurity:
            return true
        case .helpSupport:
            return false
        }
    }
}

struct BakerProfileDetailView: View {
    let kind: BakerProfileDetailKind

    @Environment(\.dismiss) private var dismiss
    @State private var selectedLanguage = UserDefaults.standard.string(forKey: "bakerAppLanguage") ?? "English"
    @State private var profileVisibility = UserDefaults.standard.string(forKey: "bakerProfileVisibility") ?? "Public"
    @State private var showPortfolio = UserDefaults.standard.object(forKey: "bakerShowPortfolio") as? Bool ?? true
    @State private var newOrderAlerts = UserDefaults.standard.object(forKey: "bakerNewOrderAlerts") as? Bool ?? true
    @State private var bidUpdateAlerts = UserDefaults.standard.object(forKey: "bakerBidUpdateAlerts") as? Bool ?? true
    @State private var dataSharing = UserDefaults.standard.object(forKey: "bakerDataSharing") as? Bool ?? false
    @State private var biometricAuth = UserDefaults.standard.object(forKey: "bakerBiometricAuth") as? Bool ?? false
    @State private var expandedFAQs: Set<Int> = []
    @State private var searchText = ""

    var body: some View {
        ZStack {
            Color.cakeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    Group {
                        switch kind {
                        case .language:
                            BakerLanguageDetailContent(selectedLanguage: $selectedLanguage)
                        case .privacySecurity:
                            BakerPrivacySecurityDetailContent(
                                profileVisibility: $profileVisibility,
                                showPortfolio: $showPortfolio,
                                newOrderAlerts: $newOrderAlerts,
                                bidUpdateAlerts: $bidUpdateAlerts,
                                dataSharing: $dataSharing,
                                biometricAuth: $biometricAuth
                            )
                        case .helpSupport:
                            BakerHelpSupportDetailContent(searchText: $searchText, expandedFAQs: $expandedFAQs)
                        }
                    }
                    .padding(.bottom, 24)
                }

                if kind.needsSaveButton {
                    Button {
                        saveSettings()
                        dismiss()
                    } label: {
                        Text("Save & Done")
                            .font(.urbanistSemiBold(16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color(hex: "5D3714"))
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 88)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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

            Text(kind.title)
                .font(.urbanistBold(18))
                .foregroundColor(Color(hex: "5D3714"))

            Spacer()

            Color.clear.frame(width: 24, height: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.cakeSurface)
    }

    private func saveSettings() {
        UserDefaults.standard.set(selectedLanguage, forKey: "bakerAppLanguage")
        UserDefaults.standard.set(profileVisibility, forKey: "bakerProfileVisibility")
        UserDefaults.standard.set(showPortfolio, forKey: "bakerShowPortfolio")
        UserDefaults.standard.set(newOrderAlerts, forKey: "bakerNewOrderAlerts")
        UserDefaults.standard.set(bidUpdateAlerts, forKey: "bakerBidUpdateAlerts")
        UserDefaults.standard.set(dataSharing, forKey: "bakerDataSharing")
        UserDefaults.standard.set(biometricAuth, forKey: "bakerBiometricAuth")
    }
}

struct BakerLanguageDetailContent: View {
    @Binding var selectedLanguage: String
    private let languages = [("English", "GB"), ("Sinhala", "LK"), ("Tamil", "IN")]

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                ForEach(Array(languages.enumerated()), id: \.offset) { index, language in
                    Button { selectedLanguage = language.0 } label: {
                        HStack(spacing: 16) {
                            Text(language.1)
                                .font(.urbanistBold(13))
                                .foregroundColor(.cakeBrown)
                                .frame(width: 42, height: 30)
                                .background(Color.cakeBrown.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text(language.0)
                                .font(.urbanistMedium(16))
                                .foregroundColor(.cakePrimaryText)

                            Spacer()

                            if selectedLanguage == language.0 {
                                Circle()
                                    .fill(Color(hex: "C17C3D"))
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            } else {
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                    .frame(width: 24, height: 24)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)

                    if index < languages.count - 1 {
                        Divider().padding(.leading, 74)
                    }
                }
            }
            .background(Color.cakeSurface.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cakeStroke, lineWidth: 1))
            .shadow(color: Color.cakeStroke, radius: 8, y: 4)
            .padding(.horizontal, 20)
            .padding(.top, 20)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "4C8B35"))
                    Text("Language Preference")
                        .font(.urbanistSemiBold(14))
                        .foregroundColor(Color(hex: "4C8B35"))
                }

                Text("Your selected language will be used for baker profile, orders, bids, and support screens.")
                    .font(.urbanistRegular(13))
                    .foregroundColor(.cakeSecondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(hex: "E9F9E1").opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }
}

struct BakerPrivacySecurityDetailContent: View {
    @Binding var profileVisibility: String
    @Binding var showPortfolio: Bool
    @Binding var newOrderAlerts: Bool
    @Binding var bidUpdateAlerts: Bool
    @Binding var dataSharing: Bool
    @Binding var biometricAuth: Bool

    var body: some View {
        VStack(spacing: 20) {
            detailSection(title: "Profile & Visibility") {
                profileVisibilityRow
                Divider().padding(.leading, 16)
                toggleRow(title: "Portfolio Visibility", subtitle: "Show your cake gallery to customers", isOn: $showPortfolio)
            }

            detailSection(title: "Communication") {
                toggleRow(title: "New Request Alerts", subtitle: "Get notified when matching requests arrive", isOn: $newOrderAlerts)
                Divider().padding(.leading, 16)
                toggleRow(title: "Bid Update Alerts", subtitle: "Receive accepted bid and payment updates", isOn: $bidUpdateAlerts)
                Divider().padding(.leading, 16)
                toggleRow(title: "Data Sharing", subtitle: "Help improve CakeLab baker analytics", isOn: $dataSharing)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Security")
                    .font(.urbanistMedium(14))
                    .foregroundColor(.cakeSecondaryText)
                    .padding(.horizontal, 20)

                toggleRow(title: "Biometric Authentication", subtitle: "Use Face ID or Touch ID to login", isOn: $biometricAuth)
                    .background(Color.cakeSurface.opacity(0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cakeStroke, lineWidth: 1))
                    .shadow(color: Color.cakeStroke, radius: 8, y: 4)
                    .padding(.horizontal, 20)
            }

            detailSection(title: "Data Management") {
                Button {} label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(width: 34, height: 34)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        Text("Delete Baker Account")
                            .font(.urbanistRegular(15))
                            .foregroundColor(.red)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 20)
    }

    private var profileVisibilityRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Profile Visibility")
                    .font(.urbanistMedium(14))
                    .foregroundColor(.cakePrimaryText)
                Text("Control who can see your baker profile")
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeTertiaryText)
            }

            Spacer()

            Picker("", selection: $profileVisibility) {
                Text("Public").tag("Public")
                Text("Private").tag("Private")
            }
            .pickerStyle(.segmented)
            .frame(width: 118)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.urbanistMedium(14))
                    .foregroundColor(.cakePrimaryText)
                Text(subtitle)
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeTertiaryText)
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .tint(.cakeBrown)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func detailSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.urbanistMedium(14))
                .foregroundColor(.cakeSecondaryText)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.cakeSurface.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cakeStroke, lineWidth: 1))
            .shadow(color: Color.cakeStroke, radius: 8, y: 4)
            .padding(.horizontal, 20)
        }
    }
}

struct BakerHelpSupportDetailContent: View {
    @Binding var searchText: String
    @Binding var expandedFAQs: Set<Int>

    private let faqs = [
        ("How do I place a bid?", "Open the Bids tab, review a matching request, enter your price and delivery details, then submit the bid."),
        ("Where can I see accepted bids?", "Accepted bids move into Orders after the customer confirms the bid and completes payment."),
        ("How do I update an order status?", "Open an active order, choose the current progress stage, and save the status update."),
        ("How do customers find my bakery?", "Customers see your profile, portfolio, rating, address, city, and accepted bid details."),
        ("How do I edit my portfolio?", "Go to My Profile, open Edit Portfolio, and update your cake photos and descriptions."),
        ("When do I receive payment notifications?", "You receive a notification when a customer completes payment for your accepted bid.")
    ]

    private var filteredFAQs: [(Int, (String, String))] {
        if searchText.isEmpty {
            return faqs.enumerated().map { ($0.offset, $0.element) }
        }

        return faqs.enumerated()
            .filter { item in
                item.element.0.localizedCaseInsensitiveContains(searchText) ||
                item.element.1.localizedCaseInsensitiveContains(searchText)
            }
            .map { ($0.offset, $0.element) }
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.cakeTertiaryText)

                TextField("Search FAQs...", text: $searchText)
                    .font(.urbanistRegular(14))
                    .foregroundColor(.cakePrimaryText)

                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.cakeTertiaryText)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.cakeInsetSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            .padding(.top, 20)

            VStack(alignment: .leading, spacing: 10) {
                Text("Frequently Asked Questions")
                    .font(.urbanistMedium(14))
                    .foregroundColor(.cakeSecondaryText)
                    .padding(.horizontal, 20)

                if filteredFAQs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(Color(hex: "C17C3D").opacity(0.5))
                        Text("No FAQs found")
                            .font(.urbanistMedium(16))
                            .foregroundColor(.cakeSecondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .padding(.horizontal, 20)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredFAQs.enumerated()), id: \.element.0) { index, faq in
                            BakerFAQItemView(
                                question: faq.1.0,
                                answer: faq.1.1,
                                isExpanded: expandedFAQs.contains(faq.0),
                                onToggle: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if expandedFAQs.contains(faq.0) {
                                            expandedFAQs.remove(faq.0)
                                        } else {
                                            expandedFAQs.insert(faq.0)
                                        }
                                    }
                                }
                            )

                            if index < filteredFAQs.count - 1 {
                                Divider().padding(.horizontal, 16)
                            }
                        }
                    }
                    .background(Color.cakeSurface.opacity(0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cakeStroke, lineWidth: 1))
                    .shadow(color: Color.cakeStroke, radius: 8, y: 4)
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

struct BakerFAQItemView: View {
    let question: String
    let answer: String
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Text(question)
                        .font(.urbanistSemiBold(14))
                        .foregroundColor(.cakePrimaryText)
                        .lineLimit(2)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.cakeTertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider().padding(.horizontal, 16)

                    Text(answer)
                        .font(.urbanistRegular(13))
                        .foregroundColor(.cakeSecondaryText)
                        .lineLimit(nil)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
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

// MARK: - Portfolio Preview DetailSheet
private struct PortfolioPreviewDetailSheet: View {
    let work: PortfolioPreviewWork
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.cakeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        PortfolioWorkImageView(imageBase64: work.imageReference, height: 170)

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
        WrappingTagLayout(horizontalSpacing: 8, verticalSpacing: 10) {
            ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                Text(tag)
                    .font(.urbanistRegular(12))
                    .foregroundColor(Color(red: 0.32, green: 0.23, blue: 0.16))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(pastelPalette[index % pastelPalette.count])
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .flipsForRightToLeftLayoutDirection(false)
    }
}

private struct WrappingTagLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedLineWidth = lineWidth == 0 ? size.width : lineWidth + horizontalSpacing + size.width

            if proposedLineWidth > maxWidth, lineWidth > 0 {
                totalWidth = max(totalWidth, lineWidth)
                totalHeight += lineHeight + verticalSpacing
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth = proposedLineWidth
                lineHeight = max(lineHeight, size.height)
            }
        }

        totalWidth = max(totalWidth, lineWidth)
        totalHeight += lineHeight

        return CGSize(
            width: proposal.width ?? totalWidth,
            height: totalHeight
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x > bounds.minX, x + size.width > bounds.minX + maxWidth {
                x = bounds.minX
                y += lineHeight + verticalSpacing
                lineHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            x += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }
    }
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
                                .background(Color.cakeInsetSurface)
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
                                                .foregroundColor(.cakePrimaryText)
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
                .background(Color.cakeInsetSurface)
                .cornerRadius(12)
        }
    }
}

// MARK: - Baker Payment Details View
struct BakerPaymentDetailsView: View {
    let user: AppUser
    @StateObject private var viewModel = BakerPaymentDetailsViewModel()
    @Environment(\.dismiss) private var dismiss

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let cardDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        ZStack {
            Color.cakeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                if viewModel.isLoading {
                    ProgressView("Loading payments...")
                        .tint(.cakeBrown)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    errorState(message: error)
                } else if viewModel.payments.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 20) {
                            summaryCard
                                .padding(.horizontal, 16)
                                .padding(.top, 16)

                            ForEach(viewModel.groupedByMonth, id: \.month) { section in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 10) {
                                        Text(section.month.uppercased())
                                            .font(.urbanistSemiBold(11))
                                            .foregroundColor(.cakeGrey)
                                        Rectangle()
                                            .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
                                            .frame(height: 1)
                                    }
                                    .padding(.horizontal, 16)

                                    ForEach(section.records) { record in
                                        BakerPaymentDetailsCard(
                                            record: record,
                                            dateFormatter: Self.cardDateFormatter,
                                            currencyFormatter: Self.currencyFormatter
                                        )
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }

                            Spacer().frame(height: 104)
                        }
                    }
                    .refreshable {
                        await viewModel.load(bakerID: user.id)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.load(bakerID: user.id)
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

            Text("Payment Details")
                .font(.urbanistBold(18))
                .foregroundColor(Color(hex: "5D3714"))

            Spacer()

            Color.clear.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.cakeSurface)
    }

    private var summaryCard: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 93/255, green: 55/255, blue: 20/255),
                    Color(red: 148/255, green: 98/255, blue: 58/255)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(22)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Total Received")
                            .font(.urbanistRegular(13))
                            .foregroundColor(.white.opacity(0.72))
                        Text("LKR \(Self.currencyFormatter.string(for: viewModel.totalReceived) ?? "0.00")")
                            .font(.urbanistBold(30))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.18))
                            .frame(width: 58, height: 58)
                        Image(systemName: "banknote.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }

                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: 1)

                HStack(spacing: 28) {
                    summaryStatView(icon: "checkmark.circle.fill", value: "\(viewModel.payments.filter(\.isSuccess).count)", label: "Successful")
                    summaryStatView(icon: "cart.fill", value: "\(viewModel.payments.count)", label: "Payments")
                    Spacer()
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
        }
        .shadow(color: Color(red: 93/255, green: 55/255, blue: 20/255).opacity(0.32), radius: 16, x: 0, y: 7)
    }

    private func summaryStatView(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.80))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.urbanistBold(16))
                    .foregroundColor(.white)
                Text(label)
                    .font(.urbanistRegular(11))
                    .foregroundColor(.white.opacity(0.68))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                    .frame(width: 96, height: 96)
                Image(systemName: "creditcard")
                    .font(.system(size: 38))
                    .foregroundColor(.cakeBrown.opacity(0.55))
            }

            Text("No Payments Yet")
                .font(.urbanistBold(19))
                .foregroundColor(.cakePrimaryText)

            Text("Customer payments for your accepted bids will appear here.")
                .font(.urbanistRegular(14))
                .foregroundColor(.cakeGrey)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 44)
        }
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange.opacity(0.7))
            Text(message)
                .font(.urbanistRegular(14))
                .foregroundColor(.cakeGrey)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Retry") {
                Task { await viewModel.load(bakerID: user.id) }
            }
            .font(.urbanistSemiBold(14))
            .foregroundColor(.cakeBrown)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct BakerPaymentDetailsCard: View {
    let record: BakerPaymentDetailsRecord
    let dateFormatter: DateFormatter
    let currencyFormatter: NumberFormatter
    @State private var selectedReceipt: PDFReceiptData?

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(paymentMethodBackgroundColor)
                        .frame(width: 54, height: 54)
                    Image(systemName: paymentMethodIcon)
                        .font(.system(size: paymentMethodIconSize))
                        .foregroundColor(paymentMethodIconColor)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(record.cakeName)
                        .font(.urbanistBold(15))
                        .foregroundColor(.cakePrimaryText)
                        .lineLimit(1)

                    Text("Customer: \(record.customerName)")
                        .font(.urbanistRegular(13))
                        .foregroundColor(Color(red: 0.42, green: 0.42, blue: 0.42))

                    paymentMethodBadge
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 6) {
                    Text("LKR \(currencyFormatter.string(for: record.amount) ?? "0")")
                        .font(.urbanistBold(15))
                        .foregroundColor(.cakePrimaryText)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(record.isSuccess ? "Received" : record.status.capitalized)
                            .font(.urbanistSemiBold(11))
                            .foregroundColor(record.isSuccess ? Color(red: 0.10, green: 0.58, blue: 0.35) : .orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(record.isSuccess ? Color(red: 0.10, green: 0.58, blue: 0.35).opacity(0.11) : Color.orange.opacity(0.11))
                            .clipShape(Capsule())

                        Text(dateFormatter.string(from: record.paidAt))
                            .font(.urbanistRegular(10))
                            .foregroundColor(.cakeGrey)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Rectangle()
                .fill(Color(red: 0.92, green: 0.92, blue: 0.92))
                .frame(height: 1)
                .padding(.horizontal, 16)

            HStack {
                breakdownItem(label: "Baker Receives", value: "LKR \(Int(record.amount).formatted())", highlight: true)
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.75))
                Spacer()
                breakdownItem(label: "Service Fee", value: "LKR \(Int(record.serviceFee).formatted())")
                Spacer()
                Image(systemName: "equal")
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.75))
                Spacer()
                breakdownItem(label: "Customer Paid", value: "LKR \(Int(record.total).formatted())")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
        .background(Color.cakeSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.055), radius: 10, x: 0, y: 3)
        .contextMenu {
            Button {
                selectedReceipt = receiptData
            } label: {
                Label("View PDF Receipt", systemImage: "doc.richtext")
            }
        }
        .sheet(item: $selectedReceipt) { receipt in
            PDFReceiptPreviewView(receipt: receipt)
        }
    }

    private var receiptData: PDFReceiptData {
        PDFReceiptData(
            id: record.id,
            title: "Baker Payment Receipt",
            receiptNumber: record.id,
            cakeName: record.cakeName,
            payerLabel: "Customer",
            payerName: record.customerName,
            receiverLabel: "Baker",
            receiverName: "You",
            paymentMethod: paymentMethodText,
            status: record.status,
            paidAt: record.paidAt,
            subtotalLabel: "Baker Receives",
            subtotal: record.amount,
            serviceFee: record.serviceFee,
            totalLabel: "Customer Paid",
            total: record.total
        )
    }

    private var paymentMethodText: String {
        if record.isApplePay { return "Apple Pay" }
        if record.isGooglePay { return "Google Pay" }
        if record.isCash { return "Cash" }
        if record.cardLast4.isEmpty { return record.method.isEmpty ? "Card" : record.method }
        return "\(record.method) •••• \(record.cardLast4)"
    }

    private func breakdownItem(label: String, value: String, highlight: Bool = false) -> some View {
        VStack(alignment: .center, spacing: 3) {
            Text(value)
                .font(highlight ? .urbanistBold(12) : .urbanistSemiBold(12))
                .foregroundColor(highlight ? Color(hex: "5D3714") : Color(red: 0.22, green: 0.22, blue: 0.22))
            Text(label)
                .font(.urbanistRegular(10))
                .foregroundColor(.cakeGrey)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var paymentMethodIcon: String {
        if record.isApplePay { return "apple.logo" }
        if record.isGooglePay { return "g.circle.fill" }
        if record.isCash { return "banknote.fill" }
        return "creditcard.fill"
    }

    private var paymentMethodIconSize: CGFloat {
        record.isApplePay ? 22 : 20
    }

    private var paymentMethodIconColor: Color {
        if record.isApplePay { return .black }
        if record.isGooglePay { return Color(red: 0.2, green: 0.5, blue: 0.95) }
        if record.isCash { return Color(red: 0.2, green: 0.65, blue: 0.2) }
        return .cakeBrown
    }

    private var paymentMethodBackgroundColor: Color {
        if record.isApplePay { return Color.black.opacity(0.07) }
        if record.isGooglePay { return Color(red: 0.2, green: 0.5, blue: 0.95).opacity(0.1) }
        if record.isCash { return Color(red: 0.2, green: 0.65, blue: 0.2).opacity(0.1) }
        return Color(red: 0.92, green: 0.90, blue: 0.87)
    }

    @ViewBuilder
    private var paymentMethodBadge: some View {
        if record.isApplePay {
            badge(icon: "apple.logo", text: "Apple Pay", color: .black, background: Color.black.opacity(0.08))
        } else if record.isGooglePay {
            badge(icon: "g.circle.fill", text: "Google Pay", color: Color(red: 0.2, green: 0.5, blue: 0.95), background: Color(red: 0.2, green: 0.5, blue: 0.95).opacity(0.1))
        } else if record.isCash {
            badge(icon: "banknote.fill", text: "Cash", color: Color(red: 0.2, green: 0.65, blue: 0.2), background: Color(red: 0.2, green: 0.65, blue: 0.2).opacity(0.1))
        } else {
            badge(icon: "creditcard.fill", text: fullCardNumber(record.cardLast4), color: Color(hex: "5D3714"), background: Color(red: 0.92, green: 0.88, blue: 0.83))
        }
    }

    private func badge(icon: String, text: String, color: Color, background: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.urbanistSemiBold(11))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(background)
        .clipShape(Capsule())
    }

    private func fullCardNumber(_ last4: String) -> String {
        last4.isEmpty ? "Card Payment" : "•••• •••• •••• \(last4)"
    }
}

#Preview {
    @State var tabSelection = 0
    return BakerProfileView(user: AppUser.mockBaker, parentTabSelection: $tabSelection)
}
