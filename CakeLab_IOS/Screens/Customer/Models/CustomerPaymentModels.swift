import Foundation

// MARK: - PaymentRecord
/// A single customer payment record used in the payment history screen.
struct PaymentRecord: Identifiable {
    let id: String
    let orderID: String
    let cakeName: String
    let bakerName: String
    let amount: Double
    let serviceFee: Double
    let total: Double
    let method: String
    let cardholderName: String
    let cardLast4: String
    let status: String
    let paidAt: Date

    var isSuccess: Bool { status == "success" }
    var isApplePay: Bool { method.lowercased().contains("apple") }
    var isGooglePay: Bool { method.lowercased().contains("google") }
    var isCash: Bool { method.lowercased().contains("cash") }
    var isCard: Bool { method.lowercased().contains("card") && !isApplePay && !isGooglePay }
    var maskedCard: String { cardLast4.isEmpty ? "" : "•••• \(cardLast4)" }
}
