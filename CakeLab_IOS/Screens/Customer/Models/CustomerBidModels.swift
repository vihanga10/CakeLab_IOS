import Foundation

// MARK: - PaymentMethod
enum PaymentMethod: String, CaseIterable {
    case card = "Card"
    case cash = "Cash"
    case googlePay = "Google Pay"
    case applePay = "Apple Pay"
}

// MARK: - PaymentPayload
/// Payment details collected during bid acceptance checkout.
struct PaymentPayload {
    let method: PaymentMethod
    let cardholderName: String
    let cardLast4: String
    let deliveryAddress: String
    let deliveryCity: String
}

// MARK: - CustomerBidRequest
/// A cake request posted by the customer that has received baker bids.
struct CustomerBidRequest: Identifiable {
    let id: String
    let customerID: String
    let customerName: String
    let title: String
    let category: String
    let categories: [String]
    let location: String
    let customerAddress: String
    let budgetMin: Double
    let budgetMax: Double
    let expectedDate: Date
    let expectedTime: Date
    let bidCount: Int
    let createdAt: Date
    let description: String
    let styles: [String]
    let dietary: [String]
    let tier: Int
    let cakeSize: String
    let sugarLevel: Double
    let flavours: [String]
    let fillingFlavour: String
    let specialInstructions: String
    let allowNearby: Bool
    let status: String
    let isDirectRequest: Bool
    let targetArtisanID: String?
    let targetArtisanName: String?
    let referenceImages: [String]
}

// MARK: - CustomerBidOffer
/// A single baker bid offer on a customer's cake request.
struct CustomerBidOffer: Identifiable {
    let id: String
    let bakerID: String
    let bakerName: String
    let bakerProfileImageBase64: String
    let bakerImageURL: String
    let bakerAddress: String
    let bakerCity: String
    let amount: Double
    let message: String
    let canDeliverOnTime: Bool
    let deliveryDate: Date?
    let submittedAt: Date
    let status: String
}

// MARK: - BidsReceivedSheet
/// Navigation destination states for the bids received modal sheet.
enum BidsReceivedSheet: Identifiable {
    case payment(CustomerBidOffer)
    case bidDetails(CustomerBidOffer)

    var id: String {
        switch self {
        case .payment(let bid):    return "payment_\(bid.id)"
        case .bidDetails(let bid): return "details_\(bid.id)"
        }
    }
}
