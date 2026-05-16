import SwiftUI

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
            Color(red: 1.0, green: 1.0, blue: 1.0).ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                if vm.isLoading {
                    // Loading state while payment records are fetched.
                    ProgressView("Loading payments...")
                        .tint(.cakeBrown)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.payments.isEmpty && vm.errorMessage == nil {
                    // Empty state when the customer has no payments yet.
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = vm.errorMessage {
                    // Error state with retry action.
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Payment history grouped by month.
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
        }
        .navigationBarBackButtonHidden(true)
        .task {
            // Load customer payment history.
            await vm.load(customerID: user.id)
        }
        .asCustomerSubScreen()
    }

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cakeBrown)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("Payment History")
                    .font(.urbanistBold(18))
                    .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
            }
            Spacer()
            Color.clear.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.cakeSurface)
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
                .foregroundColor(.cakePrimaryText)
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
    @State private var selectedReceipt: PDFReceiptData?

    var body: some View {
        VStack(spacing: 0) {
            // Main payment row with method, cake, baker, amount, and status.
            HStack(alignment: .top, spacing: 14) {
                // Payment method icon.
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(paymentMethodBackgroundColor())
                        .frame(width: 54, height: 54)
                    Image(systemName: paymentMethodIcon())
                        .font(.system(size: paymentMethodIconSize()))
                        .foregroundColor(paymentMethodIconColor())
                }

                // Cake and baker details.
                VStack(alignment: .leading, spacing: 5) {
                    Text(record.cakeName)
                        .font(.urbanistBold(15))
                        .foregroundColor(.cakePrimaryText)
                        .lineLimit(1)

                    Text("Baker: \(record.bakerName)")
                        .font(.urbanistRegular(13))
                        .foregroundColor(Color(red: 0.42, green: 0.42, blue: 0.42))

                    // Payment method badge.
                    paymentMethodBadge()
                }

                Spacer(minLength: 4)

                // Amount, status, and paid date.
                VStack(alignment: .trailing, spacing: 6) {
                    Text("LKR \(currencyFmt.string(for: record.total) ?? "0")")
                        .font(.urbanistBold(15))
                        .foregroundColor(.cakePrimaryText)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(record.isSuccess ? "Paid" : record.status.capitalized)
                            .font(.urbanistSemiBold(11))
                            .foregroundColor(
                                record.isSuccess
                                ? Color(red: 0.10, green: 0.58, blue: 0.35)
                                : .orange
                            )
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                record.isSuccess
                                ? Color(red: 0.10, green: 0.58, blue: 0.35).opacity(0.11)
                                : Color.orange.opacity(0.11)
                            )
                            .clipShape(Capsule())

                        Text(dateFmt.string(from: record.paidAt))
                            .font(.urbanistRegular(10))
                            .foregroundColor(.cakeGrey)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Cost breakdown row.
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
        .background(Color.cakeSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.055), radius: 10, x: 0, y: 3)
        .contextMenu {
            Button {
                // Opens generated PDF receipt.
                selectedReceipt = receiptData
            } label: {
                Label("View PDF Receipt", systemImage: "doc.richtext")
            }
        }
        .sheet(item: $selectedReceipt) { receipt in
            // PDF receipt preview sheet.
            PDFReceiptPreviewView(receipt: receipt)
        }
    }

    private var receiptData: PDFReceiptData {
        PDFReceiptData(
            id: record.id,
            title: "Payment Receipt",
            receiptNumber: record.id,
            cakeName: record.cakeName,
            payerLabel: "Customer",
            payerName: record.cardholderName.isEmpty ? "Customer" : record.cardholderName,
            receiverLabel: "Baker",
            receiverName: record.bakerName,
            paymentMethod: paymentMethodText,
            status: record.status,
            paidAt: record.paidAt,
            subtotalLabel: "Bid Amount",
            subtotal: record.amount,
            serviceFee: record.serviceFee,
            totalLabel: "Total Paid",
            total: record.total
        )
    }

    private var paymentMethodText: String {
        if record.isApplePay { return "Apple Pay" }
        if record.isGooglePay { return "Google Pay" }
        if record.isCash { return "Cash" }
        if record.cardLast4.isEmpty { return record.method.isEmpty ? "Card" : record.method }
        return "\(record.method) \(record.maskedCard)"
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

    // MARK: - Payment Method Helpers
    private func paymentMethodIcon() -> String {
        if record.isApplePay {
            return "apple.logo"
        } else if record.isGooglePay {
            return "g.circle.fill"
        } else if record.isCash {
            return "banknote.fill"
        } else {
            return "creditcard.fill"
        }
    }

    private func paymentMethodIconSize() -> CGFloat {
        record.isApplePay ? 22 : 20
    }

    private func paymentMethodIconColor() -> Color {
        if record.isApplePay {
            return .black
        } else if record.isGooglePay {
            return Color(red: 0.2, green: 0.5, blue: 0.95)
        } else if record.isCash {
            return Color(red: 0.2, green: 0.65, blue: 0.2)
        } else {
            return .cakeBrown
        }
    }

    private func paymentMethodBackgroundColor() -> Color {
        if record.isApplePay {
            return Color.black.opacity(0.07)
        } else if record.isGooglePay {
            return Color(red: 0.2, green: 0.5, blue: 0.95).opacity(0.1)
        } else if record.isCash {
            return Color(red: 0.2, green: 0.65, blue: 0.2).opacity(0.1)
        } else {
            return Color(red: 0.92, green: 0.90, blue: 0.87)
        }
    }

    @ViewBuilder
    private func paymentMethodBadge() -> some View {
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
        } else if record.isGooglePay {
            HStack(spacing: 4) {
                Image(systemName: "g.circle.fill")
                    .font(.system(size: 10))
                Text("Google Pay")
                    .font(.urbanistSemiBold(11))
            }
            .foregroundColor(Color(red: 0.2, green: 0.5, blue: 0.95))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(red: 0.2, green: 0.5, blue: 0.95).opacity(0.1))
            .clipShape(Capsule())
        } else if record.isCash {
            HStack(spacing: 4) {
                Image(systemName: "banknote.fill")
                    .font(.system(size: 10))
                Text("Cash")
                    .font(.urbanistSemiBold(11))
            }
            .foregroundColor(Color(red: 0.2, green: 0.65, blue: 0.2))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(red: 0.2, green: 0.65, blue: 0.2).opacity(0.1))
            .clipShape(Capsule())
        } else {
            HStack(spacing: 4) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 10))
                Text(fullCardNumber(record.cardLast4))
                    .font(.urbanistSemiBold(11))
            }
            .foregroundColor(Color(red: 93/255, green: 55/255, blue: 20/255))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(red: 0.92, green: 0.88, blue: 0.83))
            .clipShape(Capsule())
        }
    }

    private func fullCardNumber(_ last4: String) -> String {
        if last4.isEmpty {
            return "•••• •••• •••• ••••"
        }
        return "•••• •••• •••• \(last4)"
    }
}

#Preview {
    NavigationStack {
        PaymentHistoryView(user: AppUser.mock)
    }
}
