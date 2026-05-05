import SwiftUI
import MapKit
import FirebaseFirestore
import FirebaseAuth

// MARK: - Baker Home View
@MainActor
struct BakerHomeView: View {
    let user: AppUser
    @State private var bakerCity = ""
    @State private var filterCity: String? = nil
    @State private var showLocationSheet = false
    @State private var showAllMatching = false
    @State private var showAllOpen = false
    @State private var showAllActive = false
    @State private var selectedRequest: CakeRequest?
    @State private var showBidDetail = false
    @State private var profileAvatar: UIImage? = nil
    @StateObject private var matchingRequestsVM = BakerMatchingRequestsViewModel()
    @EnvironmentObject var notificationManager: NotificationManager

    // Live stats – loaded from Firestore
    @State private var activeOrdersList: [CakeOrder] = []
    @State private var upcomingDeliveriesCount: Int = 0
    @State private var earningsThisMonth: String = "LKR 0"
    @State private var isLoadingStats = false
    
    private var newRequests: Int {
        filteredRequests.count
    }

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
                Color.white.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // MARK: Header
                        bakerHeader
                            .padding(.bottom, 16)

                        // MARK: Location Banner
                        locationBanner
                            .padding(.horizontal, 20)
                            .padding(.bottom, 28)

                        // MARK: Stats Cards
                        statsSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 28)

                        // MARK: Matching Requests Preview
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Matching Requests", count: newRequests) {
                                showAllMatching = true
                            }
                            .padding(.horizontal, 20)

                            matchingRequestsPreview
                                .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 28)

                        // MARK: Active Orders Preview
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Active Orders", count: activeOrdersList.count) {
                                showAllActive = true
                            }
                            .padding(.horizontal, 20)

                            activeOrdersPreview
                        }
                        .padding(.bottom, 28)

                        // MARK: Other Open Requests
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Other Open Requests", count: 4) {
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
            .navigationDestination(isPresented: $showAllMatching) {
                BakerMatchingRequestsView()
            }
            .navigationDestination(isPresented: $showAllOpen) {
                EmptyView()
            }
            .navigationDestination(isPresented: $showAllActive) {
                BakerOrdersView(user: user)
            }
            .sheet(isPresented: $showLocationSheet) {
                LocationPickerSheet(filterCity: $filterCity)
            }
            .task {
                await matchingRequestsVM.loadMatchingRequests()
                await loadLiveStats()
            }
            .onAppear {
                loadProfileAvatar()
                loadBakerCity()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("profileAvatarUpdated"))) { _ in
                loadProfileAvatar()
            }
            .onReceive(NotificationCenter.default.publisher(for: .bidDidChange)) { _ in
                Task {
                    await matchingRequestsVM.loadMatchingRequests()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .orderDidChange)) { _ in
                Task { await loadLiveStats() }
            }
        }
    }

    // MARK: - Header
    private var bakerHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Group {
                if let profileAvatar = profileAvatar {
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

            VStack(alignment: .leading, spacing: 2) {
                Text(greetingText())
                    .font(.urbanistRegular(13))
                    .foregroundColor(.cakeGrey)
                Text(user.name.isEmpty ? user.email : user.name)
                    .font(.urbanistSemiBold(15))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    .lineLimit(1)
            }

            Spacer()

            NotificationBellButton(notificationService: notificationManager.notificationService, userType: "baker")
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
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
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
                    title: "\(activeOrdersList.count)",
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
                    title: "\(upcomingDeliveriesCount)",
                    subtitle: "Upcoming Deliveries",
                    cardBg:   Color(red: 237/255, green: 246/255, blue: 255/255),
                    squareBg: Color(red: 220/255, green: 237/255, blue: 255/255),
                    iconColor: Color(red:  35/255, green:  83/255, blue: 143/255)
                )
                statCard(
                    icon: "banknote.fill",
                    title: earningsThisMonth,
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
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
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
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
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
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Complete Your Profile")
                                .font(.urbanistSemiBold(14))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            Text("Add specialties to see matching requests")
                                .font(.urbanistRegular(12))
                                .foregroundColor(.cakeGrey)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(Color(red: 1, green: 0.95, blue: 0.88))
                    .cornerRadius(12)
                }
            } else if matchingRequestsVM.matchingRequests.isEmpty {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.cakeGrey.opacity(0.5))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No Matching Requests")
                                .font(.urbanistSemiBold(14))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            Text("Check back soon for requests matching your specialties")
                                .font(.urbanistRegular(12))
                                .foregroundColor(.cakeGrey)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(Color(red: 0.97, green: 0.96, blue: 0.94))
                    .cornerRadius(12)
                }
            } else if filteredRequests.isEmpty {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 20))
                            .foregroundColor(.cakeGrey.opacity(0.5))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No Requests in \(filterCity ?? "")")
                                .font(.urbanistSemiBold(14))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            Text("Try selecting a different city or \"None\" to see all requests")
                                .font(.urbanistRegular(12))
                                .foregroundColor(.cakeGrey)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(Color(red: 0.97, green: 0.96, blue: 0.94))
                    .cornerRadius(12)
                }
            } else {
                ForEach(Array(filteredRequests.prefix(2))) { cakeReq in
                    let req = cakeReq.toCakeRequest()
                    MatchingRequestCard(request: req) {
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
            if isLoadingStats {
                // Loading skeleton — horizontal scrolling circles
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
            } else if activeOrdersList.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cart.badge.plus")
                        .font(.system(size: 34))
                        .foregroundColor(.cakeBrown.opacity(0.35))
                    Text("No active orders yet")
                        .font(.urbanistSemiBold(13))
                        .foregroundColor(.cakeGrey)
                    Text("New orders will appear here once customers place them")
                        .font(.urbanistRegular(12))
                        .foregroundColor(.cakeGrey.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            } else {
                // Horizontal scrolling circles — mirrors customer home screen
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(activeOrdersList) { order in
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
                                    Text("Order No:\n\(order.id.prefix(6))")
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

    // MARK: - Other Open Requests Preview
    private var otherOpenRequestsPreview: some View {
        VStack(spacing: 12) {
            ForEach(mockOtherRequests.prefix(2)) { req in
                NavigationLink(destination: BakerBidDetailView(request: req)) {
                    OtherRequestCard(request: req)
                }
                .buttonStyle(.plain)
            }
        }
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

    private func loadProfileAvatar() {
        guard let base64String = UserDefaults.standard.string(forKey: "profileAvatar_\(user.id)") else {
            profileAvatar = nil
            return
        }

        guard let imageData = Data(base64Encoded: base64String) else {
            profileAvatar = nil
            return
        }

        profileAvatar = UIImage(data: imageData)
    }

    private func loadBakerCity() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        Task {
            do {
                let doc = try await db.collection("artisans").document(uid).getDocument()
                if let city = doc.data()?["city"] as? String, !city.isEmpty {
                    bakerCity = city
                    if filterCity == nil {
                        filterCity = city
                    }
                }
            } catch {
                print("Failed to load baker city: \(error)")
            }
        }
    }

    // MARK: - Live Stats Loader
    private func loadLiveStats() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoadingStats = true
        await loadActiveOrders(bakerUID: uid)
        await loadEarningsThisMonth(bakerUID: uid)
        isLoadingStats = false
    }

    private func loadActiveOrders(bakerUID: String) async {
        let db = Firestore.firestore()
        let statuses = ["confirmed", "baking", "decorating", "quality_check"]
        var seen = Set<String>()
        var orders: [CakeOrder] = []
        do {
            for key in ["artisanId", "bakerID", "bakerId"] {
                let snap = try await db.collection("orders")
                    .whereField(key, isEqualTo: bakerUID)
                    .whereField("status", in: statuses)
                    .getDocuments()
                for doc in snap.documents {
                    guard !seen.contains(doc.documentID),
                          let order = CakeOrder(document: doc) else { continue }
                    seen.insert(doc.documentID)
                    orders.append(order)
                }
            }
        } catch {
            print("BakerHome: active orders error – \(error.localizedDescription)")
        }
        activeOrdersList = orders.sorted { $0.deliveryDate < $1.deliveryDate }
        // Upcoming deliveries = the 5 with the closest delivery dates
        upcomingDeliveriesCount = min(5, activeOrdersList.count)
    }

    private func loadEarningsThisMonth(bakerUID: String) async {
        let db = Firestore.firestore()
        let statuses = ["completed", "delivered", "done"]
        var seen = Set<String>()
        var completed: [CakeOrder] = []
        do {
            for key in ["artisanId", "bakerID", "bakerId"] {
                let snap = try await db.collection("orders")
                    .whereField(key, isEqualTo: bakerUID)
                    .whereField("status", in: statuses)
                    .getDocuments()
                for doc in snap.documents {
                    guard !seen.contains(doc.documentID),
                          let order = CakeOrder(document: doc) else { continue }
                    seen.insert(doc.documentID)
                    completed.append(order)
                }
            }
        } catch {
            print("BakerHome: earnings error – \(error.localizedDescription)")
        }
        let cal = Calendar.current
        let now = Date()
        let thisMonth = cal.component(.month, from: now)
        let thisYear  = cal.component(.year,  from: now)
        let monthly = completed.filter {
            cal.component(.month, from: $0.deliveryDate) == thisMonth &&
            cal.component(.year,  from: $0.deliveryDate) == thisYear
        }
        // Consistent with BakerOrdersView: 3,500 LKR per completed order
        let total = Double(monthly.count) * 3_500
        if total >= 1_000_000 {
            earningsThisMonth = String(format: "LKR %.1fM", total / 1_000_000)
        } else if total >= 1_000 {
            earningsThisMonth = String(format: "LKR %.0fK", total / 1_000)
        } else {
            earningsThisMonth = String(format: "LKR %.0f", total)
        }
    }
}

// MARK: - Location Picker Sheet
struct LocationPickerSheet: View {
    @Binding var filterCity: String?
    @Environment(\.dismiss) private var dismiss

    @State private var localSelection: String?

    private let districts = SriLankaDistricts.all

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Select City to Filter")
                        .font(.urbanistSemiBold(15))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        // None option — shows all matching requests
                        districtButton(title: "None", isSelected: localSelection == nil) {
                            localSelection = nil
                        }

                        ForEach(districts, id: \.self) { district in
                            districtButton(title: district, isSelected: localSelection == district) {
                                localSelection = district
                            }
                        }
                    }

                    Button {
                        filterCity = localSelection
                        dismiss()
                    } label: {
                        Text("Confirm")
                            .font(.urbanistBold(16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.cakeBrown)
                            .cornerRadius(16)
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .navigationTitle("Filter by City")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { localSelection = filterCity }
        .presentationDetents([.medium, .large])
    }

    private func districtButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.urbanistMedium(14))
                .foregroundColor(isSelected ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.cakeBrown : Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.clear : Color(red: 0.88, green: 0.88, blue: 0.88), lineWidth: 1)
                )
        }
    }
}

// MARK: - Matching Request Card (used on Home + Matching screen)
struct MatchingRequestCard: View {
    let request: CakeRequest
    var onPlaceBid: (() -> Void)? = nil

    private let pastelPalette: [Color] = [
        Color(red: 0.95, green: 0.84, blue: 0.92),
        Color(red: 0.98, green: 0.86, blue: 0.82),
        Color(red: 0.97, green: 0.93, blue: 0.78),
        Color(red: 0.86, green: 0.93, blue: 0.98),
        Color(red: 0.87, green: 0.95, blue: 0.88),
        Color(red: 0.91, green: 0.88, blue: 0.98)
    ]

    private var chipColor: Color {
        let index = abs(request.category.name.hashValue) % pastelPalette.count
        return pastelPalette[index]
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Main Content ──────────────────────────────
            HStack(alignment: .top, spacing: 12) {
                // Reference image or Category icon
                if !request.referenceImages.isEmpty,
                   let imageData = Data(base64Encoded: request.referenceImages[0]),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .cornerRadius(10)
                        .clipped()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(chipColor.opacity(0.8))
                            .frame(width: 80, height: 80)
                        Image(systemName: request.category.icon)
                            .font(.system(size: 28))
                            .foregroundColor(Color(red: 0.32, green: 0.23, blue: 0.16))
                    }
                }

                // Right content — height locked to image height
                VStack(alignment: .leading, spacing: 0) {
                    Text(request.title)
                        .font(.urbanistBold(14))
                        .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12))
                        .lineLimit(2)

                    Spacer()

                    // Row 1: Category chip + Date (date right-aligned)
                    HStack(spacing: 6) {
                        Text(request.category.name)
                            .font(.urbanistMedium(10))
                            .foregroundColor(Color(red: 0.32, green: 0.23, blue: 0.16))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(chipColor)
                            .cornerRadius(6)

                        Spacer()

                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text(request.deliveryDate)
                                .font(.urbanistRegular(10))
                        }
                        .foregroundColor(.cakeGrey)
                    }

                    Spacer(minLength: 12)

                    // Row 2: Customer city (from DB) + Bid count (bids right-aligned)
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 10))
                            .foregroundColor(.cakeGrey)
                        Text(request.location)
                            .font(.urbanistRegular(11))
                            .foregroundColor(.cakeGrey)
                            .lineLimit(1)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10))
                            Text("\(request.bidCount) bids")
                                .font(.urbanistMedium(10))
                        }
                        .foregroundColor(.cakeBrown)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.cakeBrown.opacity(0.10))
                        .cornerRadius(6)
                    }
                }
                .frame(height: 80)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // ── Divider ──────────────────────────────────
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 14)

            // ── Bottom Bar ───────────────────────────────
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Budget (LKR)")
                        .font(.urbanistRegular(10))
                        .foregroundColor(.cakeGrey)
                    Text(request.budgetRange)
                        .font(.urbanistBold(13))
                        .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12))
                }

                Spacer()

                if let onPlaceBid = onPlaceBid {
                    Button(action: onPlaceBid) {
                        Text("Place Bid")
                            .font(.urbanistSemiBold(15))
                            .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.082))
                            .frame(width: 120)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.906, green: 0.871, blue: 0.847))
                            .cornerRadius(9)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(height: 155)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.09), radius: 10, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Other Request Card
struct OtherRequestCard: View {
    let request: CakeRequest

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.3, green: 0.45, blue: 0.8).opacity(0.1))
                    .frame(width: 56, height: 56)
                Image(systemName: request.category.icon)
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 0.3, green: 0.45, blue: 0.8))
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(request.title)
                        .font(.urbanistSemiBold(15))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    Spacer()
                    Text(request.budgetRange)
                        .font(.urbanistBold(13))
                        .foregroundColor(Color(red: 0.3, green: 0.45, blue: 0.8))
                }
                HStack(spacing: 6) {
                    Image(systemName: "birthday.cake")
                        .font(.system(size: 10))
                    Text(request.category.name)
                        .font(.urbanistRegular(12))
                    Text("•")
                    Text(request.location)
                        .font(.urbanistRegular(12))
                }
                .foregroundColor(.cakeGrey)

                HStack {
                    Text(request.deliveryDate)
                        .font(.urbanistRegular(12))
                        .foregroundColor(.cakeGrey)
                    Spacer()
                    Text("Can you do this?")
                        .font(.urbanistSemiBold(11))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.cakeBrown)
                        .cornerRadius(8)
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Baker Active Order Card
struct BakerActiveOrderCard: View {
    let order: BakerOrder

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(order.statusColor.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: "bag.fill")
                    .font(.system(size: 22))
                    .foregroundColor(order.statusColor)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(order.cakeName)
                        .font(.urbanistSemiBold(15))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    Spacer()
                    Text(order.statusLabel)
                        .font(.urbanistMedium(11))
                        .foregroundColor(order.statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(order.statusColor.opacity(0.1))
                        .cornerRadius(8)
                }
                Text("Customer: \(order.customerName)")
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeGrey)
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text("Deliver by \(order.deliveryDate)")
                        .font(.urbanistRegular(12))
                    Spacer()
                    Text(order.amount)
                        .font(.urbanistBold(14))
                        .foregroundColor(.cakeBrown)
                }
                .foregroundColor(.cakeGrey)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Mock Data Models
struct CakeRequest: Identifiable {
    let id: String
    let requestDocumentID: String
    let customerID: String
    let title: String
    let category: CakeCategory
    let location: String
    let deliveryDate: String
    let budgetRange: String
    let bidCount: Int
    let description: String
    let servings: Int
    let flavours: [String]
    let customerName: String
    let postedTime: String
    let referenceImages: [String]
    var isMatching: Bool = true
    
    init(
        id: String = UUID().uuidString,
        requestDocumentID: String = "",
        customerID: String = "",
        title: String,
        category: CakeCategory,
        location: String,
        deliveryDate: String,
        budgetRange: String,
        bidCount: Int,
        description: String,
        servings: Int,
        flavours: [String],
        customerName: String,
        postedTime: String,
        referenceImages: [String] = [],
        isMatching: Bool = true
    ) {
        self.id = id
        self.requestDocumentID = requestDocumentID
        self.customerID = customerID
        self.title = title
        self.category = category
        self.location = location
        self.deliveryDate = deliveryDate
        self.budgetRange = budgetRange
        self.bidCount = bidCount
        self.description = description
        self.servings = servings
        self.flavours = flavours
        self.customerName = customerName
        self.postedTime = postedTime
        self.referenceImages = referenceImages
        self.isMatching = isMatching
    }
}

struct CakeCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
}

struct BakerOrder: Identifiable {
    let id = UUID()
    let cakeName: String
    let customerName: String
    let deliveryDate: String
    let status: String
    let amount: String

    var statusColor: Color {
        switch status {
        case "baking":    return Color.orange
        case "decorating": return Color(red: 0.3, green: 0.45, blue: 0.8)
        case "ready":     return Color.green
        default:          return Color.cakeBrown
        }
    }
    var statusLabel: String {
        switch status {
        case "baking":    return "Baking"
        case "decorating": return "Decorating"
        case "ready":     return "Ready"
        default:          return "Confirmed"
        }
    }
}

// MARK: - Mock Data
let mockMatchingRequests: [CakeRequest] = [
    CakeRequest(title: "3-Tier Wedding Cake", category: CakeCategory(name: "Wedding", icon: "heart.fill"), location: "Colombo 07", deliveryDate: "Apr 12, 2026", budgetRange: "LKR 15,000–25,000", bidCount: 3, description: "Looking for a luxurious 3-tier wedding cake with white fondant, gold accents and floral decorations. Serves around 150 guests.", servings: 150, flavours: ["Vanilla", "Chocolate"], customerName: "Amali Perera", postedTime: "2 hrs ago"),
    CakeRequest(title: "Unicorn Birthday Cake", category: CakeCategory(name: "Birthday", icon: "birthday.cake.fill"), location: "Nugegoda", deliveryDate: "Apr 09, 2026", budgetRange: "LKR 5,000–8,000", bidCount: 5, description: "Need a magical unicorn theme birthday cake for my daughter's 5th birthday. Pink and purple colours preferred.", servings: 20, flavours: ["Strawberry", "Vanilla"], customerName: "Nimal Silva", postedTime: "5 hrs ago"),
    CakeRequest(title: "Corporate Anniversary Cake", category: CakeCategory(name: "Corporate", icon: "building.2.fill"), location: "Colombo 03", deliveryDate: "Apr 15, 2026", budgetRange: "LKR 10,000–18,000", bidCount: 2, description: "Elegant corporate cake for our 10th anniversary event. Should include company logo (edible print).", servings: 80, flavours: ["Chocolate", "Red Velvet"], customerName: "Saman Fernando", postedTime: "1 day ago"),
]

let mockActiveOrders: [BakerOrder] = [
    BakerOrder(cakeName: "Wedding Cake — 2 Tier", customerName: "Kavya Naidoo", deliveryDate: "Apr 08, 2026", status: "baking", amount: "LKR 18,500"),
    BakerOrder(cakeName: "Chocolate Fondant Cake", customerName: "Rohan Gupta", deliveryDate: "Apr 10, 2026", status: "decorating", amount: "LKR 6,200"),
]

let mockOtherRequests: [CakeRequest] = [
    CakeRequest(title: "Japanese Cheesecake", category: CakeCategory(name: "Dessert", icon: "fork.knife"), location: "Dehiwala", deliveryDate: "Apr 11, 2026", budgetRange: "LKR 3,500–5,000", bidCount: 1, description: "Fluffy Japanese-style cheesecake, 8-inch diameter.", servings: 10, flavours: ["Cheese"], customerName: "Priya Raj", postedTime: "3 hrs ago", isMatching: false),
    CakeRequest(title: "Gluten-Free Carrot Cake", category: CakeCategory(name: "Special Diet", icon: "leaf.fill"), location: "Mount Lavinia", deliveryDate: "Apr 13, 2026", budgetRange: "LKR 4,000–6,000", bidCount: 0, description: "Gluten-free carrot cake with cream cheese frosting. No nuts.", servings: 15, flavours: ["Carrot"], customerName: "Layla Ahmad", postedTime: "6 hrs ago", isMatching: false),
    CakeRequest(title: "Geode Crystal Cake", category: CakeCategory(name: "Artistic", icon: "sparkles"), location: "Rajagiriya", deliveryDate: "Apr 16, 2026", budgetRange: "LKR 12,000–20,000", bidCount: 2, description: "Stunning geode-style cake with sugar crystals in blue and purple tones.", servings: 40, flavours: ["Vanilla", "Blueberry"], customerName: "Malini Senanayake", postedTime: "8 hrs ago", isMatching: false),
]

#Preview {
    BakerHomeView(user: AppUser.mockBaker)
}
