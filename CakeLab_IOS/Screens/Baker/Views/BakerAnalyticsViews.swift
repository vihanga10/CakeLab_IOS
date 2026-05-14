import SwiftUI
import Charts

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
                        summaryCard
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
        .background(Color.cakeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
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
                Chart(Array(snapshot.categoryMix.enumerated()), id: \.element.id) { index, item in
                    SectorMark(
                        angle: .value("Orders", item.value),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(pastelChartColor(at: index))
                }
                .frame(height: 240)
                pastelLegend(for: snapshot.categoryMix)
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
        .background(Color.cakeInsetSurface)
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
        .background(Color.cakeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
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
                Chart(Array(snapshot.categoryEarnings.enumerated()), id: \.element.id) { index, item in
                    SectorMark(
                        angle: .value("Earnings", item.value),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(pastelChartColor(at: index))
                }
                .frame(height: 240)
                pastelLegend(for: snapshot.categoryEarnings)
            }
        }
    }

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
                    .foregroundStyle(pastelChartColor(at: index).gradient)
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
        .background(Color(red: 0.95, green: 0.98, blue: 0.95))
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
    .background(Color.cakeSurface)
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
    .background(Color.cakeInsetSurface)
    .clipShape(RoundedRectangle(cornerRadius: 18))
}

private let pastelChartPalette: [Color] = [
    Color(red: 0.98, green: 0.72, blue: 0.74),
    Color(red: 0.74, green: 0.86, blue: 1.00),
    Color(red: 0.78, green: 0.91, blue: 0.76),
    Color(red: 0.96, green: 0.84, blue: 0.60),
    Color(red: 0.82, green: 0.78, blue: 0.96),
    Color(red: 0.72, green: 0.91, blue: 0.90),
    Color(red: 0.96, green: 0.74, blue: 0.88)
]

private func pastelChartColor(at index: Int) -> Color {
    pastelChartPalette[index % pastelChartPalette.count]
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

