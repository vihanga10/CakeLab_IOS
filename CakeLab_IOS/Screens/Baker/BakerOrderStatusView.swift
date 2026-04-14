import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
final class BakerOrderStatusViewModel: ObservableObject {
    @Published var order: CakeOrder?
    @Published var selectedStep = 1
    @Published var isLoading = true
    @Published var isSaving = false
    @Published var successMessage: String?
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    let steps: [(step: Int, statusKey: String, title: String)] = [
        (1, "confirmed", "Confirmed"),
        (2, "baking", "Baking"),
        (3, "decorating", "Decorating"),
        (4, "quality_check", "Quality Checking"),
        (5, "delivered", "Delivered")
    ]

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
                self.errorMessage = "Unable to load order. \(error.localizedDescription)"
                self.isLoading = false
                return
            }

            guard let snapshot, snapshot.exists, let order = CakeOrder(document: snapshot) else {
                self.errorMessage = "Order not found."
                self.isLoading = false
                return
            }

            self.order = order
            self.selectedStep = max(1, min(5, order.currentStep))
            self.isLoading = false
        }
    }

    func updateStatus(orderID: String) async {
        guard !isSaving else { return }
        guard let stepInfo = steps.first(where: { $0.step == selectedStep }) else { return }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            var updates: [String: Any] = [
                "currentStep": stepInfo.step,
                "status": stepInfo.statusKey,
                "updatedAt": FieldValue.serverTimestamp(),
                "progressTimestamps.\(stepInfo.statusKey)": FieldValue.serverTimestamp()
            ]

            if stepInfo.statusKey == "delivered" {
                updates["completedAt"] = FieldValue.serverTimestamp()
            }

            try await db.collection("orders").document(orderID).updateData(updates)
            NotificationCenter.default.post(name: .orderDidChange, object: nil)
            successMessage = "Order status updated to \(stepInfo.title)."
        } catch {
            errorMessage = "Failed to update order status. \(error.localizedDescription)"
        }
    }
}

struct BakerOrderStatusView: View {
    let orderID: String

    @StateObject private var viewModel = BakerOrderStatusViewModel()

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.96, blue: 0.94).ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView("Loading order...")
                    .tint(.cakeBrown)
            } else if let error = viewModel.errorMessage, viewModel.order == nil {
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
            } else if let order = viewModel.order {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        orderHeader(order: order)
                        progressEditorCard(order: order)
                        customerInfoCard(order: order)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
            }
        }
        .navigationTitle("Order Status")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.startListening(orderID: orderID)
        }
        .alert("Updated", isPresented: Binding(
            get: { viewModel.successMessage != nil },
            set: { if !$0 { viewModel.successMessage = nil } }
        )) {
            Button("OK") { viewModel.successMessage = nil }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.order != nil && viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func orderHeader(order: CakeOrder) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                        .frame(width: 76, height: 76)
                    Image(systemName: "birthday.cake.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.cakeBrown.opacity(0.6))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Order ID: \(order.id.uppercased())")
                        .font(.urbanistSemiBold(14))
                        .foregroundColor(Color(red: 0.18, green: 0.18, blue: 0.18))

                    Text(order.cakeName)
                        .font(.urbanistBold(17))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .lineLimit(2)

                    Text(order.statusLabel)
                        .font(.urbanistSemiBold(12))
                        .foregroundColor(order.statusColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(order.statusColor.opacity(0.12))
                        .cornerRadius(10)
                }

                Spacer()
            }

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(.cakeBrown)
                Text("Delivery Date: \(order.formattedDeliveryDate)")
                    .font(.urbanistMedium(13))
                    .foregroundColor(.cakeGrey)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func progressEditorCard(order: CakeOrder) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Update Order Progress")
                .font(.urbanistBold(16))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

            VStack(spacing: 0) {
                ForEach(viewModel.steps, id: \.step) { item in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(item.step < viewModel.selectedStep
                                      ? Color(red: 0.14, green: 0.58, blue: 0.34)
                                      : (item.step == viewModel.selectedStep
                                         ? Color(red: 0.49, green: 0.29, blue: 0.11)
                                         : Color(red: 0.82, green: 0.82, blue: 0.82)))
                                .frame(width: 30, height: 30)
                            if item.step < viewModel.selectedStep {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Text("\(item.step)")
                                    .font(.urbanistBold(12))
                                    .foregroundColor(.white)
                            }
                        }

                        Text(item.title)
                            .font(item.step == viewModel.selectedStep ? .urbanistBold(15) : .urbanistRegular(15))
                            .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12))

                        Spacer()

                        if item.step == viewModel.selectedStep {
                            Text("Current")
                                .font(.urbanistSemiBold(11))
                                .foregroundColor(Color(red: 0.49, green: 0.29, blue: 0.11))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(red: 0.92, green: 0.88, blue: 0.83))
                                .cornerRadius(8)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            viewModel.selectedStep = item.step
                        }
                    }

                    if item.step < viewModel.steps.count {
                        Rectangle()
                            .fill(item.step < viewModel.selectedStep
                                  ? Color(red: 0.14, green: 0.58, blue: 0.34)
                                  : Color(red: 0.86, green: 0.86, blue: 0.86))
                            .frame(width: 2, height: 22)
                            .padding(.leading, 14)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Button {
                Task {
                    await viewModel.updateStatus(orderID: order.id)
                }
            } label: {
                if viewModel.isSaving {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("Updating...")
                            .font(.urbanistBold(15))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                } else {
                    Text("Update Status")
                        .font(.urbanistBold(15))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
            }
            .background(Color.cakeBrown)
            .cornerRadius(16)
            .disabled(viewModel.isSaving)
            .opacity(viewModel.isSaving ? 0.8 : 1.0)
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func customerInfoCard(order: CakeOrder) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Order Details")
                .font(.urbanistBold(16))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

            detailRow(icon: "person.fill", title: "Customer", value: order.customerId)
            detailRow(icon: "location.fill", title: "Delivery Address", value: order.artisanAddress)
            detailRow(icon: "star.fill", title: "Baker", value: order.artisanName)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.cakeBrown)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.urbanistRegular(11))
                    .foregroundColor(.cakeGrey)
                Text(value)
                    .font(.urbanistMedium(14))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            }
        }
    }
}

#Preview {
    NavigationStack {
        BakerOrderStatusView(orderID: "order_001")
    }
}
