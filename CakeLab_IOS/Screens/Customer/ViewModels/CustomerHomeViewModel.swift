import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore



@MainActor
final class CustomerHomeViewModel: ObservableObject {

    
    @Published var activeOrders: [CakeOrder]  = []
    @Published var artisans: [ArtisanProfile] = []

    @Published var isLoadingOrders   = false
    @Published var isLoadingArtisans = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    
    func fetchActiveOrders(for userId: String) async {
        isLoadingOrders = true
        errorMessage    = nil
        do {
            let snapshot = try await db.collection("orders")
                .whereField("customerId", isEqualTo: userId)
                .whereField("status", in: ["confirmed", "baking", "decorating", "quality_check"])
                .order(by: "createdAt", descending: true)
                .limit(to: 10)
                .getDocuments()

            activeOrders = snapshot.documents.compactMap { CakeOrder(document: $0) }
        } catch {
            errorMessage = "Could not load your orders."
            print("ERROR CustomerHomeViewModel.fetchActiveOrders: \(error.localizedDescription)")
        }
        isLoadingOrders = false
    }

    
    // Fetches the latest user data from Firestore 
    func refreshUser(current user: AppUser) async -> AppUser {
        do {
            let currentUID = Auth.auth().currentUser?.uid ?? user.id
            let snapshot = try await db.collection("users").document(currentUID).getDocument()
            let updatedUser = try snapshot.data(as: AppUser.self)
            return updatedUser
        } catch {
            print("ERROR CustomerHomeViewModel.refreshUser: \(error.localizedDescription)")
            return user
        }
    }


    func fetchArtisans() async {
        isLoadingArtisans = true
        do {
            let snapshot = try await db.collection("artisans")
                .order(by: "rating", descending: true)
                .limit(to: 100)
                .getDocuments()

            var loaded = snapshot.documents.compactMap { ArtisanProfile(document: $0) }

            if loaded.isEmpty {
                let usersSnap = try await db.collection("users")
                    .whereField("role", isEqualTo: "baker")
                    .limit(to: 100)
                    .getDocuments()
                loaded = usersSnap.documents.compactMap { ArtisanProfile(document: $0) }
            }

            let reviewed = await hydrateReviewStats(for: loaded)
            artisans = reviewed.sorted { $0.rating > $1.rating }
        } catch {
            errorMessage = "Could not load artisans."
            print("ERROR CustomerHomeViewModel.fetchArtisans: \(error.localizedDescription)")
        }
        isLoadingArtisans = false
    }

    private func hydrateReviewStats(for source: [ArtisanProfile]) async -> [ArtisanProfile] {
        var output: [ArtisanProfile] = []
        output.reserveCapacity(source.count)

        for artisan in source {
            guard let stats = await fetchBakerReviewStats(bakerID: artisan.id) else {
                output.append(artisan)
                continue
            }

            output.append(ArtisanProfile(
                id: artisan.id,
                name: artisan.name,
                rating: stats.rating,
                reviewCount: stats.count,
                specialties: artisan.specialties,
                city: artisan.city,
                location: artisan.location,
                isOnline: artisan.isOnline,
                imageURL: artisan.imageURL,
                profileImageBase64: artisan.profileImageBase64,
                latitude: artisan.latitude,
                longitude: artisan.longitude
            ))
        }

        return output
    }

    private func fetchBakerReviewStats(bakerID: String) async -> (rating: Double, count: Int)? {
        let trimmedID = bakerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return nil }

        var ratingsByID: [String: Int] = [:]
        for key in ["bakerID", "bakerId", "artisanId"] {
            do {
                let snapshot = try await db.collection("reviews")
                    .whereField(key, isEqualTo: trimmedID)
                    .getDocuments()

                for document in snapshot.documents {
                    let rating = parseInt(document.data()["rating"])
                    if rating > 0 { ratingsByID[document.documentID] = rating }
                }
            } catch {
                print("WARN unable to load home baker reviews for \(trimmedID) by \(key): \(error.localizedDescription)")
            }
        }

        let ratings = Array(ratingsByID.values)
        guard !ratings.isEmpty else { return nil }

        let average = Double(ratings.reduce(0, +)) / Double(ratings.count)
        return (average, ratings.count)
    }

    private func parseInt(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0 }
        return 0
    }
}
