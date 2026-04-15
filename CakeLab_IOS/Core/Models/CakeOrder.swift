import SwiftUI
import FirebaseFirestore

// MARK: - CakeOrder  (Firestore-backed)
//
// Firestore collection: "orders"
// Document fields:
//   customerId    : String        — Firebase UID of the customer who placed the order
//   artisanId     : String        — Firebase UID of the baker/artisan
//   cakeName      : String        — display name of the ordered cake
//   status        : String        — one of: "pending" | "confirmed" | "baking" |
//                                           "decorating" | "quality_check" |
//                                           "delivered" | "cancelled"
//   currentStep   : Int           — progress step 1–5
//   deliveryDate  : Timestamp     — expected delivery date
//   artisanName   : String        — baker's shop / display name
//   artisanRating : String        — e.g. "5.0 (41 reviews)"
//   artisanAddress: String        — baker's address
//   imageURL      : String?       — optional Firebase Storage URL for cake image
//   createdAt     : Timestamp     — when the order was created

struct CakeOrder: Identifiable, Sendable {
    let id: String
    let customerId: String
    let artisanId: String
    let cakeName: String
    let status: String
    let currentStep: Int
    let deliveryDate: Date
    let deliveryTime: Date?
    let deliveryDateTime: Date?
    let artisanName: String
    let artisanRating: String
    let artisanAddress: String
    let imageURL: String?

    // Resolved from status string
    var statusColor: Color {
        switch status {
        case "confirmed":     return Color(red: 0.15, green: 0.72, blue: 0.25)
        case "baking":        return Color(red: 0.95, green: 0.70, blue: 0.10)
        case "decorating":    return Color(red: 1.0,  green: 0.55, blue: 0.10)
        case "quality_check": return Color(red: 0.2,  green: 0.5,  blue: 1.0)
        default:              return .gray
        }
    }

    var statusLabel: String {
        switch status {
        case "confirmed":     return "Confirmed"
        case "baking":        return "Baking"
        case "decorating":    return "Decorating"
        case "quality_check": return "Quality Check"
        case "delivered":     return "Delivered"
        case "cancelled":     return "Cancelled"
        default:              return status.capitalized
        }
    }

    var formattedDeliveryDate: String {
        let f = DateFormatter()
        f.dateFormat = "dd/ MM/ yyyy"
        return f.string(from: deliveryDate)
    }

    // MARK: - Init from Firestore DocumentSnapshot
    init?(document: DocumentSnapshot) {
        guard
            let data          = document.data(),
            let customerId    = data["customerId"]    as? String,
            let cakeName      = data["cakeName"]      as? String,
            let status        = data["status"]        as? String,
            let currentStep   = data["currentStep"]   as? Int,
            let ts            = data["deliveryDate"]  as? Timestamp,
            let artisanName   = data["artisanName"]   as? String,
            let artisanRating = data["artisanRating"] as? String,
            let artisanAddress = data["artisanAddress"] as? String
        else { return nil }

        self.id             = document.documentID
        self.customerId     = customerId
        self.artisanId      = data["artisanId"] as? String ?? ""
        self.cakeName       = cakeName
        self.status         = status
        self.currentStep    = currentStep
        self.deliveryDate   = ts.dateValue()
        self.deliveryTime   = (data["deliveryTime"] as? Timestamp)?.dateValue()
        self.deliveryDateTime = (data["deliveryDateTime"] as? Timestamp)?.dateValue()
        self.artisanName    = artisanName
        self.artisanRating  = artisanRating
        self.artisanAddress = artisanAddress
        self.imageURL       = data["imageURL"] as? String
    }
}
