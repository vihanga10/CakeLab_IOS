import SwiftUI
import Combine
import FirebaseFirestore

// MARK: - Mock Order
struct CustomerOrder: Identifiable {
    let id: String
    let cakeName: String
    let status: String
    let statusColor: Color
    let deliveryDate: String
    let currentStep: Int   // 1–5
    let bakerName: String
    let bakerRating: String
    let bakerAddress: String
    let imageName: String

    init(id: String, cakeName: String, status: String, statusColor: Color, deliveryDate: String, currentStep: Int, bakerName: String, bakerRating: String, bakerAddress: String, imageName: String = "") {
        self.id = id
        self.cakeName = cakeName
        self.status = status
        self.statusColor = statusColor
        self.deliveryDate = deliveryDate
        self.currentStep = currentStep
        self.bakerName = bakerName
        self.bakerRating = bakerRating
        self.bakerAddress = bakerAddress
        self.imageName = imageName
    }

    init(from order: CakeOrder) {
        self.id = order.id
        self.cakeName = order.cakeName
        self.status = order.statusLabel
        self.statusColor = order.statusColor
        self.deliveryDate = order.formattedDeliveryDate
        self.currentStep = max(1, min(5, order.currentStep))
        self.bakerName = order.artisanName
        self.bakerRating = order.artisanRating
        self.bakerAddress = order.artisanAddress
        self.imageName = ""
    }
}

@MainActor
final class CustomerOrdersViewModel: ObservableObject {
    @Published var activeOrders: [CustomerOrder] = []
    @Published var completedOrders: [CustomerOrder] = []
    @Published var isLoading = false

    private let db = Firestore.firestore()

    func loadOrders(customerID: String) async {
        isLoading = true

        do {
            let activeStatuses = ["confirmed", "baking", "decorating", "quality_check"]
            let completedStatuses = ["delivered", "completed", "done"]

            async let activeSnapshot = db.collection("orders")
                .whereField("customerId", isEqualTo: customerID)
                .whereField("status", in: activeStatuses)
                .getDocuments()

            async let completedSnapshot = db.collection("orders")
                .whereField("customerId", isEqualTo: customerID)
                .whereField("status", in: completedStatuses)
                .getDocuments()

            let (activeDocs, completedDocs) = try await (activeSnapshot, completedSnapshot)

            activeOrders = activeDocs.documents
                .compactMap(CakeOrder.init(document:))
                .sorted { $0.deliveryDate < $1.deliveryDate }
                .map(CustomerOrder.init(from:))

            completedOrders = completedDocs.documents
                .compactMap(CakeOrder.init(document:))
                .sorted { $0.deliveryDate > $1.deliveryDate }
                .map(CustomerOrder.init(from:))
        } catch {
            print("Error loading customer orders: \(error.localizedDescription)")
        }

        isLoading = false
    }
}

// MARK: - Customer Orders View
struct CustomerOrdersView: View {
    let user: AppUser

    @State private var selectedTab = 0   // 0 = Active, 1 = Completed
    @StateObject private var viewModel = CustomerOrdersViewModel()

    private let stepLabels = ["Confirmed", "Baking", "Decorating", "Quality\nChecking", "Delivered"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.97, green: 0.97, blue: 0.97).ignoresSafeArea()

                VStack(spacing: 0) {

                    // ── Tab Selector ──────────────────────────────────────
                    HStack(spacing: 0) {
                        tabButton(title: "Active Orders", tag: 0)
                        tabButton(title: "Completed Orders", tag: 1)
                    }
                    .padding(4)
                    .background(Color(red: 0.92, green: 0.92, blue: 0.92))
                    .clipShape(Capsule())
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                    // ── Content ────────────────────────────────────────────
                    if selectedTab == 0 {
                        if viewModel.isLoading {
                            ProgressView("Loading orders...")
                                .tint(.cakeBrown)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if viewModel.activeOrders.isEmpty {
                            emptyState(message: "No active orders")
                        } else {
                            ScrollView(showsIndicators: false) {
                                VStack(spacing: 0) {
                                    ForEach(Array(viewModel.activeOrders.enumerated()), id: \.element.id) { idx, order in
                                        NavigationLink {
                                            CustomerOrderStatusView(orderID: order.id, fallbackOrder: order)
                                        } label: {
                                            OrderCard(order: order, stepLabels: stepLabels)
                                        }
                                        .buttonStyle(.plain)
                                        if idx < viewModel.activeOrders.count - 1 {
                                            Divider()
                                                .padding(.horizontal, 16)
                                        }
                                    }
                                }
                                .background(Color.white)
                                .cornerRadius(14)
                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 20)
                            }
                        }
                    } else {
                        if viewModel.completedOrders.isEmpty {
                            emptyState(message: "No completed orders yet")
                        } else {
                            ScrollView(showsIndicators: false) {
                                VStack(spacing: 0) {
                                    ForEach(Array(viewModel.completedOrders.enumerated()), id: \.element.id) { idx, order in
                                        OrderCard(order: order, stepLabels: stepLabels)
                                        if idx < viewModel.completedOrders.count - 1 {
                                            Divider()
                                                .padding(.horizontal, 16)
                                        }
                                    }
                                }
                                .background(Color.white)
                                .cornerRadius(14)
                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 20)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Order Details")
                        .font(.urbanistBold(18))
                        .foregroundColor(Color(red: 93/255, green: 55/255, blue: 20/255))
                }
            }
        }
        .task {
            await viewModel.loadOrders(customerID: user.id)
        }
        .onReceive(NotificationCenter.default.publisher(for: .orderDidChange)) { _ in
            Task {
                await viewModel.loadOrders(customerID: user.id)
            }
        }
    }

    // MARK: - Tab Button
    private func tabButton(title: String, tag: Int) -> some View {
        Button { withAnimation { selectedTab = tag } } label: {
            Text(title)
                .font(selectedTab == tag ? .urbanistSemiBold(13) : .urbanistRegular(13))
                .foregroundColor(selectedTab == tag ? .white : Color(red: 0.4, green: 0.4, blue: 0.4))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(selectedTab == tag ? Color.cakeBrown : Color.clear)
                .clipShape(Capsule())
        }
    }

    private func emptyState(message: String) -> some View {
        VStack {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.cakeGrey)
                .padding(.bottom, 8)
            Text(message)
                .font(.urbanistRegular(14))
                .foregroundColor(.cakeGrey)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Order Card
struct OrderCard: View {
    let order: CustomerOrder
    let stepLabels: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Order Row ──────────────────────────────────────────────
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                        .frame(width: 80, height: 80)
                    if UIImage(named: order.imageName) != nil {
                        Image(order.imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: "birthday.cake.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.cakeBrown.opacity(0.4))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(order.cakeName)
                        .font(.urbanistBold(13))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        statusBadge
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Delivery Date:")
                                .font(.urbanistRegular(10))
                                .foregroundColor(.cakeGrey)
                            Text(order.deliveryDate)
                                .font(.urbanistSemiBold(11))
                                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            // ── Progress Tracker ───────────────────────────────────────
            OrderProgressTracker(currentStep: order.currentStep, labels: stepLabels)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 16)

            // ── Baker Info ─────────────────────────────────────────────
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                        .frame(width: 46, height: 46)
                    Image(systemName: "person.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.cakeBrown.opacity(0.5))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(order.bakerName)
                        .font(.urbanistBold(13))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.1))
                        Text(order.bakerRating)
                            .font(.urbanistRegular(11))
                            .foregroundColor(.cakeGrey)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.cakeGrey)
                        Text(order.bakerAddress)
                            .font(.urbanistRegular(11))
                            .foregroundColor(.cakeGrey)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var statusBadge: some View {
        Text(order.status)
            .font(.urbanistSemiBold(11))
            .foregroundColor(order.statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(order.statusColor.opacity(0.12))
            .cornerRadius(8)
    }
}

// MARK: - Order Progress Tracker
struct OrderProgressTracker: View {
    let currentStep: Int    // 1-based
    let labels: [String]
    private let totalSteps = 5

    var body: some View {
        VStack(spacing: 8) {
            // Circles + connecting lines
            HStack(spacing: 0) {
                ForEach(1...totalSteps, id: \.self) { step in
                    stepCircle(step: step)
                    if step < totalSteps {
                        connectorLine(step: step)
                    }
                }
            }

            // Labels
            HStack(spacing: 0) {
                ForEach(0..<totalSteps, id: \.self) { idx in
                    Text(labels[idx])
                        .font(.urbanistRegular(9))
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func stepCircle(step: Int) -> some View {
        ZStack {
            if step < currentStep {
                // Completed
                Circle()
                    .fill(Color(red: 0.15, green: 0.60, blue: 0.22))
                    .frame(width: 30, height: 30)
                Text("\(step)")
                    .font(.urbanistBold(12))
                    .foregroundColor(.white)
            } else if step == currentStep {
                // Current
                Circle()
                    .fill(Color(red: 0.92, green: 0.86, blue: 0.76))
                    .frame(width: 30, height: 30)
                Circle()
                    .stroke(Color(red: 0.80, green: 0.72, blue: 0.60), lineWidth: 1.5)
                    .frame(width: 30, height: 30)
                Text("\(step)")
                    .font(.urbanistBold(12))
                    .foregroundColor(Color(red: 0.5, green: 0.35, blue: 0.15))
            } else {
                // Future
                Circle()
                    .fill(Color(red: 0.82, green: 0.82, blue: 0.82))
                    .frame(width: 30, height: 30)
                Text("\(step)")
                    .font(.urbanistBold(12))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 30)
    }

    private func connectorLine(step: Int) -> some View {
        Rectangle()
            .fill(step < currentStep
                  ? Color(red: 0.15, green: 0.60, blue: 0.22)
                  : Color(red: 0.80, green: 0.80, blue: 0.80))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .offset(y: -8) // align with circle centers
    }
}

#Preview {
    CustomerOrdersView(user: AppUser.mock)
}
