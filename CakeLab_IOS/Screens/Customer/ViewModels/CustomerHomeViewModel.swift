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

            artisans = loaded.sorted { $0.rating > $1.rating }
        } catch {
            errorMessage = "Could not load artisans."
            print("ERROR CustomerHomeViewModel.fetchArtisans: \(error.localizedDescription)")
        }
        isLoadingArtisans = false
    }
}
