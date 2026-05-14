import Foundation
import Combine
import FirebaseFirestore

// MARK: - ReviewModalViewModel
/// Handles review submission to Firestore and baker stats updates.
@MainActor
final class ReviewModalViewModel: ObservableObject {
    @Published var isSubmitting = false
    @Published var showSuccessMessage = false

    private let db = Firestore.firestore()

    func submitReview(
        orderID: String,
        artisanId: String,
        customerId: String,
        bakerName: String,
        rating: Int,
        reviewText: String,
        reviewImagesBase64: [String],
        onSuccess: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) {
        guard !reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isSubmitting = true

        Task {
            do {
                let customerProfile = await loadCustomerProfile(customerId: customerId)
                let trimmedReview = reviewText.trimmingCharacters(in: .whitespacesAndNewlines)
                let customerName = customerProfile.name.isEmpty ? "Customer" : customerProfile.name

                let review: [String: Any] = [
                    "orderID": orderID,
                    "bakerID": artisanId,
                    "artisanId": artisanId,
                    "customerID": customerId,
                    "customerId": customerId,
                    "customerName": customerName,
                    "customerImage": customerProfile.imageBase64,
                    "rating": rating,
                    "comment": trimmedReview,
                    "reviewText": trimmedReview,
                    "reviewImagesBase64": reviewImagesBase64,
                    "createdAt": Timestamp(date: Date()),
                    "bakerName": bakerName
                ]

                try await db.collection("reviews").document().setData(review)
                await updateBakerReviewStats(artisanId: artisanId)

                isSubmitting = false
                showSuccessMessage = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onSuccess()
                }
            } catch {
                isSubmitting = false
                onError("Failed to submit review: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private Helpers

    private func loadCustomerProfile(customerId: String) async -> (name: String, imageBase64: String) {
        guard !customerId.isEmpty else { return ("", "") }

        do {
            let document = try await db.collection("users").document(customerId).getDocument()
            let data = document.data() ?? [:]
            let name = (data["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let remoteImageBase64 = firstString(
                data["profileImageBase64"], data["avatarBase64"], data["photoBase64"]
            )
            let localImageBase64 = UserDefaults.standard.string(forKey: "profileAvatar_\(customerId)") ?? ""
            let imageBase64 = firstString(remoteImageBase64, localImageBase64)

            if remoteImageBase64.isEmpty && !imageBase64.isEmpty {
                try? await db.collection("users").document(customerId).setData([
                    "profileImageBase64": imageBase64,
                    "avatarBase64": imageBase64,
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
            }

            return (name, imageBase64)
        } catch {
            let localImageBase64 = UserDefaults.standard.string(forKey: "profileAvatar_\(customerId)") ?? ""
            return ("", localImageBase64)
        }
    }

    private func updateBakerReviewStats(artisanId: String) async {
        guard !artisanId.isEmpty else { return }

        do {
            let snapshot = try await db.collection("reviews")
                .whereField("bakerID", isEqualTo: artisanId)
                .getDocuments()

            let ratings = snapshot.documents.compactMap { $0.data()["rating"] as? Int }
            guard !ratings.isEmpty else { return }

            let average = Double(ratings.reduce(0, +)) / Double(ratings.count)
            let stats: [String: Any] = ["rating": average, "reviewCount": ratings.count]

            try await db.collection("artisans").document(artisanId).setData(stats, merge: true)
            try? await db.collection("users").document(artisanId).setData(stats, merge: true)
        } catch {
            print("Error updating baker review stats: \(error.localizedDescription)")
        }
    }

    private func firstString(_ values: Any?...) -> String {
        values.compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }
}
