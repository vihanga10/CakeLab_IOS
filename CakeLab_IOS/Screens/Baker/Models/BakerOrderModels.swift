import SwiftUI

// MARK: - Baker Order 

struct BakerOrderFull: Identifiable {
    let id = UUID()
    let cakeName: String
    let customerName: String
    let deliveryDate: String
    let location: String
    let status: String
    let amount: String
    let progressPercent: Int
    let currentStep: Int
    let notes: String
    var rating: Int = 5

    var statusColor: Color {
        switch status {
        case "baking":       return Color.orange
        case "decorating":   return Color(red: 0.3, green: 0.45, blue: 0.8)
        case "ready":        return Color.green
        case "confirmed":    return Color.cakeBrown
        default:             return Color.cakeGrey
        }
    }

    var statusLabel: String {
        switch status {
        case "baking":       return "Baking"
        case "decorating":   return "Decorating"
        case "ready":        return "Ready to Collect"
        case "confirmed":    return "Confirmed"
        default:             return status.capitalized
        }
    }
}

// MARK: - Baker Order Customer Profile

struct BakerOrderCustomerProfile {
    let name: String
    let address: String
    let city: String
    let profileImageBase64: String
    let imageURL: String

    static func fallback(for order: CakeOrder) -> BakerOrderCustomerProfile {
        BakerOrderCustomerProfile(
            name: order.customerId.isEmpty ? "Customer" : order.customerId,
            address: "",
            city: "",
            profileImageBase64: "",
            imageURL: ""
        )
    }

    var displayLocation: String {
        let location = SriLankaDistricts.displayLocation(address: address, city: city)
        return location.isEmpty ? "Delivery address not provided" : location
    }
}
