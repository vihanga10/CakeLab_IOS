import WidgetKit
import SwiftUI

private enum SharedKeys {
    static let appGroupID = "group.com.vihanga.CakeLab-IOS"
    static let snapshotKey = "widget.snapshot.v1"
}

private enum SnapshotRole: String, Codable {
    case customer
    case baker
    case unknown
}

private struct SnapshotOrder: Codable {
    let id: String
    let cakeName: String
    let status: String
    let currentStep: Int
    let deliveryDate: Date
    let counterpartName: String
}

private struct SnapshotMatchingRequest: Codable {
    let id: String
    let title: String
    let category: String
    let expectedDate: Date
    let bidCount: Int
    let budgetMin: Double
    let budgetMax: Double
}

private struct SnapshotPayload: Codable {
    let isLoggedIn: Bool
    let role: SnapshotRole
    let userID: String
    let updatedAt: Date
    let customerNearestOrder: SnapshotOrder?
    let customerActiveOrders: [SnapshotOrder]
    let bakerNearestOrder: SnapshotOrder?
    let bakerLatestMatchingRequest: SnapshotMatchingRequest?

    static var fallback: SnapshotPayload {
        SnapshotPayload(
            isLoggedIn: false,
            role: .unknown,
            userID: "",
            updatedAt: Date(),
            customerNearestOrder: nil,
            customerActiveOrders: [],
            bakerNearestOrder: nil,
            bakerLatestMatchingRequest: nil
        )
    }
}

private struct CakeLabWidgetEntry: TimelineEntry {
    let date: Date
    let payload: SnapshotPayload
}

private struct CakeLabWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CakeLabWidgetEntry {
        CakeLabWidgetEntry(date: Date(), payload: .fallback)
    }

    func getSnapshot(in context: Context, completion: @escaping (CakeLabWidgetEntry) -> Void) {
        completion(CakeLabWidgetEntry(date: Date(), payload: loadPayload()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CakeLabWidgetEntry>) -> Void) {
        let entry = CakeLabWidgetEntry(date: Date(), payload: loadPayload())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadPayload() -> SnapshotPayload {
        guard let defaults = UserDefaults(suiteName: SharedKeys.appGroupID) else {
            return .fallback
        }

        guard let data = defaults.data(forKey: SharedKeys.snapshotKey) else {
            return .fallback
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(SnapshotPayload.self, from: data)) ?? .fallback
    }
}

@main
struct CakeLabWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CustomerNearestOrderWidget()
        CustomerActiveOrdersListWidget()
        BakerNearestOrderWidget()
        BakerLatestMatchingWidget()
    }
}

struct CustomerNearestOrderWidget: Widget {
    private let kind = "com.vihanga.cakelab.widget.customer.nearest-order"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CakeLabWidgetProvider()) { entry in
            CustomerNearestOrderWidgetView(entry: entry)
        }
        .configurationDisplayName("Customer Delivery Step")
        .description("Shows your nearest active order and current delivery step.")
        .supportedFamilies([.systemMedium])
    }
}

struct CustomerActiveOrdersListWidget: Widget {
    private let kind = "com.vihanga.cakelab.widget.customer.active-list"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CakeLabWidgetProvider()) { entry in
            CustomerActiveOrdersWidgetView(entry: entry)
        }
        .configurationDisplayName("Customer Active Orders")
        .description("Shows active orders from your home page list.")
        .supportedFamilies([.systemMedium])
    }
}

struct BakerNearestOrderWidget: Widget {
    private let kind = "com.vihanga.cakelab.widget.baker.nearest-order"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CakeLabWidgetProvider()) { entry in
            BakerNearestOrderWidgetView(entry: entry)
        }
        .configurationDisplayName("Baker Delivery Step")
        .description("Shows your nearest active order and production step.")
        .supportedFamilies([.systemMedium])
    }
}

struct BakerLatestMatchingWidget: Widget {
    private let kind = "com.vihanga.cakelab.widget.baker.latest-matching"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CakeLabWidgetProvider()) { entry in
            BakerLatestMatchingWidgetView(entry: entry)
        }
        .configurationDisplayName("Baker Matching Request")
        .description("Shows the latest matching request from customer posts.")
        .supportedFamilies([.systemMedium])
    }
}

private struct CustomerNearestOrderWidgetView: View {
    let entry: CakeLabWidgetEntry

    var body: some View {
        Group {
            if !entry.payload.isLoggedIn {
                LoginRequiredWidgetCard(message: "Sign in as customer to view delivery steps.")
            } else if entry.payload.role != .customer {
                RoleMismatchWidgetCard(message: "This widget is available for customer accounts.")
            } else if let order = entry.payload.customerNearestOrder {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Nearest Delivery")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(dateText(order.deliveryDate))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Text(order.cakeName)
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        StatusPill(status: order.status)
                        Spacer()
                        Text("Step \(max(1, min(5, order.currentStep)))/5")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.brown)
                    }

                    ProgressView(value: Double(max(1, min(5, order.currentStep))), total: 5)
                        .tint(.green)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(WidgetCardBackground())
            } else {
                EmptyDataWidgetCard(message: "No active orders.")
            }
        }
        .widgetURL(URL(string: "cakelab://widget/customer/status"))
    }
}

private struct CustomerActiveOrdersWidgetView: View {
    let entry: CakeLabWidgetEntry

    var body: some View {
        Group {
            if !entry.payload.isLoggedIn {
                LoginRequiredWidgetCard(message: "Sign in as customer to view active orders.")
            } else if entry.payload.role != .customer {
                RoleMismatchWidgetCard(message: "This widget is available for customer accounts.")
            } else if entry.payload.customerActiveOrders.isEmpty {
                EmptyDataWidgetCard(message: "No active orders in your home list.")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Active Orders")
                            .font(.system(size: 15, weight: .bold))
                        Spacer()
                        Text("\(entry.payload.customerActiveOrders.count)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    ForEach(Array(entry.payload.customerActiveOrders.prefix(3).enumerated()), id: \.element.id) { _, order in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(statusColor(order.status).opacity(0.2))
                                .frame(width: 8, height: 8)

                            Text(order.cakeName)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)

                            Spacer()

                            Text(shortDateText(order.deliveryDate))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(WidgetCardBackground())
            }
        }
        .widgetURL(URL(string: "cakelab://widget/customer/active-list"))
    }
}

private struct BakerNearestOrderWidgetView: View {
    let entry: CakeLabWidgetEntry

    var body: some View {
        Group {
            if !entry.payload.isLoggedIn {
                LoginRequiredWidgetCard(message: "Sign in as baker to view delivery steps.")
            } else if entry.payload.role != .baker {
                RoleMismatchWidgetCard(message: "This widget is available for baker accounts.")
            } else if let order = entry.payload.bakerNearestOrder {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Nearest Delivery")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(dateText(order.deliveryDate))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Text(order.cakeName)
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        StatusPill(status: order.status)
                        Spacer()
                        Text("Step \(max(1, min(5, order.currentStep)))/5")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.brown)
                    }

                    ProgressView(value: Double(max(1, min(5, order.currentStep))), total: 5)
                        .tint(.green)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(WidgetCardBackground())
            } else {
                EmptyDataWidgetCard(message: "No active baking orders.")
            }
        }
        .widgetURL(URL(string: "cakelab://widget/baker/status"))
    }
}

private struct BakerLatestMatchingWidgetView: View {
    let entry: CakeLabWidgetEntry

    var body: some View {
        Group {
            if !entry.payload.isLoggedIn {
                LoginRequiredWidgetCard(message: "Sign in as baker to view matching requests.")
            } else if entry.payload.role != .baker {
                RoleMismatchWidgetCard(message: "This widget is available for baker accounts.")
            } else if let request = entry.payload.bakerLatestMatchingRequest {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Matching Request")
                            .font(.system(size: 15, weight: .bold))
                        Spacer()
                        Text("\(request.bidCount) bids")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.brown)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.brown.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Text(request.title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(request.category)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.14))
                            .clipShape(Capsule())

                        Text(shortDateText(request.expectedDate))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Text("LKR \(Int(request.budgetMin).formatted()) - \(Int(request.budgetMax).formatted())")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(WidgetCardBackground())
            } else {
                EmptyDataWidgetCard(message: "No matching requests yet.")
            }
        }
        .widgetURL(URL(string: "cakelab://widget/baker/matching"))
    }
}

private struct WidgetCardBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.97, green: 0.96, blue: 0.94), .white],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct StatusPill: View {
    let status: String

    var body: some View {
        Text(statusLabel(status))
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(statusColor(status))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor(status).opacity(0.14))
            .clipShape(Capsule())
    }
}

private struct LoginRequiredWidgetCard: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CakeLab Widget")
                .font(.system(size: 15, weight: .bold))
            Text(message)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary)
            Spacer()
            Text("Open app to sign in")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.brown)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WidgetCardBackground())
    }
}

private struct RoleMismatchWidgetCard: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Role Needed")
                .font(.system(size: 15, weight: .bold))
            Text(message)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary)
            Spacer()
            Text("Switch account in app")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.brown)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WidgetCardBackground())
    }
}

private struct EmptyDataWidgetCard: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No Active Data")
                .font(.system(size: 15, weight: .bold))
            Text(message)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary)
            Spacer()
            Text("Open app to refresh")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.brown)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WidgetCardBackground())
    }
}

private func statusLabel(_ raw: String) -> String {
    switch raw {
    case "confirmed": return "Confirmed"
    case "baking": return "Baking"
    case "decorating": return "Decorating"
    case "quality_check": return "Quality Check"
    case "delivered": return "Delivered"
    default: return raw.capitalized
    }
}

private func statusColor(_ raw: String) -> Color {
    switch raw {
    case "confirmed": return Color(red: 0.15, green: 0.72, blue: 0.25)
    case "baking": return Color(red: 0.95, green: 0.70, blue: 0.10)
    case "decorating": return Color(red: 0.93, green: 0.48, blue: 0.08)
    case "quality_check": return Color(red: 0.20, green: 0.50, blue: 0.95)
    default: return .gray
    }
}

private func dateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd/MM/yyyy"
    return formatter.string(from: date)
}

private func shortDateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd MMM"
    return formatter.string(from: date)
}
