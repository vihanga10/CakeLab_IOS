import SwiftUI

// MARK: - Baker Orders View 
@MainActor
struct BakerOrdersView: View {
    let user: AppUser
    @StateObject private var vm: BakerOrdersViewModel
    @State private var selectedTab: OrderTab = .active

    enum OrderTab: String, CaseIterable {
        case active = "Active Orders"
        case completed = "Completed Orders"
    }

    init(user: AppUser) {
        self.user = user
        _vm = StateObject(wrappedValue: BakerOrdersViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cakeBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Text("Order Details")
                            .font(.urbanistBold(18))
                            .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                    .background(Color.cakeBackground)

                    // MARK: Segmented Tabs
                    HStack(spacing: 0) {
                        ForEach(OrderTab.allCases, id: \.self) { tab in
                            tabButton(tab)
                        }
                    }
                    .padding(4)
                    .background(Color(red: 0.92, green: 0.92, blue: 0.92))
                    .clipShape(Capsule())
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                    if selectedTab == .active {
                        if vm.isLoadingActive {
                            ProgressView("Loading active orders...")
                                .tint(.cakeBrown)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if vm.activeOrders.isEmpty {
                            emptyState(message: "No active orders")
                        } else {
                            activeOrdersList
                        }
                    } else {
                        if vm.isLoading {
                            ProgressView("Loading completed orders...")
                                .tint(.cakeBrown)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if vm.completedOrders.isEmpty {
                            emptyState(message: "No completed orders")
                        } else {
                            completedOrdersList
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await vm.loadActiveOrdersData()
            await vm.loadCompletedOrdersData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .orderDidChange)) { _ in
            Task {
                await vm.loadActiveOrdersData()
                await vm.loadCompletedOrdersData()
            }
        }
    }

    private func tabButton(_ tab: OrderTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            Text(tab.rawValue)
                .font(selectedTab == tab ? .urbanistSemiBold(13) : .urbanistRegular(13))
                .foregroundColor(selectedTab == tab ? .white : Color(red: 0.4, green: 0.4, blue: 0.4))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(selectedTab == tab ? Color.cakeBrown : Color.clear)
                .clipShape(Capsule())
        }
    }

    private func emptyState(message: String) -> some View {
        VStack {
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundColor(.cakeGrey)
                .padding(.bottom, 8)

            Text(message)
                .font(.urbanistRegular(15))
                .foregroundColor(.cakeGrey)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Active Orders
    private var activeOrdersList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                ForEach(vm.activeOrders) { order in
                    NavigationLink {
                        BakerOrderStatusView(orderID: order.id)
                    } label: {
                        BakerActiveOrderCardFromCakeOrder(
                            order: order,
                            customer: vm.activeOrderCustomers[order.id] ?? .fallback(for: order)
                        )
                    }
                    .buttonStyle(.plain)
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
                        Text(String(format: "LKR %.0f", vm.totalEarnings))
                            .font(.urbanistBold(22))
                            .foregroundColor(.cakeBrown)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Completed")
                            .font(.urbanistRegular(13))
                            .foregroundColor(.cakeGrey)
                        Text("\(vm.completedCount) Order\(vm.completedCount == 1 ? "" : "s")")
                            .font(.urbanistBold(18))
                            .foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.4))
                    }
                }
                .padding(18)
                .background(Color.cakeSurface)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                .padding(.horizontal, 20)

                ForEach(vm.completedOrders) { order in
                    NavigationLink {
                        BakerOrderStatusView(orderID: order.id)
                    } label: {
                        BakerCompletedOrderCardFromCakeOrder(
                            order: order,
                            customer: vm.completedOrderCustomers[order.id] ?? .fallback(for: order),
                            amount: vm.completedOrderAmounts[order.id] ?? order.amount
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 100)
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
                                    .foregroundColor(.cakePrimaryText)
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
                    .background(Color.cakeSurface)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                    .padding(.horizontal, 20)
                    
                    // Progress Steps
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Update Order Status")
                            .font(.urbanistBold(16))
                            .foregroundColor(.cakePrimaryText)
                        
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
                    .background(Color.cakeSurface)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                    .padding(.horizontal, 20)
                    
                    // Customer Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Customer Details")
                            .font(.urbanistBold(16))
                            .foregroundColor(.cakePrimaryText)
                        detailRow(icon: "person.fill", label: "Name", value: order.customerName)
                        detailRow(icon: "location.fill", label: "Delivery Address", value: order.location)
                        detailRow(icon: "phone.fill", label: "Phone", value: "+94 77 123 4567")
                        detailRow(icon: "bubble.left.fill", label: "Special Notes", value: order.notes)
                    }
                    .padding(18)
                    .background(Color.cakeSurface)
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
                    .foregroundColor(.cakePrimaryText)
            }
        }
    }
}
