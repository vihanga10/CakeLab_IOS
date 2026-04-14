import SwiftUI
import Combine
import FirebaseFirestore

// MARK: - Payment Record Model
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
    var maskedCard: String { cardLast4.isEmpty ? "" : "•••• \(cardLast4)" }
}

// MARK: - Payment History ViewModel
@MainActor
final class PaymentHistoryViewModel: ObservableObject {
    @Published var payments: [PaymentRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    var totalSpent: Double {
        payments.filter(\.isSuccess).reduce(0) { $0 + $1.total }
    }

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

// MARK: - Payment History View
struct PaymentHistoryView: View {
    let user: AppUser
    @StateObject private var vm = PaymentHistoryViewModel()
    @Environment(\.dismiss) private var dismiss

    private static let currencyFmt: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    private static let cardDateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.97, blue: 0.97).ignoresSafeArea()

            if vm.isLoading {
                ProgressView("Loading payments...")
                    .tint(.cakeBrown)
            } else if vm.payments.isEmpty && vm.errorMessage == nil {
                emptyState
            } else if let error = vm.errorMessage {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange.opacity(0.7))
                    Text(error)
                        .font(.urbanistRegular(14))
                        .foregroundColor(.cakeGrey)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Button("Retry") {
                        Task { await vm.load(customerID: user.id) }
                    }
                    .font(.urbanistSemiBold(14))
                    .foregroundColor(.cakeBrown)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 20, pinnedViews: []) {
                        summaryCard
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        ForEach(vm.groupedByMonth, id: \.month) { section in
                            VStack(alignment: .leading, spacing: 12) {
                                // Month header
                                HStack(spacing: 10) {
                                    Text(section.month.uppercased())
                                        .font(.urbanistSemiBold(11))
                                        .foregroundColor(.cakeGrey)
                                        .tracking(1)
                                    Rectangle()
                                        .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
                                        .frame(height: 1)
                                }
                                .padding(.horizontal, 16)

                                ForEach(section.records) { record in
                                    PaymentRecordCard(
                                        record: record,
                                        dateFmt: Self.cardDateFmt,
                                        currencyFmt: Self.currencyFmt
                                    )
                                    .padding(.horizontal, 16)
                                }
                            }
                        }

                        Spacer().frame(height: 32)
                    }
                }
                .refreshable {
                    await vm.load(customerID: user.id)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.urbanistSemiBold(15))
                    }
                    .foregroundColor(.cakeBrown)
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Payment History")
                    .font(.urbanistBold(18))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            }
        }
        .task {
            await vm.load(customerID: user.id)
        }
    }

    // MARK: - Summary Card
    private var summaryCard: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 93/255, green: 55/255, blue: 20/255),
                    Color(red: 148/255, green: 98/255, blue: 58/255)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(22)

            VStack(alignment: .leading, spacing: 18) {
                // Top row: total + icon
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Total Spent")
                            .font(.urbanistRegular(13))
                            .foregroundColor(.white.opacity(0.72))
                        Text("LKR \(Self.currencyFmt.string(for: vm.totalSpent) ?? "0.00")")
                            .font(.urbanistBold(30))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.18))
                            .frame(width: 58, height: 58)
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: 1)

                // Stats row
                HStack(spacing: 28) {
                    summaryStatView(
                        icon: "checkmark.circle.fill",
                        value: "\(vm.payments.filter(\.isSuccess).count)",
                        label: "Successful"
                    )
                    summaryStatView(
                        icon: "cart.fill",
                        value: "\(vm.payments.count)",
                        label: "Orders"
                    )
                    Spacer()
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
        }
        .shadow(
            color: Color(red: 93/255, green: 55/255, blue: 20/255).opacity(0.32),
            radius: 16, x: 0, y: 7
        )
    }

    private func summaryStatView(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.80))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.urbanistBold(16))
                    .foregroundColor(.white)
                Text(label)
                    .font(.urbanistRegular(11))
                    .foregroundColor(.white.opacity(0.68))
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                    .frame(width: 96, height: 96)
                Image(systemName: "creditcard")
                    .font(.system(size: 38))
                    .foregroundColor(.cakeBrown.opacity(0.55))
            }
            Text("No Payments Yet")
                .font(.urbanistBold(19))
                .foregroundColor(Color(red: 0.18, green: 0.18, blue: 0.18))
            Text("Your payment history will appear here\nonce you complete a cake order.")
                .font(.urbanistRegular(14))
                .foregroundColor(.cakeGrey)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.horizontal, 44)
    }
}

// MARK: - Payment Record Card
struct PaymentRecordCard: View {
    let record: PaymentRecord
    let dateFmt: DateFormatter
    let currencyFmt: NumberFormatter

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(alignment: .top, spacing: 14) {
                // Method icon
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(
                            record.isApplePay
                            ? Color.black.opacity(0.07)
                            : Color(red: 0.92, green: 0.90, blue: 0.87)
                        )
                        .frame(width: 54, height: 54)
                    Image(systemName: record.isApplePay ? "apple.logo" : "creditcard.fill")
                        .font(.system(size: record.isApplePay ? 22 : 20))
                        .foregroundColor(record.isApplePay ? .black : .cakeBrown)
                }

                // Details
                VStack(alignment: .leading, spacing: 5) {
                    Text(record.cakeName)
                        .font(.urbanistBold(15))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .lineLimit(1)

                    Text("Baker: \(record.bakerName)")
                        .font(.urbanistRegular(13))
                        .foregroundColor(Color(red: 0.42, green: 0.42, blue: 0.42))

                    HStack(spacing: 6) {
                        if record.isApplePay {
                            HStack(spacing: 4) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 10))
                                Text("Apple Pay")
                                    .font(.urbanistSemiBold(11))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.08))
                            .clipShape(Capsule())
                        } else if !record.maskedCard.isEmpty {
                            Text(record.maskedCard)
                                .font(.urbanistSemiBold(11))
                                .foregroundColor(Color(red: 93/255, green: 55/255, blue: 20/255))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(red: 0.92, green: 0.88, blue: 0.83))
                                .clipShape(Capsule())
                        }

                        Text(dateFmt.string(from: record.paidAt))
                            .font(.urbanistRegular(11))
                            .foregroundColor(.cakeGrey)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                // Amount + Status
                VStack(alignment: .trailing, spacing: 6) {
                    Text("LKR \(currencyFmt.string(for: record.total) ?? "0")")
                        .font(.urbanistBold(15))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                    Text(record.isSuccess ? "Paid" : record.status.capitalized)
                        .font(.urbanistSemiBold(11))
                        .foregroundColor(
                            record.isSuccess
                            ? Color(red: 0.10, green: 0.58, blue: 0.35)
                            : .orange
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            record.isSuccess
                            ? Color(red: 0.10, green: 0.58, blue: 0.35).opacity(0.11)
                            : Color.orange.opacity(0.11)
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Cost breakdown row
            Rectangle()
                .fill(Color(red: 0.92, green: 0.92, blue: 0.92))
                .frame(height: 1)
                .padding(.horizontal, 16)

            HStack {
                breakdownItem(
                    label: "Bid Amount",
                    value: "LKR \(Int(record.amount).formatted())"
                )
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.75))
                Spacer()
                breakdownItem(
                    label: "Service Fee",
                    value: "LKR \(Int(record.serviceFee).formatted())"
                )
                Spacer()
                Image(systemName: "equal")
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.75))
                Spacer()
                breakdownItem(
                    label: "Total",
                    value: "LKR \(Int(record.total).formatted())",
                    highlight: true
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.055), radius: 10, x: 0, y: 3)
    }

    private func breakdownItem(label: String, value: String, highlight: Bool = false) -> some View {
        VStack(alignment: .center, spacing: 3) {
            Text(value)
                .font(highlight ? .urbanistBold(12) : .urbanistSemiBold(12))
                .foregroundColor(
                    highlight
                    ? Color(red: 93/255, green: 55/255, blue: 20/255)
                    : Color(red: 0.22, green: 0.22, blue: 0.22)
                )
            Text(label)
                .font(.urbanistRegular(10))
                .foregroundColor(.cakeGrey)
        }
    }
}

#Preview {
    NavigationStack {
        PaymentHistoryView(user: AppUser.mock)
    }
}
