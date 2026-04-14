import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
final class CustomerOrderStatusViewModel: ObservableObject {
    @Published var order: CakeOrder?
    @Published var isLoading = true
    @Published var errorMessage: String?

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

            self.order = order
            self.isLoading = false
        }
    }
}

struct CustomerOrderStatusView: View {
    let orderID: String
    let fallbackOrder: CustomerOrder

    @StateObject private var viewModel = CustomerOrderStatusViewModel()

    private let stepLabels = ["Confirmed", "Baking", "Decorating", "Quality Checking", "Delivered"]

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

                        statusTimelineCard(currentStep: currentStep)

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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                        .frame(width: 80, height: 80)
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

                    Text(statusText)
                        .font(.urbanistSemiBold(12))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(statusColor.opacity(0.12))
                        .cornerRadius(10)
                }

                Spacer()
            }

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(.cakeBrown)
                Text("Expected Delivery: \(deliveryDateText)")
                    .font(.urbanistMedium(13))
                    .foregroundColor(.cakeGrey)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func statusTimelineCard(currentStep: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Progress Timeline")
                .font(.urbanistBold(16))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

            VStack(spacing: 0) {
                ForEach(Array(stepLabels.enumerated()), id: \.offset) { idx, title in
                    let step = idx + 1
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(step < currentStep
                                      ? Color(red: 0.14, green: 0.58, blue: 0.34)
                                      : (step == currentStep
                                         ? Color(red: 0.49, green: 0.29, blue: 0.11)
                                         : Color(red: 0.82, green: 0.82, blue: 0.82)))
                                .frame(width: 30, height: 30)
                            if step < currentStep {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Text("\(step)")
                                    .font(.urbanistBold(12))
                                    .foregroundColor(.white)
                            }
                        }

                        Text(title)
                            .font(step == currentStep ? .urbanistBold(15) : .urbanistRegular(15))
                            .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))

                        Spacer()

                        if step == currentStep {
                            Text("Current")
                                .font(.urbanistSemiBold(11))
                                .foregroundColor(Color(red: 0.49, green: 0.29, blue: 0.11))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(red: 0.92, green: 0.88, blue: 0.83))
                                .cornerRadius(8)
                        }
                    }

                    if idx < stepLabels.count - 1 {
                        Rectangle()
                            .fill(step < currentStep
                                  ? Color(red: 0.14, green: 0.58, blue: 0.34)
                                  : Color(red: 0.85, green: 0.85, blue: 0.85))
                            .frame(width: 2, height: 22)
                            .padding(.leading, 14)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
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
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
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
