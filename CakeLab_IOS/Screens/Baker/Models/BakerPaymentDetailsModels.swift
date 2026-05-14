import Foundation

// MARK: - Baker Payment Details Record

struct BakerPaymentDetailsRecord: Identifiable {
    let id: String
    let orderID: String
    let customerID: String
    let cakeName: String
    let customerName: String
    let amount: Double
    let serviceFee: Double
    let total: Double
    let method: String
    let cardLast4: String
    let status: String
    let paidAt: Date

    var isSuccess: Bool { status.lowercased() == "success" }
    var isApplePay: Bool { method.lowercased().contains("apple") }
    var isGooglePay: Bool { method.lowercased().contains("google") }
    var isCash: Bool { method.lowercased().contains("cash") }
    var isCard: Bool { method.lowercased().contains("card") && !isApplePay && !isGooglePay }
}
