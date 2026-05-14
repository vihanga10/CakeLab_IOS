import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

// MARK: - CreateCakeRequestViewModel
/// Handles publishing and saving cake requests to Firestore.
@MainActor
final class CreateCakeRequestViewModel: ObservableObject {
    @Published var isSaving = false

    private let db = Firestore.firestore()

    func publishRequest(
        requestData: [String: Any],
        collection: String,
        documentID: String,
        cleanupDraftID: String?,
        triggerNotification: Bool,
        requestTitle: String,
        customerID: String,
        notificationManager: NotificationManager,
        onSuccess: @escaping () -> Void
    ) async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await db.collection(collection).document(documentID).setData(requestData, merge: true)

            if let cleanupDraftID, collection == "cakeRequests" {
                try? await db.collection("draftRequests").document(cleanupDraftID).delete()
            }

            if triggerNotification {
                let title = requestTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Untitled Request" : requestTitle
                notificationManager.notifyRequestPosted(requestTitle: title, userID: customerID)
            }

            NotificationCenter.default.post(name: NSNotification.Name("customerRequestDidChange"), object: nil)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onSuccess()
            }
        } catch {
            print("Error saving request to \(collection): \(error)")
        }
    }

    func fetchCurrentUserProfile(userID: String) async -> [String: Any] {
        do {
            let snapshot = try await db.collection("users").document(userID).getDocument()
            return snapshot.data() ?? [:]
        } catch {
            print("Error fetching current user profile: \(error)")
            return [:]
        }
    }

    func currentUserID() -> String? {
        Auth.auth().currentUser?.uid
    }

    /// Returns a new unique Firestore document ID for the given collection.
    func newDocumentID(for collection: String) -> String {
        Firestore.firestore().collection(collection).document().documentID
    }
}
