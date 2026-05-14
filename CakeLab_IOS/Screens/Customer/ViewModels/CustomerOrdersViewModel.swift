import Foundation
import Combine
import FirebaseFirestore


// Loads active and completed orders from Firestore for the customer orders tab.
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

            let parsedActiveOrders = activeDocs.documents
                .compactMap(CakeOrder.init(document:))
                .sorted { $0.deliveryDate < $1.deliveryDate }
                .map(CustomerOrder.init(from:))

            let parsedCompletedOrders = completedDocs.documents
                .compactMap(CakeOrder.init(document:))
                .sorted { $0.deliveryDate > $1.deliveryDate }
                .map(CustomerOrder.init(from:))

            activeOrders = await enrichOrdersWithBakerProfiles(parsedActiveOrders)
            completedOrders = await enrichOrdersWithBakerProfiles(parsedCompletedOrders)
        } catch {
            print("Error loading customer orders: \(error.localizedDescription)")
        }

        isLoading = false
    }

    

    private func enrichOrdersWithBakerProfiles(_ orders: [CustomerOrder]) async -> [CustomerOrder] {
        var cache: [String: BakerOrderProfile] = [:]
        var enrichedOrders: [CustomerOrder] = []
        enrichedOrders.reserveCapacity(orders.count)

        for order in orders {
            let bakerID = order.bakerID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !bakerID.isEmpty else { enrichedOrders.append(order); continue }

            let profile: BakerOrderProfile
            if let cached = cache[bakerID] {
                profile = cached
            } else {
                profile = await fetchBakerProfile(bakerID: bakerID)
                cache[bakerID] = profile
            }
            enrichedOrders.append(order.enriched(with: profile))
        }

        return enrichedOrders
    }

    private func fetchBakerProfile(bakerID: String) async -> BakerOrderProfile {
        async let artisanProfile = fetchBakerProfileData(collection: "artisans", bakerID: bakerID)
        async let userProfile = fetchBakerProfileData(collection: "users", bakerID: bakerID)

        let (artisanData, userData) = await (artisanProfile, userProfile)
        let primaryData = artisanData ?? [:]
        let fallbackData = userData ?? [:]

        let name = firstString(primaryData["shopName"], primaryData["name"], fallbackData["name"])
        let address = firstString(primaryData["address"], primaryData["location"], fallbackData["address"])
        let city = SriLankaDistricts.canonical(firstString(primaryData["city"], fallbackData["city"])) ?? firstString(primaryData["city"], fallbackData["city"])
        let rating = parseDouble(primaryData["rating"])
        let reviewCount = parseInt(primaryData["reviewCount"])
        let ratingText = rating > 0
            ? String(format: "%.1f", rating)
            : firstString(primaryData["artisanRating"], fallbackData["artisanRating"])

        return BakerOrderProfile(
            name: name, ratingText: ratingText, reviewCount: reviewCount,
            address: address, city: city,
            profileImageBase64: firstString(primaryData["profileImageBase64"], fallbackData["profileImageBase64"]),
            imageURL: firstString(primaryData["imageURL"], primaryData["avatarURL"], fallbackData["imageURL"], fallbackData["avatarURL"])
        )
    }

    private func fetchBakerProfileData(collection: String, bakerID: String) async -> [String: Any]? {
        do {
            let document = try await db.collection(collection).document(bakerID).getDocument()
            return document.data()
        } catch { return nil }
    }

    private func firstString(_ values: Any?...) -> String {
        values.compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    private func parseInt(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) ?? 0 }
        return 0
    }

    private func parseDouble(_ value: Any?) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) ?? 0 }
        return 0
    }
}
