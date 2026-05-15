import Foundation

// MARK: - OrderStatusBakerProfile
/// Baker profile data displayed on the customer's order status screen.
struct OrderStatusBakerProfile {
    let name: String
    let ratingText: String
    let reviewCount: Int
    let address: String
    let city: String
    let phone: String
    let profileImageBase64: String
    let imageURL: String

    static let empty = OrderStatusBakerProfile(
        name: "", ratingText: "", reviewCount: 0,
        address: "", city: "", phone: "", profileImageBase64: "", imageURL: ""
    )
}
