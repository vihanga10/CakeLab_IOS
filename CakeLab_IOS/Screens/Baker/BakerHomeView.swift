import SwiftUI
import MapKit

// MARK: - Baker Home View
@MainActor
struct BakerHomeView: View {
    let user: AppUser
    @State private var isLocationActive = true
    @State private var selectedCity = "Colombo"
    @State private var showLocationSheet = false
    @State private var showAllMatching = false
    @State private var showAllOpen = false
    @State private var showAllActive = false
    @State private var selectedRequest: CakeRequest?
    @State private var showBidDetail = false
    @StateObject private var matchingRequestsVM = BakerMatchingRequestsViewModel()
    @EnvironmentObject var notificationManager: NotificationManager

    // Mock stats
    private let activeOrders = 3
    private let upcomingDeliveries = 2
    private let earnings = "LKR 48,500"
    
    private var newRequests: Int {
        matchingRequestsVM.matchingRequests.count
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(red: 0.97, green: 0.96, blue: 0.94).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // MARK: Header
                        bakerHeader
                            .padding(.bottom, 16)

                        // MARK: Location Banner
                        locationBanner
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        // MARK: Stats Cards
                        statsSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)

                        // MARK: Matching Requests Preview
                        sectionHeader("Matching Requests", count: newRequests) {
                            showAllMatching = true
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                        matchingRequestsPreview
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)

                        // MARK: Active Orders Preview
                        sectionHeader("Active Orders", count: activeOrders) {
                            showAllActive = true
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                        activeOrdersPreview
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)

                        // MARK: Other Open Requests
                        sectionHeader("Other Open Requests", count: 4) {
                            showAllOpen = true
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                        otherOpenRequestsPreview
                            .padding(.horizontal, 20)
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
                LocationPickerSheet(selectedCity: $selectedCity, isActive: $isLocationActive)
            }
            .task {
                await matchingRequestsVM.loadMatchingRequests()
            }
            .onReceive(NotificationCenter.default.publisher(for: .bidDidChange)) { _ in
                Task {
                    await matchingRequestsVM.loadMatchingRequests()
                }
            }
        }
    }

    // MARK: - Header
    private var bakerHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText())
                    .font(.urbanistRegular(14))
                    .foregroundColor(.cakeGrey)
                Text(user.name.isEmpty ? "Baker" : user.name)
                    .font(.urbanistBold(22))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                Text("Ready to bake something amazing?")
                    .font(.urbanistRegular(13))
                    .foregroundColor(.cakeGrey)
            }
            Spacer()
            HStack(spacing: 12) {
                // Notification bell
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.black.opacity(0.07), radius: 4, x: 0, y: 2)
                    NotificationBellButton(notificationService: notificationManager.notificationService, userType: "baker")
                }
                // Avatar
                Circle()
                    .fill(Color.cakeBrown.opacity(0.18))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(user.name.prefix(1)).uppercased())
                            .font(.urbanistBold(18))
                            .foregroundColor(.cakeBrown)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    // MARK: - Location Banner
    private var locationBanner: some View {
        Button { showLocationSheet = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isLocationActive ? Color.green.opacity(0.15) : Color.gray.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: isLocationActive ? "location.fill" : "location.slash")
                        .font(.system(size: 15))
                        .foregroundColor(isLocationActive ? .green : .gray)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(isLocationActive ? "Location Filter Active" : "Location Filter Off")
                        .font(.urbanistSemiBold(13))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    Text(isLocationActive ? "Showing requests near \(selectedCity)" : "Tap to enable location filtering")
                        .font(.urbanistRegular(12))
                        .foregroundColor(.cakeGrey)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.cakeGrey)
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats
    private var statsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statCard(icon: "bag.fill", title: "\(activeOrders)", subtitle: "Active Orders", color: Color.cakeBrown)
                statCard(icon: "sparkles", title: "\(newRequests)", subtitle: "New Matching", color: Color(red: 0.2, green: 0.6, blue: 0.4))
            }
            HStack(spacing: 12) {
                statCard(icon: "calendar.badge.clock", title: "\(upcomingDeliveries)", subtitle: "Upcoming Deliveries", color: Color(red: 0.3, green: 0.45, blue: 0.8))
                statCard(icon: "banknote.fill", title: earnings, subtitle: "Earnings This Month", color: Color(red: 0.7, green: 0.45, blue: 0.1))
            }
        }
    }

    private func statCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
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
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section Header
    private func sectionHeader(_ title: String, count: Int, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.urbanistBold(17))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            Spacer()
            Button(action: action) {
                HStack(spacing: 4) {
                    Text("See all")
                        .font(.urbanistSemiBold(13))
                    Text("(\(count))")
                        .font(.urbanistRegular(12))
                }
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
            } else {
                ForEach(matchingRequestsVM.matchingRequests.prefix(2)) { cakeReq in
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
        VStack(spacing: 12) {
            ForEach(mockActiveOrders.prefix(2)) { order in
                BakerActiveOrderCard(order: order)
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
        case 5..<12: return "Good Morning ☀️"
        case 12..<17: return "Good Afternoon 🌤️"
        case 17..<21: return "Good Evening 🌙"
        default:      return "Good Night 🌙"
        }
    }
}

// MARK: - Location Picker Sheet
struct LocationPickerSheet: View {
    @Binding var selectedCity: String
    @Binding var isActive: Bool
    @Environment(\.dismiss) private var dismiss

    private let cities = ["Colombo", "Gampaha", "Kandy", "Galle", "Matara",
                          "Negombo", "Kurunegala", "Ratnapura", "Anuradhapura", "Jaffna"]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location Filter")
                            .font(.urbanistBold(16))
                        Text("Show requests near your location")
                            .font(.urbanistRegular(13))
                            .foregroundColor(.cakeGrey)
                    }
                    Spacer()
                    Toggle("", isOn: $isActive)
                        .tint(.cakeBrown)
                }
                .padding(16)
                .background(Color(red: 0.97, green: 0.96, blue: 0.94))
                .cornerRadius(14)

                if isActive {
                    Text("Select Your City")
                        .font(.urbanistSemiBold(15))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(cities, id: \.self) { city in
                            Button {
                                selectedCity = city
                            } label: {
                                Text(city)
                                    .font(.urbanistMedium(14))
                                    .foregroundColor(selectedCity == city ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(selectedCity == city ? Color.cakeBrown : Color.white)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedCity == city ? Color.clear : Color(red: 0.88, green: 0.88, blue: 0.88), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }

                Spacer()

                Button {
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
            }
            .padding(20)
            .navigationTitle("Baker Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.cakeBrown)
                }
            }
        }
        .presentationDetents([.medium, .large])
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
            // ── Top Section ──────────────────────────────
            HStack(alignment: .top, spacing: 12) {
                // Category icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(chipColor.opacity(0.8))
                        .frame(width: 48, height: 48)
                    Image(systemName: request.category.icon)
                        .font(.system(size: 22))
                        .foregroundColor(Color(red: 0.32, green: 0.23, blue: 0.16))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(request.title)
                        .font(.urbanistBold(14))
                        .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12))
                        .lineLimit(1)

                    // Category chip + Date on same row
                    HStack(spacing: 6) {
                        Text(request.category.name)
                            .font(.urbanistMedium(10))
                            .foregroundColor(Color(red: 0.32, green: 0.23, blue: 0.16))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(chipColor)
                            .cornerRadius(6)

                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text(request.deliveryDate)
                                .font(.urbanistRegular(10))
                        }
                        .foregroundColor(.cakeGrey)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // ── Location + Bid Count Row ──────────────────
            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 11))
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
            .padding(.horizontal, 14)
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
                            .padding(.vertical, 8)
                            .background(Color(red: 0.906, green: 0.871, blue: 0.847))
                            .cornerRadius(9)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
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
