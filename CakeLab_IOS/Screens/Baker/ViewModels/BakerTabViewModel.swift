import Foundation
import Combine
import FirebaseFirestore

// MARK: - BakerTabViewModel
/// Handles login-time side-effects for the baker tab: loading matching requests
/// and triggering in-app notifications for new matches.
@MainActor
final class BakerTabViewModel: ObservableObject {
    @Published var matchingRequestsLoaded = false

    private let db = Firestore.firestore()

    /// Fetches open matching requests once per session and fires notifications
    /// for the first three matches. Pass the baker's AppUser and the app-wide
    /// NotificationManager as parameters because ViewModels cannot hold
    /// @EnvironmentObject references.
    func loadMatchingRequestsAndNotify(
        user: AppUser,
        notificationManager: NotificationManager
    ) async {
        guard !matchingRequestsLoaded else { return }

        do {
            let bakerSpecialties = try await loadBakerSpecialties(userID: user.id)
            guard !bakerSpecialties.isEmpty else {
                matchingRequestsLoaded = true
                return
            }

            let bidsSnapshot = try await db.collection("bids")
                .whereField("bakerID", isEqualTo: user.id)
                .getDocuments()
            let placedBidRequestIDs = Set(
                bidsSnapshot.documents.compactMap { $0.data()["requestDocumentID"] as? String }
            )

            let snapshot = try await db.collection("cakeRequests")
                .whereField("status", isEqualTo: "open")
                .limit(to: 50)
                .getDocuments()

            var requests: [CakeRequestRecord] = []
            for document in snapshot.documents {
                if let request = CakeRequestRecord(document: document) {
                    guard !placedBidRequestIDs.contains(request.id) else { continue }
                    guard requestMatchesBakerSpecialties(request, specialties: bakerSpecialties, bakerID: user.id) else { continue }
                    requests.append(request)
                }
            }

            if !requests.isEmpty {
                for (index, request) in requests.prefix(3).enumerated() {
                    let delay = Double(index) * 0.5
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        notificationManager.notifyNewMatchingRequest(
                            requestTitle: request.title,
                            category: request.displayCategory,
                            budget: request.budgetMax,
                            customerID: request.customerID,
                            bakerID: user.id,
                            orderID: request.id
                        )
                    }
                }
            }
        } catch {
            print("Error loading matching requests: \(error.localizedDescription)")
        }

        matchingRequestsLoaded = true
    }

    // MARK: - Private Helpers

    private func loadBakerSpecialties(userID: String) async throws -> [String] {
        let snapshot = try await db.collection("artisans").document(userID).getDocument()
        return snapshot.data()?["specialties"] as? [String] ?? []
    }

    private func requestMatchesBakerSpecialties(
        _ request: CakeRequestRecord,
        specialties: [String],
        bakerID: String
    ) -> Bool {
        if request.isDirectRequest {
            return request.targetArtisanId == bakerID
        }

        let normalizedSpecialties = Set(specialties.map(normalizedCakeCategory).filter { !$0.isEmpty })
        guard !normalizedSpecialties.isEmpty else { return false }

        let requestCategories = request.categories.isEmpty ? [request.category] : request.categories
        let categories = requestCategories.isEmpty ? [request.displayCategory] : requestCategories
        let normalizedRequestCategories = Set(categories.map(normalizedCakeCategory).filter { !$0.isEmpty })

        return !normalizedRequestCategories.isDisjoint(with: normalizedSpecialties)
    }

    private func normalizedCakeCategory(_ raw: String) -> String {
        let cleaned = raw
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "cakes", with: "")
            .replacingOccurrences(of: "cake", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
