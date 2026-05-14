import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

// MARK: - BakerProfileViewModel
/// Loads and aggregates all data for the baker profile tab from Firestore.
@MainActor
final class BakerProfileViewModel: ObservableObject {
    @Published var profileData: BakerProfileData = .empty
    @Published var isLoading = true
    @Published var completedOrders: [CakeOrder] = []
    @Published var monthlyOrders: [MonthlyOrderData] = []
    @Published var earningsData: EarningsData = .empty
    @Published var reviews: [Review] = []
    @Published var paymentRecords: [BakerPaymentRecord] = []

    var performanceSnapshot: BakerPerformanceSnapshot {
        BakerPerformanceSnapshot.build(orders: completedOrders, reviews: reviews)
    }

    var earningsSnapshot: BakerEarningsSnapshot {
        BakerEarningsSnapshot.build(orders: completedOrders, payments: paymentRecords)
    }

    private let db = Firestore.firestore()

    func loadProfileData(user: AppUser) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let artisanSnapshot = try await loadArtisanDocument(userID: user.id)
            let artisanData = artisanSnapshot.data() ?? [:]

            let statuses = ["completed", "delivered", "done"]
            var completedCount = 0
            for key in ["bakerID", "bakerId"] {
                if let count = try? await db.collection("orders")
                    .whereField(key, isEqualTo: user.id)
                    .whereField("status", in: statuses)
                    .count
                    .getAggregation(source: .server)
                    .count {
                    completedCount = max(completedCount, Int(truncating: count))
                }
            }

            profileData = BakerProfileData(
                shopName: resolveShopName(artisanData: artisanData, user: user),
                address: resolveAddress(artisanData: artisanData, user: user),
                city: resolveCity(artisanData: artisanData, user: user),
                isOnline: artisanData["isOnline"] as? Bool ?? true,
                rating: artisanData["rating"] as? Double ?? 0,
                reviewCount: artisanData["reviewCount"] as? Int ?? 0,
                completedOrders: completedCount,
                about: resolveAbout(artisanData: artisanData),
                createdAt: resolveCreatedAt(artisanData: artisanData, user: user),
                specialties: resolveSpecialties(artisanData: artisanData),
                profileImageURL: resolveProfileImageURL(artisanData: artisanData, user: user),
                profileImageBase64: artisanData["profileImageBase64"] as? String ?? "",
                coverImageURL: artisanData["coverImageURL"] as? String ?? "",
                coverImageBase64: artisanData["coverImageBase64"] as? String ?? "",
                portfolioWorks: resolvePortfolioWorks(artisanData: artisanData)
            )
        } catch {
            print("ERROR BakerProfileViewModel.loadProfileData: \(error.localizedDescription)")
            profileData = BakerProfileData.empty
        }
    }

    func loadAnalyticsData(user: AppUser) async {
        async let ordersTask = fetchCompletedOrders(userID: user.id)
        async let paymentsTask = fetchPayments(userID: user.id)
        async let reviewsTask = fetchReviews(userID: user.id)

        do { completedOrders = try await ordersTask } catch {
            print("Error loading completed order analytics: \(error.localizedDescription)")
            completedOrders = []
        }
        do { paymentRecords = try await paymentsTask } catch {
            print("Error loading baker payment analytics: \(error.localizedDescription)")
            paymentRecords = []
        }
        do { reviews = try await reviewsTask } catch {
            print("Error loading review analytics: \(error.localizedDescription)")
            reviews = []
        }

        monthlyOrders = performanceSnapshot.monthlyOrders.map {
            MonthlyOrderData(month: $0.label, count: Int($0.value))
        }

        let summary = earningsSnapshot
        earningsData = EarningsData(
            totalEarningsThisMonth: summary.totalEarningsThisMonth,
            totalEarningsLastMonth: summary.totalEarningsLastMonth,
            totalEarningsThisYear: summary.totalEarningsThisYear,
            avgPerOrder: summary.avgPerOrder
        )
    }

    // MARK: - Firestore Loaders

    private func loadArtisanDocument(userID: String) async throws -> DocumentSnapshot {
        let direct = try await db.collection("artisans").document(userID).getDocument()
        if direct.exists { return direct }

        let query = try await db.collection("artisans")
            .whereField("uid", isEqualTo: userID)
            .limit(to: 1)
            .getDocuments()

        return query.documents.first ?? direct
    }

    private func fetchCompletedOrders(userID: String) async throws -> [CakeOrder] {
        let statuses = ["completed", "delivered", "done"]
        var orders: [CakeOrder] = []

        for key in ["bakerID", "bakerId", "artisanId"] {
            do {
                let snapshot = try await db.collection("orders")
                    .whereField(key, isEqualTo: userID)
                    .whereField("status", in: statuses)
                    .getDocuments()

                for doc in snapshot.documents {
                    if let order = CakeOrder(document: doc), !orders.contains(where: { $0.id == order.id }) {
                        orders.append(order)
                    }
                }
            } catch {
                print("Unable to load completed orders by \(key): \(error.localizedDescription)")
            }
        }

        return orders.sorted { $0.deliveryDate < $1.deliveryDate }
    }

    private func fetchReviews(userID: String) async throws -> [Review] {
        var reviewsByID: [String: Review] = [:]

        for key in ["bakerID", "bakerId", "artisanId"] {
            do {
                let snapshot = try await db.collection("reviews")
                    .whereField(key, isEqualTo: userID)
                    .getDocuments()

                for document in snapshot.documents {
                    if let review = Review(document: document) {
                        reviewsByID[review.id] = review
                    }
                }
            } catch {
                print("Unable to load reviews by \(key): \(error.localizedDescription)")
            }
        }

        return reviewsByID.values.sorted { $0.createdAt > $1.createdAt }
    }

    private func fetchPayments(userID: String) async throws -> [BakerPaymentRecord] {
        let snapshot = try await db.collection("payments")
            .whereField("bakerId", isEqualTo: userID)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            return BakerPaymentRecord(
                id: doc.documentID,
                orderID: data["orderID"] as? String ?? "",
                amount: parseDouble(data["amount"]),
                total: parseDouble(data["total"]),
                method: data["method"] as? String ?? "",
                status: data["status"] as? String ?? "success",
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        .sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Data Resolvers

    private func resolveShopName(artisanData: [String: Any], user: AppUser) -> String {
        let options = [artisanData["shopName"] as? String, artisanData["name"] as? String, user.name]
        return options.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first(where: { !$0.isEmpty }) ?? "Baker Shop"
    }

    private func resolveAddress(artisanData: [String: Any], user: AppUser) -> String {
        let options = [artisanData["location"] as? String, artisanData["address"] as? String, user.address]
        return options.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first(where: { !$0.isEmpty }) ?? "No address added"
    }

    private func resolveCity(artisanData: [String: Any], user: AppUser) -> String {
        let options = [artisanData["city"] as? String, user.city]
        return options.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first(where: { !$0.isEmpty }) ?? ""
    }

    private func resolveAbout(artisanData: [String: Any]) -> String {
        let options = [artisanData["about"] as? String, artisanData["bio"] as? String, artisanData["description"] as? String]
        return options.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first(where: { !$0.isEmpty }) ?? "No profile description added yet."
    }

    private func resolveCreatedAt(artisanData: [String: Any], user: AppUser) -> Date {
        if let ts = artisanData["createdAt"] as? Timestamp { return ts.dateValue() }
        return user.createdAt
    }

    private func resolveSpecialties(artisanData: [String: Any]) -> [String] {
        let values = artisanData["specialties"] as? [String] ?? []
        return values.isEmpty ? ["Custom Cakes"] : values
    }

    private func resolveProfileImageURL(artisanData: [String: Any], user: AppUser) -> String {
        if let imageURL = artisanData["imageURL"] as? String, !imageURL.isEmpty { return imageURL }
        return user.avatarURL ?? ""
    }

    private func resolvePortfolioWorks(artisanData: [String: Any]) -> [PortfolioPreviewWork] {
        let publishedWorks = artisanData["portfolioPublishedWorks"] as? [[String: Any]] ?? []
        let resolved = publishedWorks.compactMap(PortfolioPreviewWork.init(dictionary:))
        if !resolved.isEmpty { return Array(resolved.prefix(6)) }

        let legacyImages = artisanData["portfolioImages"] as? [String] ?? artisanData["portfolioURLs"] as? [String] ?? []
        return legacyImages.prefix(6).enumerated().map { index, imageRef in
            PortfolioPreviewWork(id: "legacy-\(index)", title: "Portfolio Work", description: "", imageReference: imageRef, traits: [])
        }
    }

    private func parseDouble(_ value: Any?) -> Double {
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
