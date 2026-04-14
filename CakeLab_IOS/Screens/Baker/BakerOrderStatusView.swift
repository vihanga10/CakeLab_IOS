import SwiftUI
import Combine
import FirebaseFirestore

struct OrderPartyDetails {
    let name: String
    let phone: String
    let address: String
    let notes: String
}

@MainActor
final class BakerOrderStatusViewModel: ObservableObject {
    @Published var order: CakeOrder?
    @Published var selectedStep = 1
    @Published var isLoading = true
    @Published var isSaving = false
    @Published var successMessage: String?
    @Published var errorMessage: String?
    @Published var progressTimestamps: [String: Date] = [:]
    @Published var createdAt: Date?
    @Published var partyDetails = OrderPartyDetails(
        name: "Customer",
        phone: "Not provided",
        address: "Not provided",
        notes: "No special notes"
    )

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

            let data = snapshot.data() ?? [:]
            self.order = order
            self.selectedStep = max(1, min(5, order.currentStep))
            self.createdAt = Self.parseDate(data["createdAt"])
            self.progressTimestamps = Self.parseProgressTimestamps(data["progressTimestamps"])

            Task {
                await self.loadPartyDetails(order: order, data: data)
            }

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

    func timestamp(for statusKey: String) -> Date? {
        progressTimestamps[statusKey]
    }

    private func loadPartyDetails(order: CakeOrder, data: [String: Any]) async {
        let fallbackName = (data["customerName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackPhone = (data["customerPhone"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackAddress = (data["customerAddress"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackNotes = (data["notes"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? (data["specialNotes"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let userSnapshot = try await db.collection("users").document(order.customerId).getDocument()
            let userData = userSnapshot.data() ?? [:]

            let profileName = (userData["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let profilePhone = (userData["phoneNumber"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let profileAddress = (userData["address"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let profileCity = (userData["city"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

            let composedAddress: String? = {
                if let profileAddress, !profileAddress.isEmpty, let profileCity, !profileCity.isEmpty {
                    return "\(profileAddress), \(profileCity)"
                }
                if let profileAddress, !profileAddress.isEmpty { return profileAddress }
                if let profileCity, !profileCity.isEmpty { return profileCity }
                return nil
            }()

            partyDetails = OrderPartyDetails(
                name: profileName?.isEmpty == false ? profileName! : (fallbackName?.isEmpty == false ? fallbackName! : order.customerId),
                phone: profilePhone?.isEmpty == false ? profilePhone! : (fallbackPhone?.isEmpty == false ? fallbackPhone! : "Not provided"),
                address: composedAddress ?? (fallbackAddress?.isEmpty == false ? fallbackAddress! : "Not provided"),
                notes: fallbackNotes?.isEmpty == false ? fallbackNotes! : "No special notes"
            )
        } catch {
            partyDetails = OrderPartyDetails(
                name: fallbackName?.isEmpty == false ? fallbackName! : order.customerId,
                phone: fallbackPhone?.isEmpty == false ? fallbackPhone! : "Not provided",
                address: fallbackAddress?.isEmpty == false ? fallbackAddress! : "Not provided",
                notes: fallbackNotes?.isEmpty == false ? fallbackNotes! : "No special notes"
            )
        }
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

struct BakerOrderStatusView: View {
    let orderID: String

    @StateObject private var viewModel = BakerOrderStatusViewModel()

    private let screenBackground = Color(red: 0.96, green: 0.96, blue: 0.96)
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

    private static let topRightDateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()

    var body: some View {
        ZStack {
            screenBackground.ignoresSafeArea()

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
                    VStack(spacing: 18) {
                        orderHeader(order: order)
                        progressEditorCard(order: order)
                        customerInfoCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
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

                VStack(alignment: .leading, spacing: 6) {
                    Text("Order ID: \(order.id.uppercased())")
                        .font(.urbanistSemiBold(14))
                        .foregroundColor(Color(red: 0.18, green: 0.18, blue: 0.18))

                    Text(order.cakeName)
                        .font(.urbanistBold(18))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .lineLimit(2)

                    HStack(spacing: 14) {
                        HStack(spacing: 5) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 11))
                            Text(viewModel.partyDetails.name)
                                .lineLimit(1)
                        }
                        .font(.urbanistRegular(12))
                        .foregroundColor(.cakeGrey)

                        HStack(spacing: 5) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                            Text(Self.topRightDateFmt.string(from: order.deliveryDate))
                        }
                        .font(.urbanistRegular(12))
                        .foregroundColor(.cakeGrey)
                    }
                }

                Spacer()

                Text(order.statusLabel)
                    .font(.urbanistSemiBold(12))
                    .foregroundColor(order.statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(order.statusColor.opacity(0.12))
                    .cornerRadius(10)
            }
        }
        .padding(16)
        .background(surface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func progressEditorCard(order: CakeOrder) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.steps, id: \.step) { item in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 0) {
                                ZStack {
                                    Circle()
                                        .fill(circleColor(for: item.step))
                                        .frame(width: 36, height: 36)
                                    Circle()
                                        .fill(Color.white.opacity(item.step == viewModel.selectedStep ? 0.9 : 0.0))
                                        .frame(width: 16, height: 16)
                                    if item.step < viewModel.selectedStep {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }

                                if item.step < viewModel.steps.count {
                                    Rectangle()
                                        .fill(Color(red: 0.78, green: 0.78, blue: 0.78))
                                        .frame(width: 1.2, height: 48)
                                        .padding(.top, 4)
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(item.title)
                                        .font(item.step == viewModel.selectedStep ? .urbanistBold(15) : .urbanistMedium(15))
                                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                                    Spacer()

                                    if item.step == viewModel.selectedStep {
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

                                if item.step < viewModel.steps.count {
                                    Divider()
                                        .padding(.top, 10)
                                        .padding(.bottom, 8)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.selectedStep = item.step
                            }
                        }
                    }
                }

                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Expected Date")
                            .font(.urbanistSemiBold(12))
                            .foregroundColor(accent)
                        Text(Self.dateFmt.string(from: order.deliveryDate))
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
                        Text("Update")
                            .font(.urbanistBold(15))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                }
                .background(accent)
                .cornerRadius(18)
                .disabled(viewModel.isSaving)
                .opacity(viewModel.isSaving ? 0.8 : 1.0)
                .padding(.top, 16)
            }
            .padding(16)
        }
        .background(surface)
        .cornerRadius(22)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
    }

    private var customerInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            detailRow(icon: "person.fill", title: "Name", value: viewModel.partyDetails.name)
            detailRow(icon: "mappin.circle.fill", title: "Delivery Address", value: viewModel.partyDetails.address)
            detailRow(icon: "phone.fill", title: "Phone", value: viewModel.partyDetails.phone)
            detailRow(icon: "text.bubble.fill", title: "Special Notes", value: viewModel.partyDetails.notes)
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

    private func circleColor(for step: Int) -> Color {
        if step < viewModel.selectedStep {
            return Color(red: 0.14, green: 0.58, blue: 0.34)
        }
        if step == viewModel.selectedStep {
            return accent
        }
        return Color(red: 0.78, green: 0.78, blue: 0.78)
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
