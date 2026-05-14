import Foundation
import Combine
import FirebaseAuth


// Loads the customer's draft cake requests using CustomerRequestStore.
@MainActor
final class DraftIdeasViewModel: ObservableObject {
    @Published var drafts: [CakeRequestRecord] = []
    @Published var isLoading = false

    private let requestStore = CustomerRequestStore()

    func fetchDrafts() async {
        guard let userID = Auth.auth().currentUser?.uid else {
            drafts = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            drafts = try await requestStore.fetchRequests(for: userID, from: .draft)
        } catch {
            print("Error fetching draft requests: \(error)")
        }
    }
}
