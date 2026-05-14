import Foundation
import Combine
import FirebaseFirestore

// MARK: - BakerPaymentDetailsViewModel
/// Loads a baker's full payment history from Firestore with CoreData caching.
@MainActor
final class BakerPaymentDetailsViewModel: ObservableObject {
    @Published var payments: [BakerPaymentDetailsRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    var totalReceived: Double {
        payments.filter(\.isSuccess).reduce(0) { $0 + $1.amount }
    }

    var groupedByMonth: [(month: String, records: [BakerPaymentDetailsRecord])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        var grouped: [String: [BakerPaymentDetailsRecord]] = [:]

        for payment in payments {
            grouped[formatter.string(from: payment.paidAt), default: []].append(payment)
        }

        return grouped.keys
            .sorted { lhs, rhs in
                guard let lhsDate = grouped[lhs]?.first?.paidAt,
                      let rhsDate = grouped[rhs]?.first?.paidAt else { return lhs > rhs }
                return lhsDate > rhsDate
            }
            .map { month in (month: month, records: grouped[month] ?? []) }
    }

    func load(bakerID: String) async {
        let trimmedBakerID = bakerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBakerID.isEmpty else {
            payments = []
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let cachedPayments = CoreDataCacheService.shared.cachedBakerPayments(for: trimmedBakerID)
        if !cachedPayments.isEmpty {
            payments = cachedPayments
        }

        do {
            let paymentSnapshot = try await db.collection("payments")
                .whereField("bakerId", isEqualTo: trimmedBakerID)
                .getDocuments()
            let paymentDocuments = paymentSnapshot.documents

            var orderNames: [String: String] = [:]
            var orderCustomerNames: [String: String] = [:]
            var customerNames: [String: String] = [:]

            let orderIDs = Set(paymentDocuments.compactMap { firstString($0.data()["orderID"]) }.filter { !$0.isEmpty })
            for orderID in orderIDs {
                if let orderSnapshot = try? await db.collection("orders").document(orderID).getDocument(),
                   let orderData = orderSnapshot.data() {
                    orderNames[orderID] = firstString(orderData["cakeName"], orderData["title"], "Cake Order")
                    orderCustomerNames[orderID] = firstString(orderData["customerName"], orderData["customerFullName"])
                }
            }

            let customerIDs = Set(paymentDocuments.compactMap { firstString($0.data()["customerId"], $0.data()["customerID"]) }.filter { !$0.isEmpty })
            for customerID in customerIDs {
                if let userSnapshot = try? await db.collection("users").document(customerID).getDocument(),
                   let userData = userSnapshot.data() {
                    customerNames[customerID] = firstString(userData["name"], userData["fullName"], userData["email"])
                }
            }

            let loadedPayments = paymentDocuments.map { document in
                let data = document.data()
                let orderID = firstString(data["orderID"])
                let customerID = firstString(data["customerId"], data["customerID"])

                return BakerPaymentDetailsRecord(
                    id: document.documentID,
                    orderID: orderID,
                    customerID: customerID,
                    cakeName: firstString(data["cakeName"], orderNames[orderID], "Cake Order"),
                    customerName: firstString(data["customerName"], customerNames[customerID], orderCustomerNames[orderID], "Customer"),
                    amount: parseDouble(data["amount"]),
                    serviceFee: parseDouble(data["serviceFee"]),
                    total: parseDouble(data["total"]),
                    method: firstString(data["method"], "Card"),
                    cardLast4: firstString(data["cardLast4"]),
                    status: firstString(data["status"], "success"),
                    paidAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                )
            }
            .sorted { $0.paidAt > $1.paidAt }

            payments = loadedPayments
            CoreDataCacheService.shared.cacheBakerPayments(loadedPayments, for: trimmedBakerID)
        } catch {
            if payments.isEmpty {
                errorMessage = "Unable to load payment details."
            }
        }
    }

    // MARK: - Private Helpers

    private func firstString(_ values: Any?...) -> String {
        values.compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    private func parseDouble(_ value: Any?) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String {
            let cleaned = value.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(cleaned) ?? 0
        }
        return 0
    }
}
