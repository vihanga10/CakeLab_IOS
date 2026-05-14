import FirebaseFirestore

enum CustomerRequestCollection {
    case published
    case draft

    var firestoreName: String {
        switch self {
        case .published:
            return "cakeRequests"
        case .draft:
            return "draftRequests"
        }
    }

    func includes(_ request: CakeRequestRecord) -> Bool {
        switch self {
        case .published:
            return request.status != "draft"
        case .draft:
            return true
        }
    }
}

struct CustomerRequestStore {
    private let db = Firestore.firestore()

    func fetchRequests(for userID: String, from collection: CustomerRequestCollection) async throws -> [CakeRequestRecord] {
        async let currentFieldSnapshot = db.collection(collection.firestoreName)
            .whereField("customerID", isEqualTo: userID)
            .getDocuments()
        async let legacyFieldSnapshot = db.collection(collection.firestoreName)
            .whereField("customerId", isEqualTo: userID)
            .getDocuments()

        let snapshots = try await [currentFieldSnapshot, legacyFieldSnapshot]
        var requestsByID: [String: CakeRequestRecord] = [:]

        for snapshot in snapshots {
            for document in snapshot.documents {
                guard let request = CakeRequestRecord(document: document) else {
                    continue
                }

                guard collection.includes(request), request.ownedBy(userID: userID) else {
                    continue
                }

                requestsByID[request.id] = request
            }
        }

        return requestsByID.values.sorted { $0.sortDate > $1.sortDate }
    }
}
