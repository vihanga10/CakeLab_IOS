import SwiftUI
import FirebaseFirestore

struct Review: Identifiable, Sendable {
    let id: String
    let bakerID: String
    let customerID: String
    let customerName: String
    let customerImage: String?
    let rating: Int  // 1-5
    let comment: String
    let createdAt: Date
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: createdAt)
    }

    init(
        id: String,
        bakerID: String,
        customerID: String,
        customerName: String,
        customerImage: String?,
        rating: Int,
        comment: String,
        createdAt: Date
    ) {
        self.id = id
        self.bakerID = bakerID
        self.customerID = customerID
        self.customerName = customerName
        self.customerImage = customerImage
        self.rating = rating
        self.comment = comment
        self.createdAt = createdAt
    }
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        let bakerID = Self.firstString(data["bakerID"], data["bakerId"], data["artisanId"])
        let customerID = Self.firstString(data["customerID"], data["customerId"])
        let customerName = Self.firstString(data["customerName"], data["customerFullName"], data["customerEmail"], "Customer")
        let comment = Self.firstString(data["comment"], data["reviewText"])
        let rating = Self.intValue(data["rating"])
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        guard !bakerID.isEmpty, !customerID.isEmpty, rating > 0 else { return nil }
        
        self.id = document.documentID
        self.bakerID = bakerID
        self.customerID = customerID
        self.customerName = customerName
        self.customerImage = Self.firstString(data["customerImage"], data["customerImageURL"], data["customerProfileImageBase64"], data["customerAvatarURL"])
        self.rating = rating
        self.comment = comment
        self.createdAt = createdAt
    }

    private static func firstString(_ values: Any?...) -> String {
        values.compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    private static func intValue(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0 }
        return 0
    }
}
