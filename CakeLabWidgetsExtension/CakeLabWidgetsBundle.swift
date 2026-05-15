import WidgetKit
import SwiftUI
import UIKit

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
    let referenceImageBase64: String?
    let bakerID: String?
    let bakerName: String?
    let bakerRating: String?
    let bakerReviewCount: Int?
    let bakerAddress: String?
    let bakerCity: String?
    let bakerProfileImageBase64: String?
    let bakerImageURL: String?
    let customerName: String?
    let customerAddress: String?
    let customerCity: String?
    let customerID: String?
    let customerProfileImageBase64: String?
    let customerImageURL: String?
}

private struct SnapshotMatchingRequest: Codable {
    let id: String
    let title: String
    let category: String
    let location: String?
    let referenceImageBase64: String?
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
        .contentMarginsDisabled()
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
                CustomerNearestDeliveryCard(order: order)
            } else {
                EmptyDataWidgetCard(message: "No active orders.")
            }
        }
        .widgetURL(URL(string: "cakelab://widget/customer/status"))
    }
}

private struct CustomerNearestDeliveryCard: View {
    let order: SnapshotOrder
    private let horizontalInset: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 9) {
                orderImage

                VStack(alignment: .leading, spacing: 4) {
                    Text(order.cakeName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.11, green: 0.11, blue: 0.11))
                        .lineLimit(2)

                    HStack(alignment: .top, spacing: 8) {
                        CompactStatusBadge(status: order.status)

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 1) {
                            Text("Delivery Date:")
                                .font(.system(size: 9, weight: .regular))
                                .foregroundColor(Color(red: 0.48, green: 0.48, blue: 0.48))
                            Text(dateText(order.deliveryDate))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(red: 0.14, green: 0.14, blue: 0.14))
                        }
                    }
                }
            }
            .padding(.horizontal, horizontalInset)
            .padding(.top, 6)
            .padding(.bottom, 6)

            WidgetOrderProgressTracker(currentStep: order.currentStep)
                .padding(.horizontal, horizontalInset)
                .padding(.bottom, 6)

            Divider()
                .padding(.horizontal, horizontalInset)

            HStack(spacing: 8) {
                bakerProfileImage

                VStack(alignment: .leading, spacing: 1) {
                    Text(bakerName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.10))
                        .lineLimit(1)
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color(red: 1.0, green: 0.74, blue: 0.08))
                        Text(bakerRatingText)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(Color(red: 0.50, green: 0.50, blue: 0.50))
                            .lineLimit(1)
                    }
                    if !bakerLocationText.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(Color(red: 0.50, green: 0.50, blue: 0.50))
                            Text(bakerLocationText)
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(Color(red: 0.50, green: 0.50, blue: 0.50))
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, horizontalInset)
            .padding(.top, 4)
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
    }

    private var orderImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.92, green: 0.90, blue: 0.87))

            if let image = widgetImage(from: order.referenceImageBase64) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(systemName: "birthday.cake.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 0.37, green: 0.22, blue: 0.08).opacity(0.45))
            }
        }
        .frame(width: 58, height: 58)
        .clipped()
    }

    private var bakerProfileImage: some View {
        Group {
            if let image = widgetImage(from: order.bakerProfileImageBase64) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = URL(string: order.bakerImageURL ?? ""), !(order.bakerImageURL ?? "").isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        bakerProfileFallback
                    }
                }
            } else {
                bakerProfileFallback
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
    }

    private var bakerProfileFallback: some View {
        Circle()
            .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.37, green: 0.22, blue: 0.08).opacity(0.5))
            )
    }

    private var bakerName: String {
        let resolved = order.bakerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return resolved.isEmpty ? order.counterpartName : resolved
    }

    private var bakerRatingText: String {
        let rating = order.bakerRating?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let reviewCount = order.bakerReviewCount ?? 0
        let reviewText = "\(reviewCount) review\(reviewCount == 1 ? "" : "s")"

        if rating.isEmpty || rating == "New baker" {
            return reviewCount > 0 ? reviewText : "No reviews yet"
        }

        return reviewCount > 0 ? "\(rating) (\(reviewText))" : rating
    }

    private var bakerLocationText: String {
        let address = order.bakerAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let city = order.bakerCity?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if address.isEmpty { return city }
        if city.isEmpty || address.localizedCaseInsensitiveContains(city) { return address }
        return "\(address), \(city)"
    }
}

private struct CompactStatusBadge: View {
    let status: String

    var body: some View {
        Text(statusLabel(status))
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(statusColor(status))
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(statusColor(status).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct WidgetOrderProgressTracker: View {
    let currentStep: Int
    private let labels = ["Confirmed", "Baking", "Decorating", "Quality\nChecking", "Delivered"]
    private let circleDiameter: CGFloat = 18
    private let progressLabelWidth: CGFloat = 58

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 0) {
                ForEach(1...5, id: \.self) { step in
                    stepCircle(step)
                    if step < 5 {
                        Rectangle()
                            .fill(step < clampedStep ? Color(red: 0.15, green: 0.60, blue: 0.22) : Color(red: 0.80, green: 0.80, blue: 0.80))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            progressLabelRow
        }
    }

    private var clampedStep: Int {
        max(1, min(5, currentStep))
    }

    private var progressLabelRow: some View {
        GeometryReader { proxy in
            let connectorWidth = max(
                0,
                (proxy.size.width - (circleDiameter * CGFloat(labels.count))) / CGFloat(labels.count - 1)
            )

            ZStack(alignment: .topLeading) {
                ForEach(labels.indices, id: \.self) { index in
                    Text(labels[index])
                        .font(.system(size: 7, weight: .regular))
                        .foregroundColor(Color(red: 0.40, green: 0.40, blue: 0.40))
                        .multilineTextAlignment(progressLabelTextAlignment(for: index))
                        .lineLimit(2)
                        .frame(width: progressLabelWidth, alignment: progressLabelFrameAlignment(for: index))
                        .position(
                            x: progressLabelX(index: index, totalWidth: proxy.size.width, connectorWidth: connectorWidth),
                            y: 8
                        )
                }
            }
        }
        .frame(height: 20)
    }

    private func progressLabelX(index: Int, totalWidth: CGFloat, connectorWidth: CGFloat) -> CGFloat {
        if index == 0 { return progressLabelWidth / 2 }
        if index == labels.count - 1 { return totalWidth - (progressLabelWidth / 2) }

        return CGFloat(index) * (circleDiameter + connectorWidth) + (circleDiameter / 2)
    }

    private func progressLabelTextAlignment(for index: Int) -> TextAlignment {
        switch index {
        case 0: return .leading
        case labels.count - 1: return .trailing
        default: return .center
        }
    }

    private func progressLabelFrameAlignment(for index: Int) -> Alignment {
        switch index {
        case 0: return .leading
        case labels.count - 1: return .trailing
        default: return .center
        }
    }

    private func stepCircle(_ step: Int) -> some View {
        ZStack {
            if step < clampedStep {
                Circle()
                    .fill(Color(red: 0.15, green: 0.60, blue: 0.22))
                    .frame(width: 18, height: 18)
                Text("\(step)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            } else if step == clampedStep {
                Circle()
                    .fill(Color(red: 0.92, green: 0.86, blue: 0.76))
                    .frame(width: 18, height: 18)
                Circle()
                    .stroke(Color(red: 0.80, green: 0.72, blue: 0.60), lineWidth: 1.2)
                    .frame(width: 18, height: 18)
                Text("\(step)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color(red: 0.50, green: 0.35, blue: 0.15))
            } else {
                Circle()
                    .fill(Color(red: 0.82, green: 0.82, blue: 0.82))
                    .frame(width: 18, height: 18)
                Text("\(step)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 18)
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
                VStack(alignment: .leading, spacing: 15) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Active Orders")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12))
                        Spacer()
                        Text("See all")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(red: 0.37, green: 0.22, blue: 0.08))
                    }

                    HStack(alignment: .top, spacing: 18) {
                        ForEach(Array(entry.payload.customerActiveOrders.prefix(3).enumerated()), id: \.element.id) { _, order in
                            CustomerActiveOrderCircleCard(order: order)
                        }
                        Spacer(minLength: 0)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 22)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.white)
            }
        }
        .widgetURL(URL(string: "cakelab://widget/customer/active-list"))
    }
}

private struct CustomerActiveOrderCircleCard: View {
    let order: SnapshotOrder

    private var orderNumber: String {
        String(order.id.prefix(6))
    }

    var body: some View {
        VStack(spacing: 9) {
            ZStack {
                Circle()
                    .stroke(Color(red: 0.10, green: 0.66, blue: 0.20), lineWidth: 3)
                    .frame(width: 76, height: 76)

                Circle()
                    .fill(Color(red: 0.93, green: 0.91, blue: 0.88))
                    .frame(width: 68, height: 68)

                if let image = widgetImage(from: order.referenceImageBase64) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 62, height: 62)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "birthday.cake.fill")
                        .font(.system(size: 25, weight: .regular))
                        .foregroundColor(Color(red: 0.37, green: 0.22, blue: 0.08).opacity(0.48))
                }
            }

            Text("Order No:\n\(orderNumber)")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color(red: 0.20, green: 0.20, blue: 0.20))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 82)
        }
        .frame(width: 82)
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
                BakerNearestDeliveryCard(order: order)
            } else {
                EmptyDataWidgetCard(message: "No active baking orders.")
            }
        }
        .widgetURL(URL(string: "cakelab://widget/baker/status"))
    }
}

private struct BakerNearestDeliveryCard: View {
    let order: SnapshotOrder
    private let horizontalInset: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 9) {
                orderImage

                VStack(alignment: .leading, spacing: 4) {
                    Text(order.cakeName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.11, green: 0.11, blue: 0.11))
                        .lineLimit(2)

                    HStack(alignment: .top, spacing: 8) {
                        CompactStatusBadge(status: order.status)

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 1) {
                            Text("Delivery Date:")
                                .font(.system(size: 9, weight: .regular))
                                .foregroundColor(Color(red: 0.48, green: 0.48, blue: 0.48))
                            Text(dateText(order.deliveryDate))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(red: 0.14, green: 0.14, blue: 0.14))
                        }
                    }
                }
            }
            .padding(.horizontal, horizontalInset)
            .padding(.top, 6)
            .padding(.bottom, 6)

            WidgetOrderProgressTracker(currentStep: order.currentStep)
                .padding(.horizontal, horizontalInset)
                .padding(.bottom, 6)

            Divider()
                .padding(.horizontal, horizontalInset)

            HStack(spacing: 8) {
                customerProfileImage

                VStack(alignment: .leading, spacing: 1) {
                    Text(customerName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.10))
                        .lineLimit(1)
                    if !customerLocationText.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(Color(red: 0.50, green: 0.50, blue: 0.50))
                            Text(customerLocationText)
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(Color(red: 0.50, green: 0.50, blue: 0.50))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, horizontalInset)
            .padding(.top, 4)
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
    }

    private var orderImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.92, green: 0.90, blue: 0.87))

            if let image = widgetImage(from: order.referenceImageBase64) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(systemName: "birthday.cake.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 0.37, green: 0.22, blue: 0.08).opacity(0.45))
            }
        }
        .frame(width: 58, height: 58)
        .clipped()
    }

    private var customerName: String {
        let resolved = order.customerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return resolved.isEmpty ? order.counterpartName : resolved
    }

    private var customerLocationText: String {
        let address = order.customerAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let city = order.customerCity?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if address.isEmpty { return city }
        if city.isEmpty || address.localizedCaseInsensitiveContains(city) { return address }
        return "\(address), \(city)"
    }

    private var customerProfileImage: some View {
        Group {
            if let image = widgetImage(from: order.customerProfileImageBase64) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = URL(string: order.customerImageURL ?? ""), !(order.customerImageURL ?? "").isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        customerProfileFallback
                    }
                }
            } else {
                customerProfileFallback
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
    }

    private var customerProfileFallback: some View {
        Circle()
            .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.37, green: 0.22, blue: 0.08).opacity(0.5))
            )
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
                matchingRequestCard(request)
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(WidgetMatchingCardBackground())
            } else {
                EmptyDataWidgetCard(message: "No matching requests yet.")
            }
        }
        .widgetURL(URL(string: "cakelab://widget/baker/matching"))
    }

    private func matchingRequestCard(_ request: SnapshotMatchingRequest) -> some View {
        VStack(spacing: 7) {
            HStack(alignment: .top, spacing: 10) {
                matchingRequestImage(request)

                VStack(alignment: .leading, spacing: 7) {
                    Text(request.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(request.category.isEmpty ? "Cake" : request.category)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(red: 0.88, green: 0.94, blue: 0.97))
                            .clipShape(Capsule())

                        Spacer(minLength: 4)

                        Label(shortDateText(request.expectedDate), systemImage: "calendar")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 6) {
                        Label(locationText(for: request), systemImage: "mappin.and.ellipse")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        Label("\(request.bidCount) bids", systemImage: "person.2.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(red: 0.37, green: 0.22, blue: 0.08))
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(red: 0.91, green: 0.88, blue: 0.84))
                            .clipShape(Capsule())
                    }
                }
            }

            Divider()

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Budget (LKR)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("LKR \(Int(request.budgetMin).formatted()) - \(Int(request.budgetMax).formatted())")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 8)

                Text("Place Bid")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.37, green: 0.22, blue: 0.08))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(Color(red: 0.91, green: 0.86, blue: 0.82))
                    .clipShape(Capsule())
            }
        }
    }

    private func matchingRequestImage(_ request: SnapshotMatchingRequest) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.95, green: 0.93, blue: 0.90))

            if let image = widgetImage(from: request.referenceImageBase64) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "birthday.cake.fill")
                    .font(.system(size: 27))
                    .foregroundColor(Color(red: 0.37, green: 0.22, blue: 0.08).opacity(0.42))
            }
        }
        .frame(width: 74, height: 74)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .clipped()
    }

    private func locationText(for request: SnapshotMatchingRequest) -> String {
        let location = request.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return location.isEmpty ? "Location not provided" : location
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

private struct WidgetMatchingCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
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

private func widgetImage(from base64: String?) -> UIImage? {
    guard let base64 else { return nil }
    let trimmed = base64.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let imagePayload: String
    if let commaIndex = trimmed.firstIndex(of: ",") {
        imagePayload = String(trimmed[trimmed.index(after: commaIndex)...])
    } else {
        imagePayload = trimmed
    }

    let normalized = imagePayload
        .components(separatedBy: .whitespacesAndNewlines)
        .joined()
    guard let data = Data(base64Encoded: normalized) else { return nil }
    return UIImage(data: data)
}
