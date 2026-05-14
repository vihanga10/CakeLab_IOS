import Foundation
import Combine
import FirebaseFirestore

// Loads baker reviews and customer profiles.
@MainActor
final class BakerReviewsViewModel: ObservableObject {
    @Published var reviews: [Review] = []
    @Published var customerProfiles: [String: ReviewCustomerProfile] = [:]
    @Published var isLoading = true

    var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        return Double(reviews.reduce(0) { $0 + $1.rating }) / Double(reviews.count)
    }

    // Loads reviews from CoreData cache first for instant display, then fetches fresh data
    func loadReviews(for user: AppUser) async {
        let db = Firestore.firestore()
        isLoading = reviews.isEmpty

        let cachedReviews = CoreDataCacheService.shared.cachedReviews(for: user.id)
        if !cachedReviews.isEmpty {
            reviews = cachedReviews
            let cachedCustomerIDs = Set(cachedReviews.map(\.customerID).filter { !$0.isEmpty })
            customerProfiles = CoreDataCacheService.shared.cachedCustomerProfiles(for: cachedCustomerIDs)
        }

        isLoading = false

        var reviewsByID: [String: Review] = [:]

        for key in ["bakerID", "bakerId", "artisanId"] {
            do {
                let query = db.collection("reviews").whereField(key, isEqualTo: user.id)
                let snapshot = try await withTimeout(seconds: 4) {
                    try await query.getDocuments()
                }

                for document in snapshot.documents {
                    if let review = Review(document: document) {
                        reviewsByID[review.id] = review
                    }
                }
            } catch {
                print("Error loading reviews by \(key): \(error.localizedDescription)")
            }
        }

        let loadedReviews = reviewsByID.values.sorted { $0.createdAt > $1.createdAt }
        if !loadedReviews.isEmpty {
            reviews = loadedReviews
            CoreDataCacheService.shared.cacheReviews(loadedReviews, for: user.id)
        }

        let loadedCustomerProfiles = await loadCustomerProfiles(for: loadedReviews, db: db)
        if !loadedCustomerProfiles.isEmpty {
            customerProfiles.merge(loadedCustomerProfiles) { _, live in live }
            CoreDataCacheService.shared.cacheCustomerProfiles(loadedCustomerProfiles)
        }
    }

    func resolvedCustomer(for review: Review) -> ReviewCustomerProfile {
        let profile = customerProfiles[review.customerID]
        return ReviewCustomerProfile(
            name: firstString(profile?.name, review.customerName, "Customer"),
            imageReference: firstString(profile?.imageReference, review.customerImage)
        )
    }

    private func loadCustomerProfiles(for reviews: [Review], db: Firestore) async -> [String: ReviewCustomerProfile] {
        var profiles: [String: ReviewCustomerProfile] = [:]
        let customerIDs = Set(reviews.map(\.customerID).filter { !$0.isEmpty })

        for customerID in customerIDs {
            do {
                let reference = db.collection("users").document(customerID)
                let document = try await withTimeout(seconds: 3) {
                    try await reference.getDocument()
                }
                let data = document.data() ?? [:]
                profiles[customerID] = ReviewCustomerProfile(
                    name: firstString(data["name"], data["fullName"], data["displayName"], data["email"]),
                    imageReference: firstString(
                        data["profileImageBase64"],
                        data["avatarBase64"],
                        data["photoBase64"],
                        data["imageURL"],
                        data["avatarURL"],
                        data["photoURL"]
                    )
                )
            } catch {
                print("Error loading review customer \(customerID): \(error.localizedDescription)")
            }
        }

        return profiles
    }

    private func withTimeout<T>(
        seconds: UInt64,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw ReviewLoadTimeout()
            }

            guard let result = try await group.next() else { throw ReviewLoadTimeout() }
            group.cancelAll()
            return result
        }
    }

    private func firstString(_ values: Any?...) -> String {
        values.compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }
}

// MARK: - Review Load Timeout
private struct ReviewLoadTimeout: Error {}
