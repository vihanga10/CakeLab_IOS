import Foundation
import Combine
import FirebaseFirestore

// Listens to real-time order status updates from Firestore for the customer order status screen.
@MainActor
final class CustomerOrderStatusViewModel: ObservableObject {
    @Published var order: CakeOrder?
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var progressTimestamps: [String: Date] = [:]
    @Published var createdAt: Date?
    @Published var requestCategory: String?
    @Published var requestBudgetMin: Double?
    @Published var requestBudgetMax: Double?
    @Published var bakerProfile = OrderStatusBakerProfile.empty

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit { listener?.remove() }

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
            self.requestCategory = nil
            self.requestBudgetMin = nil
            self.requestBudgetMax = nil
            self.isLoading = false
            self.bakerProfile = OrderStatusBakerProfile(
                name: order.artisanName, ratingText: order.artisanRating, reviewCount: 0,
                address: order.artisanAddress,
                city: "",
                phone: self.firstString(data["artisanPhone"], data["bakerPhone"], data["phone"], data["phoneNumber"]),
                profileImageBase64: "",
                imageURL: ""
            )

            let directCategory = Self.parseCategory(from: data)
            let directBudgetMin = Self.parseDouble(data["budgetMin"])
            let directBudgetMax = Self.parseDouble(data["budgetMax"])

            if !directCategory.isEmpty { self.requestCategory = directCategory }
            if directBudgetMin > 0 { self.requestBudgetMin = directBudgetMin }
            if directBudgetMax > 0 { self.requestBudgetMax = directBudgetMax }

            if (directCategory.isEmpty || directBudgetMin <= 0 || directBudgetMax <= 0),
               let requestDocumentID = data["requestDocumentID"] as? String,
               !requestDocumentID.isEmpty {
                Task { await self.loadRequestDetails(requestDocumentID: requestDocumentID) }
            }

            if !order.artisanId.isEmpty {
                Task { await self.loadBakerProfile(bakerID: order.artisanId, orderData: data) }
            }
        }
    }

    func timestamp(for statusKey: String) -> Date? { progressTimestamps[statusKey] }


    private func loadRequestDetails(requestDocumentID: String) async {
        do {
            let snapshot = try await db.collection("cakeRequests").document(requestDocumentID).getDocument()
            guard let data = snapshot.data() else { return }
            let category = Self.parseCategory(from: data)
            let budgetMin = Self.parseDouble(data["budgetMin"])
            let budgetMax = Self.parseDouble(data["budgetMax"])
            if !category.isEmpty { requestCategory = category }
            if budgetMin > 0 { requestBudgetMin = budgetMin }
            if budgetMax > 0 { requestBudgetMax = budgetMax }
        } catch {
            print("Error loading linked cake request: \(error.localizedDescription)")
        }
    }

    private func loadBakerProfile(bakerID: String, orderData: [String: Any]) async {
        async let artisanProfile = fetchBakerProfileData(collection: "artisans", bakerID: bakerID)
        async let userProfile = fetchBakerProfileData(collection: "users", bakerID: bakerID)

        let (artisanData, userData) = await (artisanProfile, userProfile)
        let primaryData = artisanData ?? [:]
        let fallbackData = userData ?? [:]

        let rawCity = firstString(primaryData["city"], fallbackData["city"], orderData["artisanCity"], orderData["bakerCity"])
        let rating = Self.parseDouble(primaryData["rating"])
        let reviewCount = Self.parseInt(primaryData["reviewCount"])
        let ratingText = rating > 0
            ? String(format: "%.1f", rating)
            : firstString(primaryData["artisanRating"], fallbackData["artisanRating"], orderData["artisanRating"])

        bakerProfile = OrderStatusBakerProfile(
            name: firstString(primaryData["shopName"], primaryData["name"], fallbackData["name"], orderData["artisanName"]),
            ratingText: ratingText, reviewCount: reviewCount,
            address: firstString(primaryData["address"], primaryData["location"], fallbackData["address"], orderData["artisanAddress"]),
            city: SriLankaDistricts.canonical(rawCity) ?? rawCity,
            phone: firstString(
                primaryData["phone"],
                primaryData["phoneNumber"],
                primaryData["contactNumber"],
                primaryData["mobile"],
                fallbackData["phone"],
                fallbackData["phoneNumber"],
                fallbackData["contactNumber"],
                fallbackData["mobile"],
                orderData["artisanPhone"],
                orderData["bakerPhone"],
                orderData["phone"],
                orderData["phoneNumber"]
            ),
            profileImageBase64: firstString(primaryData["profileImageBase64"], fallbackData["profileImageBase64"]),
            imageURL: firstString(primaryData["imageURL"], primaryData["avatarURL"], fallbackData["imageURL"], fallbackData["avatarURL"])
        )
    }

    private func fetchBakerProfileData(collection: String, bakerID: String) async -> [String: Any]? {
        do {
            let document = try await db.collection(collection).document(bakerID).getDocument()
            return document.data()
        } catch {
            print("Error loading \(collection) baker profile: \(error.localizedDescription)")
            return nil
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
            if let date = parseDate(value) { result[key] = date }
        }
        return result
    }

    private static func parseCategory(from data: [String: Any]) -> String {
        if let category = data["category"] as? String,
           !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return category }
        if let categories = data["categories"] as? [String],
           let first = categories.first,
           !first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return first }
        return ""
    }

    static func parseDouble(_ raw: Any?) -> Double {
        if let value = raw as? Double { return value }
        if let value = raw as? Int { return Double(value) }
        if let value = raw as? NSNumber { return value.doubleValue }
        if let value = raw as? String {
            return Double(value.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        }
        return 0
    }

    static func parseInt(_ raw: Any?) -> Int {
        if let value = raw as? Int { return value }
        if let value = raw as? NSNumber { return value.intValue }
        if let value = raw as? String { return Int(value) ?? 0 }
        return 0
    }

    private func firstString(_ values: Any?...) -> String {
        values.compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }
}
