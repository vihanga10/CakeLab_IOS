import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

extension Notification.Name {
    static let bidDidChange = Notification.Name("bidDidChange")
}


@MainActor
final class BakerBidDetailViewModel: ObservableObject {
    @Published var isSubmittingBid = false
    @Published var bidSubmitted = false
    @Published var submissionError: String?

    private let db = Firestore.firestore()

    func submitBid(
        request: CakeRequest,
        bidAmount: String,
        parsedAmount: Double,
        bidMessage: String,
        deliveryNote: String,
        canDeliverOnTime: Bool,
        alternativeDate: Date,
        notificationManager: NotificationManager,
        onSuccess: @escaping () -> Void
    ) async {
        guard let bakerID = Auth.auth().currentUser?.uid else {
            submissionError = "You need to be signed in as a baker before submitting a bid."
            return
        }

        guard parsedAmount > 0 else {
            submissionError = "Enter a valid bid amount. You can use digits with spaces or commas."
            return
        }

        guard !request.requestDocumentID.isEmpty else {
            submissionError = "This request is missing its document ID, so the bid cannot be saved."
            return
        }

        isSubmittingBid = true

        let bidDocumentID = "\(request.requestDocumentID)_\(bakerID)"
        let bidRef = db.collection("bids").document(bidDocumentID)
        let requestRef = db.collection("cakeRequests").document(request.requestDocumentID)

        do {
            let bakerProfile = try await db.collection("users").document(bakerID).getDocument()
            let bakerData = bakerProfile.data() ?? [:]
            let artisanProfile = try? await db.collection("artisans").document(bakerID).getDocument()
            let artisanData = artisanProfile?.data() ?? [:]
            let bidSnapshot = try await bidRef.getDocument()
            let alreadyExists = bidSnapshot.exists

            let bakerName = (bakerData["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let bakerProfileImageBase64 = artisanData["profileImageBase64"] as? String ?? bakerData["profileImageBase64"] as? String ?? ""
            let bakerImageURL = artisanData["imageURL"] as? String ?? bakerData["imageURL"] as? String ?? bakerData["avatarURL"] as? String ?? ""
            let bakerAddress = artisanData["address"] as? String ?? artisanData["location"] as? String ?? bakerData["address"] as? String ?? ""
            let bakerCity = SriLankaDistricts.canonical(artisanData["city"] as? String)
                ?? SriLankaDistricts.canonical(bakerData["city"] as? String)
                ?? artisanData["city"] as? String
                ?? bakerData["city"] as? String ?? ""

            let bidPayload: [String: Any] = [
                "requestDocumentID": request.requestDocumentID,
                "customerID": request.customerID,
                "bakerID": bakerID,
                "bakerName": bakerName.isEmpty ? (Auth.auth().currentUser?.email ?? "Baker") : bakerName,
                "bakerProfileImageBase64": bakerProfileImageBase64,
                "bakerImageURL": bakerImageURL,
                "bakerAddress": bakerAddress,
                "bakerCity": bakerCity,
                "requestTitle": request.title,
                "requestSnapshot": [
                    "id": request.requestDocumentID,
                    "title": request.title,
                    "description": request.description,
                    "customerName": request.customerName,
                    "customerCity": request.location,
                    "category": request.category.name,
                    "budgetText": request.budgetRange,
                    "expectedDateText": request.deliveryDate,
                    "expectedTimeText": request.deliveryTime,
                    "tier": request.servings,
                    "cakeSize": request.cakeSize,
                    "sugarLevel": request.sugarLevel,
                    "flavours": request.flavours,
                    "styles": request.styles,
                    "dietary": request.dietary,
                    "fillingFlavour": request.fillingFlavour,
                    "specialInstructions": request.specialInstructions,
                    "referenceImages": request.referenceImages
                ],
                "amount": parsedAmount,
                "message": bidMessage,
                "deliveryNote": deliveryNote,
                "canDeliverOnTime": canDeliverOnTime,
                "alternativeDate": canDeliverOnTime ? NSNull() : Timestamp(date: alternativeDate),
                "submittedAt": Timestamp(date: Date()),
                "status": "submitted"
            ]

            try await bidRef.setData(bidPayload, merge: true)

            if !alreadyExists {
                try await db.runTransaction { transaction, _ in
                    let snapshot = try? transaction.getDocument(requestRef)
                    let currentCount = snapshot?.data()?["bidCount"] as? Int ?? 0
                    transaction.updateData(["bidCount": currentCount + 1], forDocument: requestRef)
                    return nil
                }
            }

            let displayName = bakerName.isEmpty ? (Auth.auth().currentUser?.email ?? "Baker") : bakerName

            notificationManager.notifyNewBidReceived(
                bakerName: displayName,
                bidAmount: parsedAmount,
                requestTitle: request.title,
                bakerID: bakerID,
                orderID: request.requestDocumentID,
                customerID: request.customerID,
                showPopup: false
            )

            notificationManager.notifyBakerBidSubmitted(
                requestTitle: request.title,
                bidAmount: parsedAmount,
                customerID: request.customerID,
                bakerID: bakerID,
                orderID: request.requestDocumentID
            )

            bidSubmitted = true
            isSubmittingBid = false
            NotificationCenter.default.post(name: .bidDidChange, object: nil)
            onSuccess()
        } catch {
            isSubmittingBid = false
            submissionError = error.localizedDescription
            print("Error submitting bid: \(error)")
        }
    }
}
