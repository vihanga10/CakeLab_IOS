import Foundation
import Combine
import FirebaseFirestore


// Loads customer payment history from Firestore.
@MainActor
final class PaymentHistoryViewModel: ObservableObject {
    @Published var payments: [PaymentRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    // Sum of all successful payment totals for this customer.
    var totalSpent: Double {
        payments.filter(\.isSuccess).reduce(0) { $0 + $1.total }
    }

    // Payment records grouped and sorted by calendar month (most recent first).
    var groupedByMonth: [(month: String, records: [PaymentRecord])] {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        var dict: [String: [PaymentRecord]] = [:]
        for p in payments {
            let key = fmt.string(from: p.paidAt)
            dict[key, default: []].append(p)
        }
        return dict.keys
            .sorted { a, b in
                let da = dict[a]!.first!.paidAt
                let db_ = dict[b]!.first!.paidAt
                return da > db_
            }
            .map { key in (month: key, records: dict[key]!) }
    }

    func load(customerID: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let payFetch = db.collection("payments")
                .whereField("customerId", isEqualTo: customerID)
                .getDocuments()
            async let orderFetch = db.collection("orders")
                .whereField("customerId", isEqualTo: customerID)
                .getDocuments()

            let (paySnap, orderSnap) = try await (payFetch, orderFetch)

            var orderNames: [String: String] = [:]
            for doc in orderSnap.documents {
                orderNames[doc.documentID] = doc.data()["cakeName"] as? String ?? "Cake Order"
            }

            payments = paySnap.documents.compactMap { doc -> PaymentRecord? in
                let d = doc.data()
                let paidAt = (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let orderID = d["orderID"] as? String ?? ""

                func toDouble(_ v: Any?) -> Double {
                    if let x = v as? Double { return x }
                    if let x = v as? Int { return Double(x) }
                    return 0
                }

                return PaymentRecord(
                    id: doc.documentID,
                    orderID: orderID,
                    cakeName: orderNames[orderID] ?? "Cake Order",
                    bakerName: d["bakerName"] as? String ?? "Baker",
                    amount: toDouble(d["amount"]),
                    serviceFee: toDouble(d["serviceFee"]),
                    total: toDouble(d["total"]),
                    method: d["method"] as? String ?? "Card",
                    cardholderName: d["cardholderName"] as? String ?? "",
                    cardLast4: d["cardLast4"] as? String ?? "",
                    status: d["status"] as? String ?? "success",
                    paidAt: paidAt
                )
            }
            .sorted { $0.paidAt > $1.paidAt }
        } catch {
            errorMessage = "Unable to load payment history."
        }
    }
}
