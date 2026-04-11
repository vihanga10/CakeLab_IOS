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
    
    init?(document: DocumentSnapshot) {
        guard
            let data = document.data(),
            let bakerID = data["bakerID"] as? String,
            let customerID = data["customerID"] as? String,
            let customerName = data["customerName"] as? String,
            let rating = data["rating"] as? Int,
            let comment = data["comment"] as? String,
            let ts = data["createdAt"] as? Timestamp
        else { return nil }
        
        self.id = document.documentID
        self.bakerID = bakerID
        self.customerID = customerID
        self.customerName = customerName
        self.customerImage = data["customerImage"] as? String
        self.rating = rating
        self.comment = comment
        self.createdAt = ts.dateValue()
    }
}
