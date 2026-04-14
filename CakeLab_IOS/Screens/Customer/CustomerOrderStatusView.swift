import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
final class CustomerOrderStatusViewModel: ObservableObject {
    @Published var order: CakeOrder?
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var progressTimestamps: [String: Date] = [:]
    @Published var createdAt: Date?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening(orderID: String) {
        listener?.remove()
        isLoading = true
        errorMessage = nil

        listener = db.collection("orders").document(orderID).addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
                self.errorMessage = "Unable to load order status. \(error.localizedDescription)"
                self.isLoading = false
                return
            }

            guard let snapshot, snapshot.exists, let order = CakeOrder(document: snapshot) else {
                self.errorMessage = "Order not found."
                self.isLoading = false
                return
            }

            let data = snapshot.data() ?? [:]
            self.order = order
            self.createdAt = Self.parseDate(data["createdAt"])
            self.progressTimestamps = Self.parseProgressTimestamps(data["progressTimestamps"])
            self.isLoading = false
        }
    }

    func timestamp(for statusKey: String) -> Date? {
        progressTimestamps[statusKey]
    }

    private static func parseDate(_ raw: Any?) -> Date? {
        if let ts = raw as? Timestamp { return ts.dateValue() }
        if let seconds = raw as? TimeInterval { return Date(timeIntervalSince1970: seconds) }
        if let seconds = raw as? Int { return Date(timeIntervalSince1970: TimeInterval(seconds)) }
        return nil
    }

    private static func parseProgressTimestamps(_ raw: Any?) -> [String: Date] {
        guard let map = raw as? [String: Any] else { return [:] }
        var result: [String: Date] = [:]
        for (key, value) in map {
            if let date = parseDate(value) {
                result[key] = date
            }
        }
        return result
    }
}

struct CustomerOrderStatusView: View {
    let orderID: String
    let fallbackOrder: CustomerOrder

    @StateObject private var viewModel = CustomerOrderStatusViewModel()

    private let steps: [(step: Int, statusKey: String, title: String)] = [
        (1, "confirmed", "Confirmed"),
        (2, "baking", "Baking"),
        (3, "decorating", "Decorating"),
        (4, "quality_check", "Quality Checking"),
        (5, "delivered", "Delivered")
    ]

    private let surface = Color.white
    private let accent = Color.cakeBrown

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "hh:mm a"
        return f
    }()

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.97, blue: 0.97).ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView("Loading status...")
                    .tint(.cakeBrown)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.urbanistRegular(14))
                        .foregroundColor(.cakeGrey)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            } else {
                let liveOrder = viewModel.order
                let statusText = liveOrder?.statusLabel ?? fallbackOrder.status
                let statusColor = liveOrder?.statusColor ?? fallbackOrder.statusColor
                let currentStep = max(1, min(5, liveOrder?.currentStep ?? fallbackOrder.currentStep))
                let deliveryDateText = liveOrder?.formattedDeliveryDate ?? fallbackOrder.deliveryDate

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        headerCard(
                            cakeName: liveOrder?.cakeName ?? fallbackOrder.cakeName,
                            statusText: statusText,
                            statusColor: statusColor,
                            deliveryDateText: deliveryDateText
                        )

                        statusTimelineCard(currentStep: currentStep, deliveryDateText: deliveryDateText)

                        bakerInfoCard(
                            name: liveOrder?.artisanName ?? fallbackOrder.bakerName,
                            rating: liveOrder?.artisanRating ?? fallbackOrder.bakerRating,
                            address: liveOrder?.artisanAddress ?? fallbackOrder.bakerAddress
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("Order Status")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.startListening(orderID: orderID)
        }
    }

    private func headerCard(cakeName: String, statusText: String, statusColor: Color, deliveryDateText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                        .frame(width: 84, height: 84)
                    Image(systemName: "birthday.cake.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.cakeBrown.opacity(0.6))
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Order ID: \(orderID.uppercased())")
                        .font(.urbanistSemiBold(14))
                        .foregroundColor(Color(red: 0.18, green: 0.18, blue: 0.18))
                    Text(cakeName)
                        .font(.urbanistBold(18))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        HStack(spacing: 5) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 11))
                            Text("You")
                        }
                        .font(.urbanistRegular(12))
                        .foregroundColor(.cakeGrey)

                        HStack(spacing: 5) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                            Text(deliveryDateText)
                        }
                        .font(.urbanistRegular(12))
                        .foregroundColor(.cakeGrey)
                    }
                }

                Spacer()

                Text(statusText)
                    .font(.urbanistSemiBold(12))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.12))
                    .cornerRadius(10)
            }
        }
        .padding(16)
        .background(surface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func statusTimelineCard(currentStep: Int, deliveryDateText: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(steps, id: \.step) { item in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(circleColor(for: item.step, currentStep: currentStep))
                                .frame(width: 36, height: 36)
                            Circle()
                                .fill(Color.white.opacity(item.step == currentStep ? 0.9 : 0.0))
                                .frame(width: 16, height: 16)
                            if item.step < currentStep {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }

                        if item.step < steps.count {
                            Rectangle()
                                .fill(Color(red: 0.78, green: 0.78, blue: 0.78))
                                .frame(width: 1.2, height: 48)
                                .padding(.top, 4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(item.title)
                                .font(item.step == currentStep ? .urbanistBold(15) : .urbanistMedium(15))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                            Spacer()

                            if item.step == currentStep {
                                Text("Current")
                                    .font(.urbanistSemiBold(11))
                                    .foregroundColor(accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(red: 0.92, green: 0.88, blue: 0.83))
                                    .cornerRadius(9)
                            }
                        }

                        HStack(spacing: 10) {
                            Text("Date : \(stepDateText(step: item.step, statusKey: item.statusKey))")
                                .font(.urbanistRegular(13))
                                .foregroundColor(.cakeGrey)

                            Rectangle()
                                .fill(Color(red: 0.80, green: 0.80, blue: 0.80))
                                .frame(width: 1, height: 14)

                            Text("Time : \(stepTimeText(step: item.step, statusKey: item.statusKey))")
                                .font(.urbanistRegular(13))
                                .foregroundColor(.cakeGrey)
                        }

                        if item.step < steps.count {
                            Divider()
                                .padding(.top, 10)
                                .padding(.bottom, 8)
                        }
                    }
                }
            }

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Expected Date")
                        .font(.urbanistSemiBold(12))
                        .foregroundColor(accent)
                    Text(deliveryDateText)
                        .font(.urbanistMedium(13))
                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Expected Time")
                        .font(.urbanistSemiBold(12))
                        .foregroundColor(accent)
                    Text("10:00 AM")
                        .font(.urbanistMedium(13))
                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                }

                Spacer()
            }
            .padding(.top, 10)

            Button {
                // Calendar integration can be wired later.
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Add Delivery to Calendar")
                        .font(.urbanistSemiBold(14))
                }
                .foregroundColor(accent)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(Color(red: 0.92, green: 0.90, blue: 0.87))
                .cornerRadius(19)
            }
            .padding(.top, 14)
        }
        .padding(16)
        .background(surface)
        .cornerRadius(22)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
    }

    private func bakerInfoCard(name: String, rating: String, address: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Baker Details")
                .font(.urbanistBold(16))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                        .frame(width: 48, height: 48)
                    Image(systemName: "person.fill")
                        .font(.system(size: 21))
                        .foregroundColor(.cakeBrown.opacity(0.55))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.urbanistBold(14))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.1))
                        Text(rating)
                            .font(.urbanistRegular(12))
                            .foregroundColor(.cakeGrey)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.cakeGrey)
                        Text(address)
                            .font(.urbanistRegular(12))
                            .foregroundColor(.cakeGrey)
                            .lineLimit(1)
                    }
                }
            }

            Button {
                // Review flow can be wired to Firestore reviews collection.
            } label: {
                Text("Write a Review")
                    .font(.urbanistBold(15))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(accent)
                    .cornerRadius(24)
            }
            .padding(.top, 14)
        }
        .padding(16)
        .background(surface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func stepDateText(step: Int, statusKey: String) -> String {
        if step == 1, let created = viewModel.timestamp(for: statusKey) ?? viewModel.createdAt {
            return Self.dateFmt.string(from: created)
        }
        guard let date = viewModel.timestamp(for: statusKey) else { return "Pending" }
        return Self.dateFmt.string(from: date)
    }

    private func stepTimeText(step: Int, statusKey: String) -> String {
        if step == 1, let created = viewModel.timestamp(for: statusKey) ?? viewModel.createdAt {
            return Self.timeFmt.string(from: created)
        }
        guard let date = viewModel.timestamp(for: statusKey) else { return "Pending" }
        return Self.timeFmt.string(from: date)
    }

    private func circleColor(for step: Int, currentStep: Int) -> Color {
        if step < currentStep {
            return Color(red: 0.14, green: 0.58, blue: 0.34)
        }
        if step == currentStep {
            return accent
        }
        return Color(red: 0.78, green: 0.78, blue: 0.78)
    }
}

#Preview {
    NavigationStack {
        CustomerOrderStatusView(
            orderID: "B001",
            fallbackOrder: CustomerOrder(
                id: "B001",
                cakeName: "Rainbow Unicorn Birthday Cake",
                status: "Decorating",
                statusColor: Color(red: 1.0, green: 0.55, blue: 0.10),
                deliveryDate: "09/04/2026",
                currentStep: 3,
                bakerName: "Cake Haven by Dinithi",
                bakerRating: "5.0 (41 reviews)",
                bakerAddress: "Colombo 02"
            )
        )
    }
}
