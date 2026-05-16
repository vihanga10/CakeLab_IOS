import SwiftUI
import Charts

// MARK: - Baker Performance Analytics View
struct BakerPerformanceAnalyticsView: View {
    let snapshot: BakerPerformanceSnapshot
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.cakeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar(title: "Performance Charts")

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // Performance cards and charts.
                        summaryCard
                        dailyOrdersCard
                        weeklyOrdersCard
                        monthlyOrdersCard
                        reviewTrendCard
                        categoryMixCard
                        ratingBreakdownCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 104)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .asBakerSubScreen()
    }

    // MARK: - Performance Summary Card
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How your bakery is performing")
                .font(.urbanistBold(16))
                .foregroundColor(Color(hex: "5D3714"))

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                metricChip(title: "Completed Orders", value: "\(snapshot.completedOrders)")
                metricChip(title: "Avg Rating", value: snapshot.averageRatingText)
                metricChip(title: "Reviews", value: "\(snapshot.totalReviews)")
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    // MARK: - Completed Orders Per Day Chart
    private var dailyOrdersCard: some View {
        analyticsCard(title: "Completed Orders Per Day", subtitle: "Last 7 days") {
            if snapshot.dailyOrders.allSatisfy({ $0.value == 0 }) {
                analyticsEmptyState(message: "Daily completed orders will appear here.")
            } else {
                Chart(snapshot.dailyOrders) { item in
                    BarMark(
                        x: .value("Day", item.label),
                        y: .value("Orders", item.value)
                    )
                    .foregroundStyle(performanceDailyChartColor)
                    .cornerRadius(6)
                }
                .frame(height: 220)
                .chartPlotStyle { plotArea in
                    plotArea.background(Color.white)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
    }

    // MARK: - Completed Orders Per Week Chart
    private var weeklyOrdersCard: some View {
        analyticsCard(title: "Completed Orders Per Week", subtitle: "Last 8 weeks") {
            if snapshot.weeklyOrders.allSatisfy({ $0.value == 0 }) {
                analyticsEmptyState(message: "Weekly completed orders will appear here.")
            } else {
                Chart(snapshot.weeklyOrders) { item in
                    BarMark(
                        x: .value("Week", item.label),
                        y: .value("Orders", item.value)
                    )
                    .foregroundStyle(performanceWeeklyChartColor)
                    .cornerRadius(6)
                }
                .frame(height: 220)
                .chartPlotStyle { plotArea in
                    plotArea.background(Color.white)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
    }

    // MARK: - Completed Orders Trend Chart
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
                    .foregroundStyle(performanceMonthlyChartColor)
                    .cornerRadius(6)
                }
                .frame(height: 220)
                .chartPlotStyle { plotArea in
                    plotArea.background(Color.white)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
    }

    // MARK: - Average Rating Trend Chart
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
                    .foregroundStyle(performanceRatingFillColor)

                    LineMark(
                        x: .value("Month", item.label),
                        y: .value("Rating", item.value)
                    )
                    .foregroundStyle(performanceRatingLineColor)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                    PointMark(
                        x: .value("Month", item.label),
                        y: .value("Rating", item.value)
                    )
                    .foregroundStyle(performanceRatingLineColor)
                }
                .frame(height: 220)
                .chartPlotStyle { plotArea in
                    plotArea.background(Color.white)
                }
                .chartYScale(domain: 0...5)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
    }

    // MARK: - Category Mix Chart
    private var categoryMixCard: some View {
        analyticsCard(title: "Category Mix", subtitle: "Completed work by category") {
            if snapshot.categoryMix.isEmpty {
                analyticsEmptyState(message: "Order categories will appear here.")
            } else {
                Chart(Array(snapshot.categoryMix.enumerated()), id: \.element.id) { index, item in
                    SectorMark(
                        angle: .value("Orders", item.value),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(pastelChartColor(at: index))
                }
                .frame(height: 240)
                .chartPlotStyle { plotArea in
                    plotArea.background(Color.white)
                }
                pastelLegend(for: snapshot.categoryMix)
            }
        }
    }

    // MARK: - Rating Breakdown Card
    private var ratingBreakdownCard: some View {
        analyticsCard(title: "Rating Breakdown", subtitle: "How customers scored your work") {
            if snapshot.ratingBreakdown.isEmpty || ratingBreakdownTotal == 0 {
                analyticsEmptyState(message: "No rating breakdown available yet.")
            } else {
                ratingBreakdownDistribution
            }
        }
    }

    private var ratingBreakdownDistribution: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(spacing: 10) {
                ForEach(sortedRatingBreakdown) { item in
                    ratingBreakdownRow(
                        star: ratingNumber(from: item.label),
                        value: item.value,
                        maxValue: maxRatingBreakdownValue
                    )
                }
            }

            VStack(spacing: 8) {
                Text(snapshot.averageRatingText)
                    .font(.urbanistBold(46))
                    .foregroundColor(Color(hex: "5D3714"))
                    .minimumScaleFactor(0.8)

                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: "star.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(index <= Int(snapshot.averageRating.rounded()) ? performanceRatingBreakdownColor : Color(hex: "C8C4C1"))
                    }
                }

                Text("(\(Int(ratingBreakdownTotal)))")
                    .font(.urbanistSemiBold(13))
                    .foregroundColor(.cakeGrey)
            }
            .frame(width: 88)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }

    private func ratingBreakdownRow(star: Int, value: Double, maxValue: Double) -> some View {
        HStack(spacing: 10) {
            Text("\(star)")
                .font(.urbanistSemiBold(14))
                .foregroundColor(.cakeGrey)
                .frame(width: 16, alignment: .trailing)

            GeometryReader { proxy in
                let ratio = maxValue == 0 ? 0 : value / maxValue
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: "C8C4C1").opacity(0.45))
                    Capsule()
                        .fill(performanceRatingBreakdownColor)
                        .frame(width: value <= 0 ? 0 : max(8, proxy.size.width * ratio))
                }
            }
            .frame(height: 10)
        }
        .frame(height: 20)
    }

    private var sortedRatingBreakdown: [AnalyticsChartPoint] {
        snapshot.ratingBreakdown.sorted {
            ratingNumber(from: $0.label) > ratingNumber(from: $1.label)
        }
    }

    private var ratingBreakdownTotal: Double {
        snapshot.ratingBreakdown.reduce(0) { $0 + $1.value }
    }

    private var maxRatingBreakdownValue: Double {
        max(snapshot.ratingBreakdown.map(\.value).max() ?? 0, 1)
    }

    private func ratingNumber(from label: String) -> Int {
        Int(label.filter(\.isNumber)) ?? 0
    }

    private func metricChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.urbanistRegular(11))
                .foregroundColor(.cakeGrey)
            Text(value)
                .font(.urbanistBold(17))
                .foregroundColor(Color(hex: "5D3714"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 58)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(performanceMetricChipBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
        .background(Color.cakeSurface)
    }
}

// MARK: - Baker Earnings Analytics View
struct BakerEarningsAnalyticsView: View {
    let snapshot: BakerEarningsSnapshot
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.cakeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar(title: "Earnings Summary")

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // Earnings summary and breakdown charts.
                        summaryCard
                        monthlyEarningsCard
                        categoryEarningsCard
                        paymentMethodsCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 104)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .asBakerSubScreen()
    }

    // MARK: - Earnings Summary Card
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your earnings overview")
                .font(.urbanistBold(16))
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
        .background(Color.cakeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    // MARK: - Monthly Earnings Chart
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
                    .foregroundStyle(earningsMonthlyChartColor)
                    .cornerRadius(6)
                }
                .frame(height: 220)
                .chartPlotStyle { plotArea in
                    plotArea.background(Color.white)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
    }

    // MARK: - Earnings by Category Chart
    private var categoryEarningsCard: some View {
        analyticsCard(title: "Earnings by Category", subtitle: "Where your revenue is coming from") {
            if snapshot.categoryEarnings.isEmpty {
                analyticsEmptyState(message: "Completed order categories will show here.")
            } else {
                Chart(Array(snapshot.categoryEarnings.enumerated()), id: \.element.id) { index, item in
                    SectorMark(
                        angle: .value("Earnings", item.value),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(pastelChartColor(at: index))
                }
                .frame(height: 240)
                .chartPlotStyle { plotArea in
                    plotArea.background(Color.white)
                }
                pastelLegend(for: snapshot.categoryEarnings)
            }
        }
    }

    // MARK: - Payment Methods Chart
    private var paymentMethodsCard: some View {
        analyticsCard(title: "Payment Methods", subtitle: "Successful payment mix") {
            if snapshot.paymentMethods.isEmpty {
                analyticsEmptyState(message: "Payment methods will appear after successful payments.")
            } else {
                Chart(Array(snapshot.paymentMethods.enumerated()), id: \.element.id) { index, item in
                    BarMark(
                        x: .value("Amount", item.value),
                        y: .value("Method", item.label)
                    )
                    .foregroundStyle(paymentMethodChartColor(at: index))
                    .cornerRadius(6)
                }
                .frame(height: 220)
                .chartPlotStyle { plotArea in
                    plotArea.background(Color.white)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let method = value.as(String.self) {
                                Text(method)
                                    .font(.urbanistSemiBold(11))
                                    .foregroundColor(.cakeGrey)
                            }
                        }
                    }
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
                .font(.urbanistBold(16))
                .foregroundColor(Color(hex: "5D3714"))
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(hex: "F8F6F3"))
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
        .background(Color.cakeSurface)
    }
}

// MARK: - Shared Analytics Card
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
    .background(Color.white)
    .clipShape(RoundedRectangle(cornerRadius: 18))
}

private let pastelChartPalette: [Color] = [
    Color(hex: "7D6148"),
    Color(hex: "A0826B"),
    Color(hex: "C2A18E"),
    Color(hex: "D9B8A3"),
    Color(hex: "C8C4C1"),
    Color(hex: "B49B87"),
    Color(hex: "E8D6C8")
]

private let performanceDailyChartColor = Color(hex: "7D6148")
private let performanceWeeklyChartColor = Color(hex: "C8C4C1")
private let performanceMonthlyChartColor = Color(red: 0.72, green: 0.60, blue: 0.50)
private let performanceRatingFillColor = Color(red: 0.94, green: 0.82, blue: 0.74)
private let performanceRatingLineColor = Color(red: 0.70, green: 0.48, blue: 0.43)
private let performanceRatingBreakdownColor = Color(red: 0.78, green: 0.67, blue: 0.58)
private let performanceMetricChipBackground = Color(hex: "F8F6F3")
private let earningsMonthlyChartColor = Color(hex: "76604B")
private let paymentMethodChartPalette: [Color] = [
    Color(red: 0.74, green: 0.55, blue: 0.47),
    Color(hex: "564638"),
    Color(red: 0.73, green: 0.66, blue: 0.57),
    Color(red: 0.88, green: 0.80, blue: 0.70),
    Color(hex: "ac9889"),
    Color(red: 0.80, green: 0.62, blue: 0.52)
]

private func pastelChartColor(at index: Int) -> Color {
    pastelChartPalette[index % pastelChartPalette.count]
}

private func paymentMethodChartColor(at index: Int) -> Color {
    paymentMethodChartPalette[index % paymentMethodChartPalette.count]
}

private func pastelLegend(for items: [AnalyticsChartPoint]) -> some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], alignment: .leading, spacing: 8) {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            HStack(spacing: 6) {
                Circle()
                    .fill(pastelChartColor(at: index))
                    .frame(width: 9, height: 9)
                Text(item.label)
                    .font(.urbanistRegular(11))
                    .foregroundColor(.cakeGrey)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
    .padding(.top, 2)
}
