import SwiftUI
import MapKit

// MARK: - Baker Home View
@MainActor
struct BakerHomeView: View {
    let user: AppUser
    @Binding var selectedTab: Int
    @State private var filterCity: String? = nil
    @State private var showLocationSheet = false
    @State private var showAllOpen = false
    @State private var selectedRequest: CakeRequest?
    @State private var showBidDetail = false
    @StateObject private var matchingRequestsVM = BakerMatchingRequestsViewModel()
    @StateObject private var homeVM = BakerHomeViewModel()
    @EnvironmentObject var notificationManager: NotificationManager
    
    private var newRequests: Int { filteredRequests.count }

    private var filteredRequests: [CakeRequestRecord] {
        guard let city = filterCity, !city.isEmpty else {
            return matchingRequestsVM.matchingRequests
        }
        return matchingRequestsVM.matchingRequests.filter {
            $0.customerCity.lowercased() == city.lowercased()
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.cakeBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header with avatar, greeting, and notifications.
                        bakerHeader
                            .padding(.bottom, 16)

                        // Location filter banner.
                        locationBanner
                            .padding(.horizontal, 20)
                            .padding(.bottom, 28)

                        // Dashboard stats cards.
                        statsSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 28)

                        // Matching requests preview cards.
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Matching Requests", count: newRequests) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedTab = 1
                                }
                            }
                            .padding(.horizontal, 20)

                            matchingRequestsPreview
                                .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 28)

                        // MARK: Active Orders Preview
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Active Orders", count: homeVM.activeOrdersList.count) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedTab = 2
                                }
                            }
                            .padding(.horizontal, 20)

                            activeOrdersPreview
                        }
                        .padding(.bottom, 28)

                        // MARK: Other Open Requests
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Other Open Requests", count: matchingRequestsVM.otherOpenRequests.count) {
                                showAllOpen = true
                            }
                            .padding(.horizontal, 20)

                            otherOpenRequestsPreview
                                .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 100)
                    }
                }
                
                NavigationLink(
                    // Hidden navigation link to bid detail form.
                    destination: Group {
                        if let req = selectedRequest {
                            BakerBidDetailView(request: req)
                        }
                    },
                    isActive: $showBidDetail
                ) {
                    EmptyView()
                }
                .hidden()
            }
            .navigationDestination(isPresented: $showAllOpen) {
                // Full list of other open requests.
                BakerOtherRequestsView(viewModel: matchingRequestsVM)
            }
            .sheet(isPresented: $showLocationSheet) {
                // City filter picker for matching requests.
                LocationPickerSheet(filterCity: $filterCity)
            }
            .task {
                // Load request previews and live home stats.
                await matchingRequestsVM.loadMatchingRequests()
                await homeVM.loadLiveStats()
            }
            .onAppear {
                // Load profile avatar and default city filter.
                homeVM.loadProfileAvatar(userID: user.id)
                homeVM.loadBakerCity()
            }
            .onChange(of: homeVM.bakerCity) { _, city in
                if filterCity == nil, !city.isEmpty {
                    filterCity = city
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("profileAvatarUpdated"))) { _ in
                homeVM.loadProfileAvatar(userID: user.id)
            }
            .onReceive(NotificationCenter.default.publisher(for: .bidDidChange)) { _ in
                Task { await matchingRequestsVM.loadMatchingRequests() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .orderDidChange)) { _ in
                Task { await homeVM.loadLiveStats() }
            }
        }
    }

    // MARK: - Header
    private var bakerHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedTab = 3
                }
            } label: {
                if let profileAvatar = homeVM.profileAvatar {
                    Image(uiImage: profileAvatar)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.90, green: 0.86, blue: 0.82))
                            .frame(width: 48, height: 48)
                        Image(systemName: "person.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.cakeBrown)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(greetingText())
                    .font(.urbanistRegular(13))
                    .foregroundColor(.cakeGrey)
                Text(user.name.isEmpty ? user.email : user.name)
                    .font(.urbanistSemiBold(15))
                    .foregroundColor(.cakePrimaryText)
                    .lineLimit(1)
            }

            Spacer()

            NotificationBellButton(notificationService: notificationManager.notificationService, userType: "baker", userID: user.id)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Location Banner
    private var locationBanner: some View {
        VStack(alignment: .center, spacing: 0) {
            Text("Matching Cake Requests")
                .font(.urbanistBold(17))
                .foregroundColor(.cakePrimaryText)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 10)

            Text(locationBannerSubtitle)
                .font(.urbanistRegular(12))
                .foregroundColor(Color(red: 95/255, green: 95/255, blue: 95/255))
                .lineSpacing(3)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 16)

            Button { showLocationSheet = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text(locationFilterButtonText)
                        .font(.urbanistSemiBold(13))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.cakeBrown)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 22)
        .background(Color(red: 235/255, green: 228/255, blue: 222/255))
        .cornerRadius(16)
    }

    private var locationFilterButtonText: String {
        if let city = filterCity, !city.isEmpty {
            return "location based filter is active for \(city)"
        }
        return "showing all matching requests – tap to filter"
    }

    private var locationBannerSubtitle: String {
        if let city = filterCity, !city.isEmpty {
            return "Explore customer requests near \(city) that match your expertise and specialties."
        }
        return "Explore all customer requests that match your expertise and specialties."
    }

    // MARK: - Stats
    private var statsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statCard(
                    icon: "bag.fill",
                    title: "\(homeVM.activeOrdersList.count)",
                    subtitle: "Active Orders",
                    cardBg:   Color(red: 248/255, green: 240/255, blue: 249/255),
                    squareBg: Color(red: 228/255, green: 185/255, blue: 230/255),
                    iconColor: Color(red: 110/255, green:  61/255, blue: 113/255)
                )
                statCard(
                    icon: "sparkles",
                    title: "\(newRequests)",
                    subtitle: "New Matching",
                    cardBg:   Color(red: 245/255, green: 245/255, blue: 254/255),
                    squareBg: Color(red: 219/255, green: 220/255, blue: 255/255),
                    iconColor: Color(red:  98/255, green:  81/255, blue: 162/255)
                )
            }
            HStack(spacing: 12) {
                statCard(
                    icon: "calendar.badge.clock",
                    title: "\(homeVM.upcomingDeliveriesCount)",
                    subtitle: "Upcoming Deliveries",
                    cardBg:   Color(red: 237/255, green: 246/255, blue: 255/255),
                    squareBg: Color(red: 220/255, green: 237/255, blue: 255/255),
                    iconColor: Color(red:  35/255, green:  83/255, blue: 143/255)
                )
                statCard(
                    icon: "banknote.fill",
                    title: homeVM.earningsThisMonth,
                    subtitle: "Earnings This Month",
                    cardBg:   Color(red: 245/255, green: 254/255, blue: 245/255),
                    squareBg: Color(red: 199/255, green: 230/255, blue: 195/255),
                    iconColor: Color(red:  68/255, green: 108/255, blue:  42/255)
                )
            }
        }
    }

    private func statCard(icon: String, title: String, subtitle: String,
                          cardBg: Color, squareBg: Color, iconColor: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(squareBg)
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.urbanistBold(18))
                    .foregroundColor(.cakePrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(.urbanistRegular(11))
                    .foregroundColor(.cakeGrey)
            }
            Spacer()
        }
        .padding(14)
        .background(cardBg)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section Header
    private func sectionHeader(_ title: String, count: Int, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.urbanistBold(15))
                .foregroundColor(.cakePrimaryText)
            Spacer()
            Button(action: action) {
                Text("See all")
                    .font(.urbanistSemiBold(13))
                    .foregroundColor(.cakeBrown)
            }
        }
    }

    // MARK: - Matching Requests Preview
    private var matchingRequestsPreview: some View {
        VStack(spacing: 12) {
            if matchingRequestsVM.isLoading {
                // Loading state for matching request cards.
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.cakeBrown)
                    Text("Loading matching requests...")
                        .font(.urbanistRegular(13))
                        .foregroundColor(.cakeGrey)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(20)
            } else if matchingRequestsVM.bakerSpecialties.isEmpty {
                homeEmptyState(
                    icon: "person.crop.circle.badge.plus",
                    title: "Complete your profile",
                    message: "Add specialties to see matching customer requests.",
                    iconColor: Color.cakeBrown.opacity(0.35)
                )
            } else if matchingRequestsVM.matchingRequests.isEmpty {
                homeEmptyState(
                    icon: "sparkles",
                    title: "No matching requests yet",
                    message: "Requests that match your specialties will appear here.",
                    iconColor: Color.cakeBrown.opacity(0.35)
                )
            } else if filteredRequests.isEmpty {
                homeEmptyState(
                    icon: "mappin.slash",
                    title: "No requests in \(filterCity ?? "this city")",
                    message: "Try another city or clear the filter to see all requests.",
                    iconColor: Color.cakeBrown.opacity(0.35)
                )
            } else {
                ForEach(Array(filteredRequests.prefix(2))) { cakeReq in
                    let req = cakeReq.toCakeRequest()
                    MatchingRequestCard(request: req) {
                        // Open bid detail from matching card.
                        selectedRequest = req
                        showBidDetail = true
                    }
                }
            }
        }
    }

    // MARK: - Active Orders Preview
    private var activeOrdersPreview: some View {
        Group {
            if homeVM.isLoadingStats {
                // Loading skeleton for active order preview.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(0..<3, id: \.self) { _ in
                            VStack(spacing: 10) {
                                Circle()
                                    .fill(Color(red: 0.91, green: 0.91, blue: 0.91))
                                    .frame(width: 90, height: 90)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(red: 0.91, green: 0.91, blue: 0.91))
                                    .frame(width: 68, height: 22)
                            }
                            .frame(width: 100)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
            } else if homeVM.activeOrdersList.isEmpty {
                activeOrdersEmptyState
            } else {
                // Horizontal active order cards.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(homeVM.activeOrdersList) { order in
                            NavigationLink {
                                BakerOrderStatusView(orderID: order.id)
                            } label: {
                                VStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .stroke(Color(red: 0.15, green: 0.65, blue: 0.22), lineWidth: 2.5)
                                            .frame(width: 90, height: 90)
                                        Circle()
                                            .fill(Color(red: 0.93, green: 0.91, blue: 0.88))
                                            .frame(width: 82, height: 82)
                                        if !order.referenceImages.isEmpty,
                                           let imageData = Data(base64Encoded: order.referenceImages[0]),
                                           let uiImage = UIImage(data: imageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 74, height: 74)
                                                .clipShape(Circle())
                                        } else {
                                            Image(systemName: "birthday.cake.fill")
                                                .font(.system(size: 30))
                                                .foregroundColor(.cakeBrown.opacity(0.45))
                                        }
                                    }
                                    Text("Order No:\n\(String(order.id.prefix(6)).uppercased())")
                                        .font(.urbanistRegular(11))
                                        .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(width: 100)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var activeOrdersEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 34))
                .foregroundColor(.cakeGrey.opacity(0.6))
            Text("No active orders yet")
                .font(.urbanistRegular(14))
                .foregroundColor(.cakeGrey)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
    }

    // MARK: - Other Open Requests Preview
    private var otherOpenRequestsPreview: some View {
        VStack(spacing: 12) {
            if matchingRequestsVM.isLoading {
                // Loading state for other open requests.
                ProgressView()
                    .tint(.cakeBrown)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(20)
            } else if matchingRequestsVM.otherOpenRequests.isEmpty {
                homeEmptyState(
                    icon: "tray",
                    title: "No other open requests yet",
                    message: "Requests outside your specialties will appear here when available.",
                    iconColor: Color.cakeBrown.opacity(0.35)
                )
            } else {
                ForEach(Array(matchingRequestsVM.otherOpenRequests.prefix(3))) { record in
                    let req = record.toCakeRequest()
                    MatchingRequestCard(
                        request: req,
                        onPlaceBid: {
                            // Open bid detail for an open request.
                            selectedRequest = req
                            showBidDetail = true
                        },
                        buttonTitle: "Can you do this?"
                    )
                }
            }
        }
    }

    private func homeEmptyState(
        icon: String,
        title: String,
        message: String,
        iconColor: Color
    ) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundColor(iconColor)
            Text(title)
                .font(.urbanistSemiBold(13))
                .foregroundColor(.cakeGrey)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.urbanistRegular(12))
                .foregroundColor(.cakeGrey.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    private func greetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<21: return "Good Evening"
        default:      return "Good Night"
        }
    }

}

#Preview {
    BakerHomeView(user: AppUser.mockBaker, selectedTab: .constant(0))
}
