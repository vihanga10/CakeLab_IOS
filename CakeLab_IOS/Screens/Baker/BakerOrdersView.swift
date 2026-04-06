import SwiftUI

// MARK: - Baker Orders View (Tab 2)
@MainActor
struct BakerOrdersView: View {
    @State private var selectedTab: OrderTab = .active

    enum OrderTab: String, CaseIterable {
        case active = "Active Orders"
        case completed = "Completed"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.97, green: 0.96, blue: 0.94).ignoresSafeArea()
                VStack(spacing: 0) {
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
            .navigationTitle("Orders")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Active Orders
    private var activeOrdersList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                ForEach(mockActiveOrdersFull) { order in
                    NavigationLink(destination: BakerOrderDetailView(order: order)) {
                        BakerOrderFullCard(order: order)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                }
            }
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
                        Text("LKR 124,500")
                            .font(.urbanistBold(22))
                            .foregroundColor(.cakeBrown)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Completed")
                            .font(.urbanistRegular(13))
                            .foregroundColor(.cakeGrey)
                        Text("12 Orders")
                            .font(.urbanistBold(18))
                            .foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.4))
                    }
                }
                .padding(18)
                .background(Color.white)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                .padding(.horizontal, 20)

                ForEach(mockCompletedOrders) { order in
                    BakerCompletedOrderCard(order: order)
                        .padding(.horizontal, 20)
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

// MARK: - Full Order Model
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

// Mock Data
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
