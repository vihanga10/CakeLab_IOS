import Foundation
import Combine
import FirebaseAuth

// MARK: - PublishRequestViewModel
/// Loads the customer's published cake requests using CustomerRequestStore.
@MainActor
final class PublishRequestViewModel: ObservableObject {
    @Published var requests: [CakeRequestRecord] = []
    @Published var isLoading = false

    private let requestStore = CustomerRequestStore()

    func fetchPublishedRequests() async {
        guard let userID = Auth.auth().currentUser?.uid else {
            requests = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            requests = try await requestStore.fetchRequests(for: userID, from: .published)
        } catch {
            print("Error fetching published requests: \(error)")
        }
    }
}
