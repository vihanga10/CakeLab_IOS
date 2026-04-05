import Foundation
import Combine
import FirebaseFirestore

// MARK: - CustomerHomeViewModel
//
// Handles all data-fetching for the Customer Home Screen.
//
// ┌────────────────────────────────────────────────────────┐
// │  Component            │  Data source                   │
// ├────────────────────────────────────────────────────────┤
// │  Search Bar           │  Static UI – no DB needed      │
// │  Dream Cake Card      │  Static UI – no DB needed      │
// │  What Are You         │  Static constants – same for   │
// │    Craving?           │  every customer                │
// │  Active Orders        │  Firestore "orders" collection │
// │                       │  filtered by customerId == uid │
// │                       │  → DIFFERENT per user          │
// │  Artisans Near You    │  Firestore "artisans" collection│
// │                       │  → SAME for every customer     │
// └────────────────────────────────────────────────────────┘

@MainActor
final class CustomerHomeViewModel: ObservableObject {

    // MARK: - Published state
    @Published var activeOrders: [CakeOrder]  = []
    @Published var artisans: [ArtisanProfile] = []

    @Published var isLoadingOrders   = false
    @Published var isLoadingArtisans = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    // MARK: - Fetch Active Orders  (user-specific)
    /// Queries the "orders" collection for documents where
    /// `customerId == userId` AND status is an active stage.
    /// First-time users will receive an empty array — the view
    /// handles this with an empty-state prompt.
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

    // MARK: - Fetch Artisans  (common for all customers)
    /// Queries the "artisans" collection ordered by rating.
    /// The same list is shown to every customer — no per-user filtering.
    func fetchArtisans() async {
        isLoadingArtisans = true
        do {
            let snapshot = try await db.collection("artisans")
                .order(by: "rating", descending: true)
                .limit(to: 10)
                .getDocuments()

            artisans = snapshot.documents.compactMap { ArtisanProfile(document: $0) }
        } catch {
            errorMessage = "Could not load artisans."
            print("ERROR CustomerHomeViewModel.fetchArtisans: \(error.localizedDescription)")
        }
        isLoadingArtisans = false
    }
}
