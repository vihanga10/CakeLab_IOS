import Foundation
import Combine
import FirebaseFirestore


@MainActor
final class BakerOrdersViewModel: ObservableObject {
    @Published var activeOrders: [CakeOrder] = []
    @Published var activeOrderCustomers: [String: BakerOrderCustomerProfile] = [:]
    @Published var completedOrders: [CakeOrder] = []
    @Published var completedOrderCustomers: [String: BakerOrderCustomerProfile] = [:]
    @Published var completedOrderAmounts: [String: Double] = [:]
    @Published var totalEarnings: Double = 0
    @Published var completedCount: Int = 0
    @Published var isLoading = true
    @Published var isLoadingActive = true

    let user: AppUser
    private let db = Firestore.firestore()

    init(user: AppUser) {
        self.user = user
    }

    func loadActiveOrdersData() async {
        isLoadingActive = true
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

    func fetchCustomerProfile(order: CakeOrder, orderData: [String: Any]) async -> BakerOrderCustomerProfile {
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

    /// Loads completed orders and calculates total earnings
    func loadCompletedOrdersData() async {
        isLoading = true
        do {
            let statuses = ["completed", "delivered", "done"]
            var allOrders: [CakeOrder] = []
            var customerProfiles: [String: BakerOrderCustomerProfile] = [:]

            for key in ["bakerID", "bakerId", "artisanId"] {
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

            completedOrders = allOrders.sorted { $0.deliveryDate > $1.deliveryDate }
            completedOrderCustomers = customerProfiles
            completedCount = completedOrders.count

            let paidAmountsByOrderID = await loadPaidAmountsByOrderID()
            completedOrderAmounts = completedOrders.reduce(into: [String: Double]()) { amounts, order in
                let paidAmount = paidAmountsByOrderID[order.id] ?? 0
                amounts[order.id] = paidAmount > 0 ? paidAmount : order.amount
            }
            totalEarnings = completedOrders.reduce(0) { total, order in
                total + (completedOrderAmounts[order.id] ?? order.amount)
            }
            isLoading = false
        } catch {
            print("Error loading completed orders: \(error.localizedDescription)")
            isLoading = false
        }
    }


    // Returns a map of orderID → total paid amount for all successful payments by the baker.
    private func loadPaidAmountsByOrderID() async -> [String: Double] {
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

    func firstString(_ values: Any?...) -> String {
        values.compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    func parseDouble(_ value: Any?) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String {
            let cleaned = value.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(cleaned) ?? 0
        }
        return 0
    }
}
