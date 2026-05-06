import SwiftUI
import Charts
import FirebaseFirestore

struct BakerPerformanceAnalyticsView: View {
    let snapshot: BakerPerformanceSnapshot
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar(title: "Performance Charts")

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        summaryCard
                        monthlyOrdersCard
                        reviewTrendCard
                        categoryMixCard
                        ratingBreakdownCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How your bakery is performing")
                .font(.urbanistBold(18))
                .foregroundColor(Color(hex: "5D3714"))

            HStack(spacing: 12) {
                metricChip(title: "Completed Orders", value: "\(snapshot.completedOrders)")
                metricChip(title: "Avg Rating", value: snapshot.averageRatingText)
                metricChip(title: "Reviews", value: "\(snapshot.totalReviews)")
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(red: 0.99, green: 0.95, blue: 0.92), Color(red: 0.96, green: 0.92, blue: 0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var monthlyOrdersCard: some View {
        analyticsCard(title: "Completed Orders Trend", subtitle: "Last 6 months") {
            if snapshot.monthlyOrders.isEmpty {
                analyticsEmptyState(message: "No completed orders yet.")
            } else {
                Chart(snapshot.monthlyOrders) { item in
                    BarMark(
                        x: .value("Month", item.label),
                        y: .value("Orders", item.value)
                    )
                    .foregroundStyle(Color.cakeBrown.gradient)
                    .cornerRadius(6)
                }
                .frame(height: 220)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
    }

    private var reviewTrendCard: some View {
        analyticsCard(title: "Average Rating Trend", subtitle: "Monthly review score") {
            if snapshot.ratingTrend.isEmpty {
                analyticsEmptyState(message: "Ratings will appear after customers leave reviews.")
            } else {
                Chart(snapshot.ratingTrend) { item in
                    AreaMark(
                        x: .value("Month", item.label),
                        y: .value("Rating", item.value)
                    )
                    .foregroundStyle(Color(red: 0.96, green: 0.79, blue: 0.49).opacity(0.22))

                    LineMark(
                        x: .value("Month", item.label),
                        y: .value("Rating", item.value)
                    )
                    .foregroundStyle(Color(red: 0.87, green: 0.56, blue: 0.15))
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                    PointMark(
                        x: .value("Month", item.label),
                        y: .value("Rating", item.value)
                    )
                    .foregroundStyle(Color(red: 0.87, green: 0.56, blue: 0.15))
                }
                .frame(height: 220)
                .chartYScale(domain: 0...5)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
    }

    private var categoryMixCard: some View {
        analyticsCard(title: "Category Mix", subtitle: "Completed work by category") {
            if snapshot.categoryMix.isEmpty {
                analyticsEmptyState(message: "Order categories will appear here.")
            } else {
                Chart(snapshot.categoryMix) { item in
                    SectorMark(
                        angle: .value("Orders", item.value),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Category", item.label))
                }
                .frame(height: 240)
                .chartLegend(position: .bottom, spacing: 12)
            }
        }
    }

    private var ratingBreakdownCard: some View {
        analyticsCard(title: "Rating Breakdown", subtitle: "How customers scored your work") {
            if snapshot.ratingBreakdown.isEmpty {
                analyticsEmptyState(message: "No rating breakdown available yet.")
            } else {
                Chart(snapshot.ratingBreakdown) { item in
                    BarMark(
                        x: .value("Reviews", item.value),
                        y: .value("Stars", item.label)
                    )
                    .foregroundStyle(Color.cakeBrown.gradient)
                    .cornerRadius(6)
                }
                .frame(height: 220)
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
            }
        }
    }

    private func metricChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.urbanistRegular(11))
                .foregroundColor(.cakeGrey)
            Text(value)
                .font(.urbanistBold(18))
                .foregroundColor(Color(hex: "5D3714"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func headerBar(title: String) -> some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cakeBrown)
            }

            Spacer()

            Text(title)
                .font(.urbanistBold(18))
                .foregroundColor(Color(hex: "5D3714"))

            Spacer()

            Color.clear.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.white)
    }
}

struct BakerEarningsAnalyticsView: View {
    let snapshot: BakerEarningsSnapshot
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar(title: "Earnings Summary")

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        summaryCard
                        monthlyEarningsCard
                        categoryEarningsCard
                        paymentMethodsCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your earnings overview")
                .font(.urbanistBold(18))
                .foregroundColor(Color(hex: "5D3714"))

            HStack(spacing: 12) {
                metricChip(title: "This Month", value: snapshot.thisMonthFormatted)
                metricChip(title: "This Year", value: snapshot.thisYearFormatted)
            }

            HStack(spacing: 12) {
                metricChip(title: "Avg Order", value: snapshot.avgPerOrderFormatted)
                metricChip(title: "Best Month", value: snapshot.bestMonthLabel)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(red: 0.91, green: 0.97, blue: 0.91), Color(red: 0.84, green: 0.94, blue: 0.86)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var monthlyEarningsCard: some View {
        analyticsCard(title: "Monthly Earnings", subtitle: "Last 6 months") {
            if snapshot.monthlyEarnings.isEmpty {
                analyticsEmptyState(message: "No earnings data available yet.")
            } else {
                Chart(snapshot.monthlyEarnings) { item in
                    BarMark(
                        x: .value("Month", item.label),
                        y: .value("Earnings", item.value)
                    )
                    .foregroundStyle(Color(red: 0.20, green: 0.60, blue: 0.40).gradient)
                    .cornerRadius(6)
                }
                .frame(height: 220)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
    }

    private var categoryEarningsCard: some View {
        analyticsCard(title: "Earnings by Category", subtitle: "Where your revenue is coming from") {
            if snapshot.categoryEarnings.isEmpty {
                analyticsEmptyState(message: "Completed order categories will show here.")
            } else {
                Chart(snapshot.categoryEarnings) { item in
                    SectorMark(
                        angle: .value("Earnings", item.value),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Category", item.label))
                }
                .frame(height: 240)
                .chartLegend(position: .bottom, spacing: 12)
            }
        }
    }

    private var paymentMethodsCard: some View {
        analyticsCard(title: "Payment Methods", subtitle: "Successful payment mix") {
            if snapshot.paymentMethods.isEmpty {
                analyticsEmptyState(message: "Payment methods will appear after successful payments.")
            } else {
                Chart(snapshot.paymentMethods) { item in
                    BarMark(
                        x: .value("Amount", item.value),
                        y: .value("Method", item.label)
                    )
                    .foregroundStyle(Color(red: 0.25, green: 0.48, blue: 0.86).gradient)
                    .cornerRadius(6)
                }
                .frame(height: 220)
            }
        }
    }

    private func metricChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.urbanistRegular(11))
                .foregroundColor(.cakeGrey)
            Text(value)
                .font(.urbanistBold(16))
                .foregroundColor(Color(hex: "12471F"))
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func headerBar(title: String) -> some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cakeBrown)
            }

            Spacer()

            Text(title)
                .font(.urbanistBold(18))
                .foregroundColor(Color(hex: "5D3714"))

            Spacer()

            Color.clear.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.white)
    }
}

private func analyticsCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 14) {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.urbanistBold(16))
                .foregroundColor(Color(hex: "5D3714"))
            Text(subtitle)
                .font(.urbanistRegular(12))
                .foregroundColor(.cakeGrey)
        }

        content()
    }
    .padding(18)
    .background(Color.white)
    .clipShape(RoundedRectangle(cornerRadius: 20))
    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
}

private func analyticsEmptyState(message: String) -> some View {
    VStack(spacing: 12) {
        Image(systemName: "chart.bar.xaxis")
            .font(.system(size: 28))
            .foregroundColor(.cakeBrown.opacity(0.65))
        Text(message)
            .font(.urbanistRegular(12))
            .foregroundColor(.cakeGrey)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 180)
    .background(Color(red: 0.98, green: 0.96, blue: 0.94))
    .clipShape(RoundedRectangle(cornerRadius: 18))
}

struct BakerPerformanceSnapshot {
    let completedOrders: Int
    let totalReviews: Int
    let averageRating: Double
    let monthlyOrders: [AnalyticsChartPoint]
    let ratingTrend: [AnalyticsChartPoint]
    let categoryMix: [AnalyticsChartPoint]
    let ratingBreakdown: [AnalyticsChartPoint]

    var averageRatingText: String { String(format: "%.1f", averageRating) }

    static let empty = BakerPerformanceSnapshot(
        completedOrders: 0,
        totalReviews: 0,
        averageRating: 0,
        monthlyOrders: [],
        ratingTrend: [],
        categoryMix: [],
        ratingBreakdown: []
    )

    static func build(orders: [CakeOrder], reviews: [Review], now: Date = Date()) -> BakerPerformanceSnapshot {
        let monthlyOrders = buildLastSixMonths(referenceDate: now) { monthStart, nextMonth in
            orders.filter { $0.deliveryDate >= monthStart && $0.deliveryDate < nextMonth }.count
        }

        let ratingTrend = buildLastSixMonths(referenceDate: now) { monthStart, nextMonth in
            let monthReviews = reviews.filter { $0.createdAt >= monthStart && $0.createdAt < nextMonth }
            guard !monthReviews.isEmpty else { return nil }
            let avg = monthReviews.reduce(0.0) { $0 + Double($1.rating) } / Double(monthReviews.count)
            return avg
        }

        var categoryCounts: [String: Double] = [:]
        for order in orders {
            let raw = order.category.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = raw.isEmpty ? "Custom" : raw
            categoryCounts[key, default: 0] += 1
        }

        let categoryMix = categoryCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { AnalyticsChartPoint(label: $0.key, value: $0.value) }

        let ratingBreakdown = (1...5).reversed().map { stars in
            AnalyticsChartPoint(
                label: "\(stars)★",
                value: Double(reviews.filter { $0.rating == stars }.count)
            )
        }

        let averageRating = reviews.isEmpty ? 0 : reviews.reduce(0) { $0 + Double($1.rating) } / Double(reviews.count)

        return BakerPerformanceSnapshot(
            completedOrders: orders.count,
            totalReviews: reviews.count,
            averageRating: averageRating,
            monthlyOrders: monthlyOrders,
            ratingTrend: ratingTrend,
            categoryMix: categoryMix,
            ratingBreakdown: ratingBreakdown
        )
    }
}

struct BakerEarningsSnapshot {
    let totalEarningsThisMonth: Double
    let totalEarningsLastMonth: Double
    let totalEarningsThisYear: Double
    let avgPerOrder: Double
    let monthlyEarnings: [AnalyticsChartPoint]
    let categoryEarnings: [AnalyticsChartPoint]
    let paymentMethods: [AnalyticsChartPoint]
    let bestMonthLabel: String

    var thisMonthFormatted: String { Self.currency(totalEarningsThisMonth) }
    var lastMonthFormatted: String { Self.currency(totalEarningsLastMonth) }
    var thisYearFormatted: String { Self.currency(totalEarningsThisYear) }
    var avgPerOrderFormatted: String { Self.currency(avgPerOrder) }

    static let empty = BakerEarningsSnapshot(
        totalEarningsThisMonth: 0,
        totalEarningsLastMonth: 0,
        totalEarningsThisYear: 0,
        avgPerOrder: 0,
        monthlyEarnings: [],
        categoryEarnings: [],
        paymentMethods: [],
        bestMonthLabel: "No data"
    )

    static func build(orders: [CakeOrder], payments: [BakerPaymentRecord], now: Date = Date()) -> BakerEarningsSnapshot {
        let calendar = Calendar.current
        let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) ?? now
        let thisYearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now

        let revenueEntries = earningsEntries(orders: orders, payments: payments)
        let monthlyEarnings = buildLastSixMonths(referenceDate: now) { monthStart, nextMonth in
            revenueEntries
                .filter { $0.date >= monthStart && $0.date < nextMonth }
                .reduce(0) { $0 + $1.amount }
        }

        let totalThisMonth = revenueEntries
            .filter { $0.date >= thisMonthStart }
            .reduce(0) { $0 + $1.amount }

        let totalLastMonth = revenueEntries
            .filter { $0.date >= lastMonthStart && $0.date < thisMonthStart }
            .reduce(0) { $0 + $1.amount }

        let totalThisYear = revenueEntries
            .filter { $0.date >= thisYearStart }
            .reduce(0) { $0 + $1.amount }

        let avgPerOrder = revenueEntries.isEmpty ? 0 : revenueEntries.reduce(0) { $0 + $1.amount } / Double(revenueEntries.count)

        var categoryTotals: [String: Double] = [:]
        for entry in revenueEntries {
            categoryTotals[entry.category, default: 0] += entry.amount
        }
        let categoryEarnings = categoryTotals
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { AnalyticsChartPoint(label: $0.key, value: $0.value) }

        var paymentMethodTotals: [String: Double] = [:]
        for payment in payments where payment.isSuccess {
            paymentMethodTotals[payment.displayMethod, default: 0] += payment.amount
        }
        let paymentMethods = paymentMethodTotals
            .sorted { $0.value > $1.value }
            .map { AnalyticsChartPoint(label: $0.key, value: $0.value) }

        let bestMonthLabel = monthlyEarnings.max(by: { $0.value < $1.value })?.label ?? "No data"

        return BakerEarningsSnapshot(
            totalEarningsThisMonth: totalThisMonth,
            totalEarningsLastMonth: totalLastMonth,
            totalEarningsThisYear: totalThisYear,
            avgPerOrder: avgPerOrder,
            monthlyEarnings: monthlyEarnings,
            categoryEarnings: categoryEarnings,
            paymentMethods: paymentMethods,
            bestMonthLabel: bestMonthLabel
        )
    }

    private static func currency(_ value: Double) -> String {
        String(format: "LKR %.0f", value)
    }

    private static func earningsEntries(orders: [CakeOrder], payments: [BakerPaymentRecord]) -> [BakerEarningsEntry] {
        if !payments.isEmpty {
            let orderLookup = Dictionary(uniqueKeysWithValues: orders.map { ($0.id, $0) })
            return payments.compactMap { payment in
                guard payment.isSuccess else { return nil }
                let category = orderLookup[payment.orderID]?.category.trimmingCharacters(in: .whitespacesAndNewlines)
                return BakerEarningsEntry(
                    amount: payment.amount,
                    date: payment.createdAt,
                    category: category?.isEmpty == false ? category! : "Custom"
                )
            }
        }

        return orders.map { order in
            let category = order.category.trimmingCharacters(in: .whitespacesAndNewlines)
            return BakerEarningsEntry(
                amount: order.amount,
                date: order.deliveryDate,
                category: category.isEmpty ? "Custom" : category
            )
        }
    }
}

struct BakerPaymentRecord: Identifiable {
    let id: String
    let orderID: String
    let amount: Double
    let total: Double
    let method: String
    let status: String
    let createdAt: Date

    var isSuccess: Bool { status.lowercased() == "success" }

    var displayMethod: String {
        let lowered = method.lowercased()
        if lowered.contains("apple") { return "Apple Pay" }
        if lowered.contains("google") { return "Google Pay" }
        if lowered.contains("cash") { return "Cash" }
        if lowered.contains("card") { return "Card" }
        return method.isEmpty ? "Other" : method
    }
}

struct AnalyticsChartPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

private struct BakerEarningsEntry {
    let amount: Double
    let date: Date
    let category: String
}

private func buildLastSixMonths(referenceDate: Date, transform: (Date, Date) -> Int) -> [AnalyticsChartPoint] {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM"

    let monthStarts = lastSixMonthStarts(referenceDate: referenceDate)
    return monthStarts.map { monthStart in
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        return AnalyticsChartPoint(label: formatter.string(from: monthStart), value: Double(transform(monthStart, nextMonth)))
    }
}

private func buildLastSixMonths(referenceDate: Date, transform: (Date, Date) -> Double?) -> [AnalyticsChartPoint] {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM"

    let monthStarts = lastSixMonthStarts(referenceDate: referenceDate)
    return monthStarts.compactMap { monthStart in
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        guard let value = transform(monthStart, nextMonth) else { return nil }
        return AnalyticsChartPoint(label: formatter.string(from: monthStart), value: value)
    }
}

private func buildLastSixMonths(referenceDate: Date, transform: (Date, Date) -> Double) -> [AnalyticsChartPoint] {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM"

    let monthStarts = lastSixMonthStarts(referenceDate: referenceDate)
    return monthStarts.map { monthStart in
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        return AnalyticsChartPoint(label: formatter.string(from: monthStart), value: transform(monthStart, nextMonth))
    }
}

private func lastSixMonthStarts(referenceDate: Date) -> [Date] {
    let calendar = Calendar.current
    let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate)) ?? referenceDate
    return (-5...0).compactMap { offset in
        calendar.date(byAdding: .month, value: offset, to: currentMonthStart)
    }
}
