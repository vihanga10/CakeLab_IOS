import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class BakerBidHistoryViewModel: ObservableObject {
    @Published var items: [BakerBidHistoryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    func loadBidHistory(bakerID: String) async {
        let trimmedBakerID = bakerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBakerID.isEmpty else {
            items = []
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let bidSnapshot = try await db.collection("bids")
                .whereField("bakerID", isEqualTo: trimmedBakerID)
                .getDocuments()

            let requestIDs = Set(
                bidSnapshot.documents.compactMap { document in
                    document.data()["requestDocumentID"] as? String
                }
            )
            let bidIDs = Set(bidSnapshot.documents.map(\.documentID))
            let customerIDs = Set(
                bidSnapshot.documents.compactMap { document in
                    firstString(document.data()["customerID"], document.data()["customerId"])
                }.filter { !$0.isEmpty }
            )
            let openRequests = await loadAccessibleRequests(requestIDs: requestIDs)
            let directRequests = await loadDirectRequestDocuments(requestIDs: requestIDs)
            let accessibleRequests = openRequests.merging(directRequests) { current, direct in
                current.enriched(with: direct)
            }
            let accessibleOrders = await loadAccessibleOrders(
                bakerID: trimmedBakerID,
                requestIDs: requestIDs,
                bidIDs: bidIDs
            )
            let customerNames = await loadCustomerNames(customerIDs: customerIDs)
            var loadedItems: [BakerBidHistoryItem] = []

            for bidDocument in bidSnapshot.documents {
                let bidData = bidDocument.data()
                guard let bid = BakerBidHistoryBid(document: bidDocument) else { continue }
                let snapshotRequest = BakerBidHistoryRequest(bidData: bidData, bid: bid)
                let orderRequest = accessibleOrders[bid.requestDocumentID] ?? accessibleOrders[bid.id]
                let request = (accessibleRequests[bid.requestDocumentID] ?? snapshotRequest)
                    .enriched(
                        with: orderRequest,
                        customerNameOverride: customerNames[bid.customerID]
                    )
                loadedItems.append(BakerBidHistoryItem(bid: bid, request: request))
            }

            items = loadedItems.sorted { $0.bid.submittedAt > $1.bid.submittedAt }
        } catch {
            errorMessage = error.localizedDescription
            items = []
        }

        isLoading = false
    }

    private func loadAccessibleRequests(requestIDs: Set<String>) async -> [String: BakerBidHistoryRequest] {
        guard !requestIDs.isEmpty else { return [:] }

        var result: [String: BakerBidHistoryRequest] = [:]
        let statuses = ["open"]

        for status in statuses {
            do {
                let snapshot = try await db.collection("cakeRequests")
                    .whereField("status", isEqualTo: status)
                    .getDocuments()

                for document in snapshot.documents {
                    guard requestIDs.contains(document.documentID),
                          let record = CakeRequestRecord(document: document) else { continue }
                    result[document.documentID] = BakerBidHistoryRequest(record: record)
                }
            } catch {
                print("Bid history could not load \(status) request records: \(error.localizedDescription)")
            }
        }

        return result
    }

    private func loadDirectRequestDocuments(requestIDs: Set<String>) async -> [String: BakerBidHistoryRequest] {
        guard !requestIDs.isEmpty else { return [:] }

        var result: [String: BakerBidHistoryRequest] = [:]
        for requestID in requestIDs {
            do {
                let snapshot = try await db.collection("cakeRequests").document(requestID).getDocument()
                guard let record = CakeRequestRecord(document: snapshot) else { continue }
                result[requestID] = BakerBidHistoryRequest(record: record)
            } catch {
                print("Bid history could not load request \(requestID): \(error.localizedDescription)")
            }
        }

        return result
    }

    private func loadAccessibleOrders(
        bakerID: String,
        requestIDs: Set<String>,
        bidIDs: Set<String>
    ) async -> [String: BakerBidHistoryRequest] {
        guard !requestIDs.isEmpty || !bidIDs.isEmpty else { return [:] }

        var result: [String: BakerBidHistoryRequest] = [:]
        var seenOrderIDs: Set<String> = []

        for key in ["bakerID", "bakerId", "artisanId"] {
            do {
                let snapshot = try await db.collection("orders")
                    .whereField(key, isEqualTo: bakerID)
                    .getDocuments()

                for document in snapshot.documents where !seenOrderIDs.contains(document.documentID) {
                    let data = document.data()
                    let requestID = firstString(data["requestDocumentID"], data["cakeRequestID"], data["requestID"])
                    let bidID = firstString(data["bidID"], data["acceptedBidID"])
                    let matchesRequest = (!requestID.isEmpty && requestIDs.contains(requestID))
                        || requestIDs.contains { document.documentID.hasPrefix("\($0)_") }
                    let matchesBid = (!bidID.isEmpty && bidIDs.contains(bidID))
                        || bidIDs.contains(document.documentID)

                    guard matchesRequest || matchesBid else { continue }

                    let request = BakerBidHistoryRequest(orderID: document.documentID, orderData: data)
                    if !requestID.isEmpty {
                        result[requestID] = request
                    }
                    if !bidID.isEmpty {
                        result[bidID] = request
                    }
                    result[document.documentID] = request
                    seenOrderIDs.insert(document.documentID)
                }
            } catch {
                print("Bid history could not load completed orders for \(key): \(error.localizedDescription)")
            }
        }

        return result
    }

    private func loadCustomerNames(customerIDs: Set<String>) async -> [String: String] {
        guard !customerIDs.isEmpty else { return [:] }

        var result: [String: String] = [:]
        for customerID in customerIDs {
            do {
                let snapshot = try await db.collection("users").document(customerID).getDocument()
                let data = snapshot.data() ?? [:]
                let name = firstString(data["name"], data["fullName"], data["email"])
                if !name.isEmpty {
                    result[customerID] = name
                }
            } catch {
                print("Bid history could not load customer \(customerID): \(error.localizedDescription)")
            }
        }
        return result
    }

    private func firstString(_ values: Any?...) -> String {
        values.compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }
}
