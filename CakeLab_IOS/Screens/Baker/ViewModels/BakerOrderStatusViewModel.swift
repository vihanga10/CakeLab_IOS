import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class BakerOrderStatusViewModel: ObservableObject {
    @Published var order: CakeOrder?
    @Published var selectedStep = 1
    @Published var isLoading = true
    @Published var isSaving = false
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

    // Ordered workflow stages shown in the baker's progress tracker.
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

    func updateStatus(orderID: String, notificationManager: NotificationManager) async {
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
            WidgetDataSyncManager.shared.refreshFromCurrentSession()
            notificationManager.notifyBakerOrderStatusUpdated(
                cakeName: order?.cakeName ?? "Order",
                stageTitle: stepInfo.title,
                statusKey: stepInfo.statusKey,
                orderID: orderID,
                customerID: order?.customerId ?? "",
                bakerID: order?.artisanId ?? ""
            )
        } catch {
            errorMessage = "Failed to update order status. \(error.localizedDescription)"
        }
    }

    // Returns the recorded completion time for the given workflow stage key, if available.
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
                if let address = profileAddress, !address.isEmpty, let city = profileCity, !city.isEmpty {
                    return "\(address), \(city)"
                }
                if let address = profileAddress, !address.isEmpty { return address }
                if let city = profileCity, !city.isEmpty { return city }
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
        if let timestamp = raw as? Timestamp { return timestamp.dateValue() }
        if let interval = raw as? TimeInterval { return Date(timeIntervalSince1970: interval) }
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
