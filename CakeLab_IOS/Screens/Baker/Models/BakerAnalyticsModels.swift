import Foundation

// MARK: - Baker PerformanceSnapshot

struct BakerPerformanceSnapshot {
    let completedOrders: Int
    let totalReviews: Int
    let averageRating: Double
    let dailyOrders: [AnalyticsChartPoint]
    let weeklyOrders: [AnalyticsChartPoint]
    let monthlyOrders: [AnalyticsChartPoint]
    let ratingTrend: [AnalyticsChartPoint]
    let categoryMix: [AnalyticsChartPoint]
    let ratingBreakdown: [AnalyticsChartPoint]

    var averageRatingText: String { String(format: "%.1f", averageRating) }

    static let empty = BakerPerformanceSnapshot(
        completedOrders: 0,
        totalReviews: 0,
        averageRating: 0,
        dailyOrders: [],
        weeklyOrders: [],
        monthlyOrders: [],
        ratingTrend: [],
        categoryMix: [],
        ratingBreakdown: []
    )

    static func build(orders: [CakeOrder], reviews: [Review], now: Date = Date()) -> BakerPerformanceSnapshot {
        let dailyOrders = buildLastSevenDays(referenceDate: now) { dayStart, nextDay in
            orders.filter { $0.deliveryDate >= dayStart && $0.deliveryDate < nextDay }.count
        }

        let weeklyOrders = buildLastEightWeeks(referenceDate: now) { weekStart, nextWeek in
            orders.filter { $0.deliveryDate >= weekStart && $0.deliveryDate < nextWeek }.count
        }

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
            dailyOrders: dailyOrders,
            weeklyOrders: weeklyOrders,
            monthlyOrders: monthlyOrders,
            ratingTrend: ratingTrend,
            categoryMix: categoryMix,
            ratingBreakdown: ratingBreakdown
        )
    }
}

// MARK: - Baker Earnings Snapshot

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
}

// MARK: - Baker Payment Record

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

// MARK: - Analytics Chart Point

struct AnalyticsChartPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

// MARK: - Baker Earnings Entry (internal)
private struct BakerEarningsEntry {
    let amount: Double
    let date: Date
    let category: String
}

// MARK: - Date Range Helpers
func buildLastSixMonths(referenceDate: Date, transform: (Date, Date) -> Int) -> [AnalyticsChartPoint] {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM"

    let monthStarts = lastSixMonthStarts(referenceDate: referenceDate)
    return monthStarts.map { monthStart in
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        return AnalyticsChartPoint(label: formatter.string(from: monthStart), value: Double(transform(monthStart, nextMonth)))
    }
}

func buildLastSixMonths(referenceDate: Date, transform: (Date, Date) -> Double?) -> [AnalyticsChartPoint] {
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

func buildLastSixMonths(referenceDate: Date, transform: (Date, Date) -> Double) -> [AnalyticsChartPoint] {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM"

    let monthStarts = lastSixMonthStarts(referenceDate: referenceDate)
    return monthStarts.map { monthStart in
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        return AnalyticsChartPoint(label: formatter.string(from: monthStart), value: transform(monthStart, nextMonth))
    }
}

func lastSixMonthStarts(referenceDate: Date) -> [Date] {
    let calendar = Calendar.current
    let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate)) ?? referenceDate
    return (-5...0).compactMap { offset in
        calendar.date(byAdding: .month, value: offset, to: currentMonthStart)
    }
}

func buildLastSevenDays(referenceDate: Date, transform: (Date, Date) -> Int) -> [AnalyticsChartPoint] {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE"

    let todayStart = calendar.startOfDay(for: referenceDate)
    return (-6...0).compactMap { offset in
        guard let dayStart = calendar.date(byAdding: .day, value: offset, to: todayStart),
              let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }
        return AnalyticsChartPoint(label: formatter.string(from: dayStart), value: Double(transform(dayStart, nextDay)))
    }
}

func buildLastEightWeeks(referenceDate: Date, transform: (Date, Date) -> Int) -> [AnalyticsChartPoint] {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"

    let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start
        ?? calendar.startOfDay(for: referenceDate)

    return (-7...0).compactMap { offset in
        guard let weekStart = calendar.date(byAdding: .weekOfYear, value: offset, to: currentWeekStart),
              let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else {
            return nil
        }
        return AnalyticsChartPoint(label: formatter.string(from: weekStart), value: Double(transform(weekStart, nextWeek)))
    }
}
