import Foundation
import Combine
import FirebaseFirestore

extension Notification.Name {
    static let orderDidChange = Notification.Name("orderDidChange")
}

// MARK: - CustomerBidsViewModel
/// Loads the customer's published cake requests that have received baker bids.
@MainActor
final class CustomerBidsViewModel: ObservableObject {
    @Published var requests: [CustomerBidRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    func loadRequests(customerID: String) async {
        isLoading = true
        errorMessage = nil

        do {
            async let primary = db.collection("cakeRequests")
                .whereField("customerID", isEqualTo: customerID).getDocuments()
            async let legacy = db.collection("cakeRequests")
                .whereField("customerId", isEqualTo: customerID).getDocuments()

            let (primarySnap, legacySnap) = try await (primary, legacy)
            var mergedDocs: [String: DocumentSnapshot] = [:]
            for document in primarySnap.documents { mergedDocs[document.documentID] = document }
            for document in legacySnap.documents { mergedDocs[document.documentID] = document }

            let parsed = mergedDocs.values
                .compactMap(Self.parseRequest)
                .filter { !Self.isClosedRequestStatus($0.status) }
            requests = parsed.sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = "Failed to load requests with bids. \(error.localizedDescription)"
        }

        isLoading = false
    }

    private static func parseRequest(document: DocumentSnapshot) -> CustomerBidRequest? {
        guard let data = document.data() else { return nil }
        let expectedDate = parseDate(data["expectedDate"]) ?? Date()
        let expectedTime = parseDate(data["expectedTime"]) ?? expectedDate
        let createdAt = parseDate(data["createdAt"]) ?? Date()

        return CustomerBidRequest(
            id: document.documentID,
            customerID: (data["customerID"] as? String) ?? (data["customerId"] as? String) ?? "",
            customerName: data["customerName"] as? String ?? "Customer",
            title: data["title"] as? String ?? "Cake Request",
            category: data["category"] as? String ?? "Custom Cake",
            categories: data["categories"] as? [String] ?? [],
            location: data["customerCity"] as? String ?? data["customerAddress"] as? String ?? "Customer Location",
            customerAddress: data["customerAddress"] as? String ?? "",
            budgetMin: parseDouble(data["budgetMin"]), budgetMax: parseDouble(data["budgetMax"]),
            expectedDate: expectedDate, expectedTime: expectedTime,
            bidCount: parseInt(data["bidCount"]), createdAt: createdAt,
            description: data["description"] as? String ?? "",
            styles: data["styles"] as? [String] ?? [],
            dietary: data["dietary"] as? [String] ?? [],
            tier: parseInt(data["tier"]),
            cakeSize: data["cakeSize"] as? String ?? "",
            sugarLevel: parseDouble(data["sugarLevel"]),
            flavours: data["flavours"] as? [String] ?? [],
            fillingFlavour: data["fillingFlavour"] as? String ?? "",
            specialInstructions: data["specialInstructions"] as? String ?? "",
            allowNearby: data["allowNearby"] as? Bool ?? false,
            status: data["status"] as? String ?? "open",
            isDirectRequest: data["isDirectRequest"] as? Bool ?? false,
            targetArtisanID: data["targetArtisanId"] as? String,
            targetArtisanName: data["targetArtisanName"] as? String,
            referenceImages: data["referenceImages"] as? [String] ?? []
        )
    }

    private static func isClosedRequestStatus(_ status: String) -> Bool {
        let normalized = status.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized == "confirmed" || normalized == "paid" ||
               normalized == "completed" || normalized == "in_progress"
    }

    private static func parseDate(_ raw: Any?) -> Date? {
        if let ts = raw as? Timestamp { return ts.dateValue() }
        if let seconds = raw as? TimeInterval { return Date(timeIntervalSince1970: seconds) }
        if let intSeconds = raw as? Int { return Date(timeIntervalSince1970: TimeInterval(intSeconds)) }
        return nil
    }

    private static func parseDouble(_ raw: Any?) -> Double {
        if let value = raw as? Double { return value }
        if let value = raw as? Int { return Double(value) }
        if let value = raw as? String { return Double(value) ?? 0 }
        return 0
    }

    private static func parseInt(_ raw: Any?) -> Int {
        if let value = raw as? Int { return value }
        if let value = raw as? Double { return Int(value) }
        if let value = raw as? String { return Int(value) ?? 0 }
        return 0
    }
}

// MARK: - BidsReceivedViewModel
/// Loads baker bids for a specific customer cake request.
@MainActor
final class BidsReceivedViewModel: ObservableObject {
    @Published var bids: [CustomerBidOffer] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    func loadBids(requestID: String, customerID: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await db.collection("bids")
                .whereField("customerID", isEqualTo: customerID)
                .getDocuments()

            let parsed = snapshot.documents
                .filter { $0.data()["requestDocumentID"] as? String == requestID }
                .compactMap(Self.parseBid)

            var enrichedBids: [CustomerBidOffer] = []
            for bid in parsed where !Self.isClosedBidStatus(bid.status) {
                enrichedBids.append(await enrichBidWithBakerProfile(bid))
            }

            bids = enrichedBids.sorted { $0.submittedAt > $1.submittedAt }
        } catch {
            errorMessage = "Failed to load bids. \(error.localizedDescription)"
        }

        isLoading = false
    }

    private static func parseBid(document: DocumentSnapshot) -> CustomerBidOffer? {
        guard let data = document.data() else { return nil }
        let submittedAt = parseDate(data["submittedAt"]) ?? Date()
        let canDeliverOnTime = data["canDeliverOnTime"] as? Bool ?? true

        return CustomerBidOffer(
            id: document.documentID,
            bakerID: data["bakerID"] as? String ?? "",
            bakerName: data["bakerName"] as? String ?? "Baker",
            bakerProfileImageBase64: data["bakerProfileImageBase64"] as? String ?? "",
            bakerImageURL: data["bakerImageURL"] as? String ?? "",
            bakerAddress: data["bakerAddress"] as? String ?? "",
            bakerCity: data["bakerCity"] as? String ?? "",
            amount: parseDouble(data["amount"]),
            message: data["message"] as? String ?? "",
            canDeliverOnTime: canDeliverOnTime,
            deliveryDate: canDeliverOnTime ? nil : parseDate(data["alternativeDate"]),
            submittedAt: submittedAt,
            status: data["status"] as? String ?? "submitted"
        )
    }

    private static func isClosedBidStatus(_ status: String) -> Bool {
        let normalized = status.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized == "accepted" || normalized == "paid" || normalized == "confirmed"
    }

    private func enrichBidWithBakerProfile(_ bid: CustomerBidOffer) async -> CustomerBidOffer {
        guard bid.bakerProfileImageBase64.isEmpty && bid.bakerImageURL.isEmpty else { return bid }
        let profileData = await fetchBakerProfileImageData(bakerID: bid.bakerID)
        return CustomerBidOffer(
            id: bid.id, bakerID: bid.bakerID, bakerName: bid.bakerName,
            bakerProfileImageBase64: profileData.base64, bakerImageURL: profileData.url,
            bakerAddress: profileData.address, bakerCity: profileData.city,
            amount: bid.amount, message: bid.message,
            canDeliverOnTime: bid.canDeliverOnTime, deliveryDate: bid.deliveryDate,
            submittedAt: bid.submittedAt, status: bid.status
        )
    }

    private func fetchBakerProfileImageData(bakerID: String) async -> (base64: String, url: String, address: String, city: String) {
        let trimmedID = bakerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return ("", "", "", "") }

        if let artisanDoc = try? await db.collection("artisans").document(trimmedID).getDocument(),
           let data = artisanDoc.data() {
            let base64 = data["profileImageBase64"] as? String ?? ""
            let url = data["imageURL"] as? String ?? data["avatarURL"] as? String ?? ""
            let address = data["address"] as? String ?? data["location"] as? String ?? ""
            let city = SriLankaDistricts.canonical(data["city"] as? String) ?? data["city"] as? String ?? ""
            if !base64.isEmpty || !url.isEmpty || !address.isEmpty || !city.isEmpty {
                return (base64, url, address, city)
            }
        }

        if let userDoc = try? await db.collection("users").document(trimmedID).getDocument(),
           let data = userDoc.data() {
            return (
                data["profileImageBase64"] as? String ?? "",
                data["imageURL"] as? String ?? data["avatarURL"] as? String ?? "",
                data["address"] as? String ?? "",
                SriLankaDistricts.canonical(data["city"] as? String) ?? data["city"] as? String ?? ""
            )
        }

        return ("", "", "", "")
    }

    private static func parseDate(_ raw: Any?) -> Date? {
        if let ts = raw as? Timestamp { return ts.dateValue() }
        if let seconds = raw as? TimeInterval { return Date(timeIntervalSince1970: seconds) }
        if let intSeconds = raw as? Int { return Date(timeIntervalSince1970: TimeInterval(intSeconds)) }
        return nil
    }

    private static func parseDouble(_ raw: Any?) -> Double {
        if let value = raw as? Double { return value }
        if let value = raw as? Int { return Double(value) }
        if let value = raw as? NSNumber { return value.doubleValue }
        if let value = raw as? String { return Double(value) ?? 0 }
        return 0
    }
}
