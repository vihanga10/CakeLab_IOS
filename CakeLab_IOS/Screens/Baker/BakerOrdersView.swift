import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Baker Orders View (Tab 2)
@MainActor
struct BakerOrdersView: View {
    let user: AppUser
    @State private var selectedTab: OrderTab = .active
    @State private var activeOrders: [CakeOrder] = []
    @State private var activeOrderCustomers: [String: BakerOrderCustomerProfile] = [:]
    @State private var completedOrders: [CakeOrder] = []
    @State private var totalEarnings: Double = 0
    @State private var completedCount: Int = 0
    @State private var isLoading = true
    @State private var isLoadingActive = true

    enum OrderTab: String, CaseIterable {
        case active = "Active Orders"
        case completed = "Completed"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                VStack(spacing: 0) {
                    // MARK: Custom Header (matches BakerMatchingRequestsView)
                    HStack {
                        Spacer()
                        Text("Orders")
                            .font(.urbanistBold(18))
                            .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                    .background(Color.white)

                    // MARK: Segmented Tabs
                    HStack(spacing: 0) {
                        ForEach(OrderTab.allCases, id: \.self) { tab in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = tab
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Text(tab.rawValue)
                                        .font(selectedTab == tab ? .urbanistBold(14) : .urbanistMedium(14))
                                        .foregroundColor(selectedTab == tab ? .cakeBrown : .cakeGrey)
                                    Rectangle()
                                        .fill(selectedTab == tab ? Color.cakeBrown : Color.clear)
                                        .frame(height: 2.5)
                                        .cornerRadius(2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .background(Color.white)
                    .overlay(
                        Rectangle().fill(Color(red: 0.88, green: 0.88, blue: 0.88)).frame(height: 1),
                        alignment: .bottom
                    )

                    if selectedTab == .active {
                        activeOrdersList
                    } else {
                        completedOrdersList
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await loadActiveOrdersData()
            await loadCompletedOrdersData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .orderDidChange)) { _ in
            Task {
                await loadActiveOrdersData()
                await loadCompletedOrdersData()
            }
        }
    }

    private func loadActiveOrdersData() async {
        isLoadingActive = true
        let db = Firestore.firestore()

        do {
            let statuses = ["confirmed", "baking", "decorating", "quality_check"]
            var allOrders: [CakeOrder] = []
            var customerProfiles: [String: BakerOrderCustomerProfile] = [:]

            for key in ["artisanId", "bakerID", "bakerId"] {
                let query = db.collection("orders")
                    .whereField(key, isEqualTo: user.id)
                    .whereField("status", in: statuses)

                let snapshot = try await query.getDocuments()
                for doc in snapshot.documents {
                    if let order = CakeOrder(document: doc), !allOrders.contains(where: { $0.id == order.id }) {
                        allOrders.append(order)
                        customerProfiles[order.id] = await fetchCustomerProfile(order: order, orderData: doc.data())
                    }
                }
            }

            activeOrders = allOrders.sorted { $0.deliveryDate < $1.deliveryDate }
            activeOrderCustomers = customerProfiles
            isLoadingActive = false
        } catch {
            print("Error loading active baker orders: \(error.localizedDescription)")
            isLoadingActive = false
        }
    }

    private func fetchCustomerProfile(order: CakeOrder, orderData: [String: Any]) async -> BakerOrderCustomerProfile {
        let db = Firestore.firestore()
        let fallbackName = firstString(orderData["customerName"], orderData["customerFullName"])
        let fallbackAddress = firstString(orderData["deliveryAddress"], orderData["customerAddress"])
        let fallbackCity = firstString(orderData["deliveryCity"], orderData["customerCity"])
        let fallbackImageBase64 = firstString(
            orderData["customerProfileImageBase64"],
            orderData["customerImageBase64"],
            orderData["customerImage"],
            UserDefaults.standard.string(forKey: "profileAvatar_\(order.customerId)")
        )
        let fallbackImageURL = firstString(orderData["customerImageURL"], orderData["customerAvatarURL"])

        guard !order.customerId.isEmpty else {
            return BakerOrderCustomerProfile(
                name: fallbackName.isEmpty ? "Customer" : fallbackName,
                address: fallbackAddress,
                city: fallbackCity,
                profileImageBase64: fallbackImageBase64,
                imageURL: fallbackImageURL
            )
        }

        do {
            let snapshot = try await db.collection("users").document(order.customerId).getDocument()
            let userData = snapshot.data() ?? [:]
            let rawCity = firstString(fallbackCity, userData["city"])

            return BakerOrderCustomerProfile(
                name: firstString(fallbackName, userData["name"], userData["fullName"], userData["email"], order.customerId),
                address: firstString(fallbackAddress, userData["address"]),
                city: SriLankaDistricts.canonical(rawCity) ?? rawCity,
                profileImageBase64: firstString(
                    fallbackImageBase64,
                    userData["profileImageBase64"],
                    userData["avatarBase64"],
                    userData["photoBase64"]
                ),
                imageURL: firstString(fallbackImageURL, userData["imageURL"], userData["avatarURL"], userData["photoURL"])
            )
        } catch {
            return BakerOrderCustomerProfile(
                name: fallbackName.isEmpty ? "Customer" : fallbackName,
                address: fallbackAddress,
                city: fallbackCity,
                profileImageBase64: fallbackImageBase64,
                imageURL: fallbackImageURL
            )
        }
    }

    private func firstString(_ values: Any?...) -> String {
        values.compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
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

    private func loadPaidAmountsByOrderID(db: Firestore) async -> [String: Double] {
        do {
            let snapshot = try await db.collection("payments")
                .whereField("bakerId", isEqualTo: user.id)
                .getDocuments()

            return snapshot.documents.reduce(into: [String: Double]()) { totals, document in
                let data = document.data()
                let status = firstString(data["status"], "success").lowercased()
                guard status == "success" else { return }

                let orderID = firstString(data["orderID"])
                guard !orderID.isEmpty else { return }

                totals[orderID, default: 0] += parseDouble(data["amount"])
            }
        } catch {
            print("Error loading baker payment totals: \(error.localizedDescription)")
            return [:]
        }
    }
    
    private func loadCompletedOrdersData() async {
        isLoading = true
        let db = Firestore.firestore()
        
        do {
            let statuses = ["completed", "delivered", "done"]
            var allOrders: [CakeOrder] = []
            
            // Try multiple field names for baker ID
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
            
            completedOrders = allOrders.sorted { $0.deliveryDate > $1.deliveryDate }
            completedCount = completedOrders.count

            let paidAmountsByOrderID = await loadPaidAmountsByOrderID(db: db)
            totalEarnings = completedOrders.reduce(0) { total, order in
                let paidAmount = paidAmountsByOrderID[order.id] ?? 0
                return total + (paidAmount > 0 ? paidAmount : order.amount)
            }
            isLoading = false
        } catch {
            print("Error loading completed orders: \(error.localizedDescription)")
            isLoading = false
        }
    }

    // MARK: - Active Orders
    private var activeOrdersList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if isLoadingActive {
                    ProgressView("Loading active orders...")
                        .tint(.cakeBrown)
                        .padding(.top, 24)
                } else if activeOrders.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.system(size: 34))
                            .foregroundColor(.cakeGrey.opacity(0.6))
                        Text("No active orders yet")
                            .font(.urbanistRegular(14))
                            .foregroundColor(.cakeGrey)
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(activeOrders) { order in
                        NavigationLink {
                            BakerOrderStatusView(orderID: order.id)
                        } label: {
                            BakerActiveOrderCardFromCakeOrder(
                                order: order,
                                customer: activeOrderCustomers[order.id] ?? .fallback(for: order)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Completed Orders
    private var completedOrdersList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                // Earnings summary header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Earned")
                            .font(.urbanistRegular(13))
                            .foregroundColor(.cakeGrey)
                        Text(String(format: "LKR %.0f", totalEarnings))
                            .font(.urbanistBold(22))
                            .foregroundColor(.cakeBrown)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Completed")
                            .font(.urbanistRegular(13))
                            .foregroundColor(.cakeGrey)
                        Text("\(completedCount) Order\(completedCount == 1 ? "" : "s")")
                            .font(.urbanistBold(18))
                            .foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.4))
                    }
                }
                .padding(18)
                .background(Color.white)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                .padding(.horizontal, 20)

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.cakeBrown)
                        Text("Loading completed orders...")
                            .font(.urbanistRegular(14))
                            .foregroundColor(.cakeGrey)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.vertical, 60)
                } else if completedOrders.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.cakeBrown.opacity(0.3))
                        Text("No Completed Orders Yet")
                            .font(.urbanistBold(16))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        Text("Complete orders to see them here")
                            .font(.urbanistRegular(13))
                            .foregroundColor(.cakeGrey)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(completedOrders) { order in
                        BakerCompletedOrderCardFromCakeOrder(order: order)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Baker Order Full Card
struct BakerOrderFullCard: View {
    let order: BakerOrderFull

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(order.cakeName)
                        .font(.urbanistBold(16))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    HStack(spacing: 5) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.cakeBrown)
                        Text(order.customerName)
                            .font(.urbanistRegular(13))
                            .foregroundColor(.cakeGrey)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(order.statusLabel)
                        .font(.urbanistSemiBold(11))
                        .foregroundColor(order.statusColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(order.statusColor.opacity(0.12))
                        .cornerRadius(8)
                    Text(order.amount)
                        .font(.urbanistBold(15))
                        .foregroundColor(.cakeBrown)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                        .font(.urbanistRegular(12))
                        .foregroundColor(.cakeGrey)
                    Spacer()
                    Text("\(order.progressPercent)%")
                        .font(.urbanistSemiBold(12))
                        .foregroundColor(.cakeBrown)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.cakeBrown.opacity(0.12))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.cakeBrown)
                            .frame(width: geo.size.width * CGFloat(order.progressPercent) / 100, height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider().padding(.horizontal, 16)

            // Footer
            HStack {
                Label(order.deliveryDate, systemImage: "calendar")
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeGrey)
                Spacer()
                Label(order.location, systemImage: "location")
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeGrey)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Completed Order Card
struct BakerCompletedOrderCard: View {
    let order: BakerOrderFull

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color.green)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(order.cakeName)
                    .font(.urbanistSemiBold(14))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                Text(order.customerName)
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeGrey)
                HStack(spacing: 4) {
                    ForEach(0..<5) { i in
                        Image(systemName: i < order.rating ? "star.fill" : "star")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.2))
                    }
                    Text("(\(order.rating).0)")
                        .font(.urbanistRegular(11))
                        .foregroundColor(.cakeGrey)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(order.amount)
                    .font(.urbanistBold(14))
                    .foregroundColor(.cakeBrown)
                Text(order.deliveryDate)
                    .font(.urbanistRegular(11))
                    .foregroundColor(.cakeGrey)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Baker Order Full
struct BakerOrderFull: Identifiable {
    let id = UUID()
    let cakeName: String
    let customerName: String
    let deliveryDate: String
    let location: String
    let status: String
    let amount: String
    let progressPercent: Int
    let currentStep: Int
    let notes: String
    var rating: Int = 5
    
    var statusColor: Color {
        switch status {
        case "baking":       return Color.orange
        case "decorating":   return Color(red: 0.3, green: 0.45, blue: 0.8)
        case "ready":        return Color.green
        case "confirmed":    return Color.cakeBrown
        default:             return Color.cakeGrey
        }
    }
    var statusLabel: String {
        switch status {
        case "baking":       return "Baking"
        case "decorating":   return "Decorating"
        case "ready":        return "Ready to Collect"
        case "confirmed":    return "Confirmed"
        default:             return status.capitalized
        }
    }
}

// MARK: - Baker Order Detail View
@MainActor
struct BakerOrderDetailView: View {
    let order: BakerOrderFull
    @State private var selectedStep: Int
    @Environment(\.dismiss) private var dismiss
    
    init(order: BakerOrderFull) {
        self.order = order
        self._selectedStep = State(initialValue: order.currentStep)
    }
    
    private let steps = ["Confirmed", "Baking", "Decorating", "Quality Check", "Ready"]
    
    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.96, blue: 0.94).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Order header card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(order.cakeName)
                                    .font(.urbanistBold(20))
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                Text("Order #\(order.id.uuidString.prefix(8).uppercased())")
                                    .font(.urbanistRegular(12))
                                    .foregroundColor(.cakeGrey)
                            }
                            Spacer()
                            Text(order.amount)
                                .font(.urbanistBold(20))
                                .foregroundColor(.cakeBrown)
                        }
                        Divider()
                        HStack {
                            Label(order.customerName, systemImage: "person.fill")
                            Spacer()
                            Label(order.deliveryDate, systemImage: "calendar")
                        }
                        .font(.urbanistRegular(13))
                        .foregroundColor(.cakeGrey)
                    }
                    .padding(18)
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                    .padding(.horizontal, 20)
                    
                    // Progress Steps
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Update Order Status")
                            .font(.urbanistBold(16))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        
                        ForEach(0..<steps.count, id: \.self) { idx in
                            HStack(spacing: 14) {
                                // Step indicator
                                ZStack {
                                    Circle()
                                        .fill(idx <= selectedStep ? Color.cakeBrown : Color(red: 0.88, green: 0.88, blue: 0.88))
                                        .frame(width: 32, height: 32)
                                    if idx < selectedStep {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                    } else {
                                        Text("\(idx + 1)")
                                            .font(.urbanistBold(13))
                                            .foregroundColor(idx == selectedStep ? .white : Color(red: 0.5, green: 0.5, blue: 0.5))
                                    }
                                }
                                Text(steps[idx])
                                    .font(idx == selectedStep ? .urbanistBold(14) : .urbanistRegular(14))
                                    .foregroundColor(idx <= selectedStep ? Color(red: 0.1, green: 0.1, blue: 0.1) : .cakeGrey)
                                Spacer()
                                if idx == selectedStep {
                                    Text("Current")
                                        .font(.urbanistSemiBold(11))
                                        .foregroundColor(.cakeBrown)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.cakeBrown.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                            .onTapGesture {
                                withAnimation { selectedStep = idx }
                            }
                            
                            if idx < steps.count - 1 {
                                Rectangle()
                                    .fill(idx < selectedStep ? Color.cakeBrown : Color(red: 0.88, green: 0.88, blue: 0.88))
                                    .frame(width: 2, height: 20)
                                    .padding(.leading, 15)
                            }
                        }
                        
                        Button {
                            // TODO: Update Firestore
                        } label: {
                            Text("Update Status")
                                .font(.urbanistBold(15))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.cakeBrown)
                                .cornerRadius(16)
                        }
                        .padding(.top, 8)
                    }
                    .padding(18)
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                    .padding(.horizontal, 20)
                    
                    // Customer Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Customer Details")
                            .font(.urbanistBold(16))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        detailRow(icon: "person.fill", label: "Name", value: order.customerName)
                        detailRow(icon: "location.fill", label: "Delivery Address", value: order.location)
                        detailRow(icon: "phone.fill", label: "Phone", value: "+94 77 123 4567")
                        detailRow(icon: "bubble.left.fill", label: "Special Notes", value: order.notes)
                    }
                    .padding(18)
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle("Order Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.cakeBrown)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.urbanistRegular(11))
                    .foregroundColor(.cakeGrey)
                Text(value)
                    .font(.urbanistMedium(13))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            }
        }
    }
}

// MARK: - Completed Order Card from CakeOrder
struct BakerCompletedOrderCardFromCakeOrder: View {
    let order: CakeOrder
    
    var body: some View {
        HStack(spacing: 14) {
            // Order image or icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.95, green: 0.93, blue: 0.90))
                    .frame(width: 48, height: 48)
                
                if let firstReferenceImage = order.referenceImages.first,
                   let imageData = Data(base64Encoded: firstReferenceImage),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if let imageURL = order.imageURL, !imageURL.isEmpty, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        default:
                            Image(systemName: "birthday.cake")
                                .font(.system(size: 18))
                                .foregroundColor(.cakeBrown.opacity(0.7))
                        }
                    }
                } else {
                    Image(systemName: "birthday.cake")
                        .font(.system(size: 18))
                        .foregroundColor(.cakeBrown.opacity(0.7))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(order.cakeName)
                    .font(.urbanistSemiBold(14))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                Text(order.artisanName)
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeGrey)
                    .lineLimit(1)
                Text("Delivered on \(order.formattedDeliveryDate)")
                    .font(.urbanistRegular(11))
                    .foregroundColor(.cakeGrey)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("LKR 3,500")
                    .font(.urbanistBold(14))
                    .foregroundColor(.cakeBrown)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.4))
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
    }
}

struct BakerOrderCustomerProfile {
    let name: String
    let address: String
    let city: String
    let profileImageBase64: String
    let imageURL: String

    static func fallback(for order: CakeOrder) -> BakerOrderCustomerProfile {
        BakerOrderCustomerProfile(
            name: order.customerId.isEmpty ? "Customer" : order.customerId,
            address: "",
            city: "",
            profileImageBase64: "",
            imageURL: ""
        )
    }

    var displayLocation: String {
        let location = SriLankaDistricts.displayLocation(address: address, city: city)
        return location.isEmpty ? "Delivery address not provided" : location
    }
}

struct BakerActiveOrderCardFromCakeOrder: View {
    let order: CakeOrder
    let customer: BakerOrderCustomerProfile

    private let stepLabels = ["Confirmed", "Baking", "Decorating", "Quality\nChecking", "Delivered"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Order Row ──────────────────────────────────────────────
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                        .frame(width: 80, height: 80)

                    if !order.referenceImages.isEmpty,
                       let imageData = Data(base64Encoded: order.referenceImages[0]),
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "birthday.cake.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.cakeBrown.opacity(0.4))
                    }
                }
                .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: 0) {
                    Text(order.cakeName)
                        .font(.urbanistBold(15))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .lineLimit(2)

                    HStack(alignment: .top, spacing: 10) {
                        Text(order.statusLabel)
                            .font(.urbanistSemiBold(11))
                            .foregroundColor(order.statusColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(order.statusColor.opacity(0.12))
                            .cornerRadius(8)

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Delivery Date:")
                                .font(.urbanistRegular(11))
                                .foregroundColor(.cakeGrey)
                            Text(order.formattedDeliveryDate)
                                .font(.urbanistSemiBold(12))
                                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                        }
                    }
                    .padding(.top, 14)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // ── Progress Tracker ───────────────────────────────────────
            OrderProgressTracker(currentStep: order.currentStep, labels: stepLabels)
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 18)

            // ── Customer Delivery Info ─────────────────────────────────
            HStack(spacing: 12) {
                customerProfileImage

                VStack(alignment: .leading, spacing: 3) {
                    Text(customer.name)
                        .font(.urbanistBold(14))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.cakeGrey)
                            .padding(.top, 2)
                        Text(customer.displayLocation)
                            .font(.urbanistRegular(11))
                            .foregroundColor(.cakeGrey)
                            .lineLimit(2)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 3)
    }

    private var customerProfileImage: some View {
        Group {
            if let image = decodeBase64Image(customer.profileImageBase64) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = URL(string: customer.imageURL), !customer.imageURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        customerProfilePlaceholder
                    }
                }
            } else {
                customerProfilePlaceholder
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
    }

    private var customerProfilePlaceholder: some View {
        Circle()
            .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.cakeBrown.opacity(0.5))
            )
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

// MARK: - Mock Data
let mockActiveOrdersFull: [BakerOrderFull] = [
    BakerOrderFull(cakeName: "3-Tier Wedding Cake", customerName: "Kavya Naidoo", deliveryDate: "Apr 08, 2026", location: "Colombo 07", status: "baking", amount: "LKR 18,500", progressPercent: 40, currentStep: 1, notes: "Please ensure white fondant with gold leaf accents"),
    BakerOrderFull(cakeName: "Unicorn Birthday Cake", customerName: "Dinesh Kumar", deliveryDate: "Apr 10, 2026", location: "Nugegoda", status: "decorating", amount: "LKR 6,200", progressPercent: 65, currentStep: 2, notes: "Pink and purple colors. Serves 20."),
    BakerOrderFull(cakeName: "Red Velvet Tiramisu", customerName: "Amali Perera", deliveryDate: "Apr 12, 2026", location: "Dehiwala", status: "confirmed", amount: "LKR 4,800", progressPercent: 10, currentStep: 0, notes: ""),
]

let mockCompletedOrders: [BakerOrderFull] = [
    BakerOrderFull(cakeName: "Chocolate Ganache Cake", customerName: "Rohan Gupta", deliveryDate: "Mar 28, 2026", location: "Kollupitiya", status: "completed", amount: "LKR 8,500", progressPercent: 100, currentStep: 4, notes: "", rating: 5),
    BakerOrderFull(cakeName: "Mango Cream Cake", customerName: "Priya Raj", deliveryDate: "Mar 20, 2026", location: "Rajagiriya", status: "completed", amount: "LKR 5,200", progressPercent: 100, currentStep: 4, notes: "", rating: 4),
    BakerOrderFull(cakeName: "Fondant Anniversary Cake", customerName: "Saman Fernando", deliveryDate: "Mar 15, 2026", location: "Colombo 03", status: "completed", amount: "LKR 14,000", progressPercent: 100, currentStep: 4, notes: "", rating: 5),
]
