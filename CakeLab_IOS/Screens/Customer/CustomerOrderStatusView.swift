import SwiftUI
import Combine
import FirebaseFirestore
import UIKit

@MainActor
final class CustomerOrderStatusViewModel: ObservableObject {
    @Published var order: CakeOrder?
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var progressTimestamps: [String: Date] = [:]
    @Published var createdAt: Date?
    @Published var requestCategory: String?
    @Published var requestBudgetMin: Double?
    @Published var requestBudgetMax: Double?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening(orderID: String) {
        listener?.remove()
        isLoading = true
        errorMessage = nil

        listener = db.collection("orders").document(orderID).addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
                self.errorMessage = "Unable to load order status. \(error.localizedDescription)"
                self.isLoading = false
                return
            }

            guard let snapshot, snapshot.exists, let order = CakeOrder(document: snapshot) else {
                self.errorMessage = "Order not found."
                self.isLoading = false
                return
            }

            let data = snapshot.data() ?? [:]
            self.order = order
            self.createdAt = Self.parseDate(data["createdAt"])
            self.progressTimestamps = Self.parseProgressTimestamps(data["progressTimestamps"])
            self.requestCategory = nil
            self.requestBudgetMin = nil
            self.requestBudgetMax = nil
            self.isLoading = false

            let directCategory = Self.parseCategory(from: data)
            let directBudgetMin = Self.parseDouble(data["budgetMin"])
            let directBudgetMax = Self.parseDouble(data["budgetMax"])

            if !directCategory.isEmpty {
                self.requestCategory = directCategory
            }
            if directBudgetMin > 0 {
                self.requestBudgetMin = directBudgetMin
            }
            if directBudgetMax > 0 {
                self.requestBudgetMax = directBudgetMax
            }

            if (directCategory.isEmpty || directBudgetMin <= 0 || directBudgetMax <= 0),
               let requestDocumentID = data["requestDocumentID"] as? String,
               !requestDocumentID.isEmpty {
                Task {
                    await self.loadRequestDetails(requestDocumentID: requestDocumentID)
                }
            }
        }
    }

    func timestamp(for statusKey: String) -> Date? {
        progressTimestamps[statusKey]
    }

    private static func parseDate(_ raw: Any?) -> Date? {
        if let ts = raw as? Timestamp { return ts.dateValue() }
        if let seconds = raw as? TimeInterval { return Date(timeIntervalSince1970: seconds) }
        if let seconds = raw as? Int { return Date(timeIntervalSince1970: TimeInterval(seconds)) }
        return nil
    }

    private static func parseProgressTimestamps(_ raw: Any?) -> [String: Date] {
        guard let map = raw as? [String: Any] else { return [:] }
        var result: [String: Date] = [:]
        for (key, value) in map {
            if let date = parseDate(value) {
                result[key] = date
            }
        }
        return result
    }

    private func loadRequestDetails(requestDocumentID: String) async {
        do {
            let snapshot = try await db.collection("cakeRequests").document(requestDocumentID).getDocument()
            guard let data = snapshot.data() else { return }

            let category = Self.parseCategory(from: data)
            let budgetMin = Self.parseDouble(data["budgetMin"])
            let budgetMax = Self.parseDouble(data["budgetMax"])

            if !category.isEmpty {
                requestCategory = category
            }
            if budgetMin > 0 {
                requestBudgetMin = budgetMin
            }
            if budgetMax > 0 {
                requestBudgetMax = budgetMax
            }
        } catch {
            print("Error loading linked cake request: \(error.localizedDescription)")
        }
    }

    private static func parseCategory(from data: [String: Any]) -> String {
        if let category = data["category"] as? String,
           !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return category
        }

        if let categories = data["categories"] as? [String],
           let first = categories.first,
           !first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return first
        }

        return ""
    }

    private static func parseDouble(_ raw: Any?) -> Double {
        if let value = raw as? Double { return value }
        if let value = raw as? Int { return Double(value) }
        if let value = raw as? NSNumber { return value.doubleValue }
        return 0
    }
}

struct CustomerOrderStatusView: View {
    let orderID: String
    let fallbackOrder: CustomerOrder

    @StateObject private var viewModel = CustomerOrderStatusViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var calendarAlert: CalendarAlert?
    @State private var showReviewModal = false

    private let steps: [(step: Int, statusKey: String, title: String)] = [
        (1, "confirmed", "Confirmed"),
        (2, "baking", "Baking"),
        (3, "decorating", "Decorating"),
        (4, "quality_check", "Quality Checking"),
        (5, "delivered", "Delivered")
    ]

    private let surface = Color.white
    private let accent = Color.cakeBrown

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "hh:mm a"
        return f
    }()

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                if viewModel.isLoading {
                    ProgressView("Loading status...")
                        .tint(.cakeBrown)
                        .frame(maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.urbanistRegular(14))
                            .foregroundColor(.cakeGrey)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    let liveOrder = viewModel.order
                    let cakeName = liveOrder?.cakeName ?? fallbackOrder.cakeName
                    let statusText = liveOrder?.statusLabel ?? fallbackOrder.status
                    let statusColor = liveOrder?.statusColor ?? fallbackOrder.statusColor
                    let currentStep = max(1, min(5, liveOrder?.currentStep ?? fallbackOrder.currentStep))
                    let deliveryDateText = liveOrder?.formattedDeliveryDate ?? fallbackOrder.deliveryDate
                    let category = resolvedOrderCategory(liveOrder)
                    let budgetMin = resolvedBudgetMin(liveOrder)
                    let budgetMax = resolvedBudgetMax(liveOrder)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Order Details (Date, Budget, Category)
                            orderDetailsCard(
                                deliveryDate: deliveryDateText,
                                budgetMin: budgetMin,
                                budgetMax: budgetMax,
                                category: category,
                                cakeName: cakeName,
                                statusText: statusText,
                                statusColor: statusColor
                            )

                            // Status Timeline
                            statusTimelineCard(currentStep: currentStep, deliveryDateText: deliveryDateText)

                            // Baker Info
                            bakerInfoCard(
                                name: liveOrder?.artisanName ?? fallbackOrder.bakerName,
                                rating: liveOrder?.artisanRating ?? fallbackOrder.bakerRating,
                                address: liveOrder?.artisanAddress ?? fallbackOrder.bakerAddress,
                                artisanId: liveOrder?.artisanId ?? "",
                                onReviewTapped: { showReviewModal = true }
                            )
                        }
                        .padding(.horizontal, 15)
                        .padding(.top, 14)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showReviewModal) {
            ReviewModalView(
                isPresented: $showReviewModal,
                bakerName: viewModel.order?.artisanName ?? fallbackOrder.bakerName,
                orderID: orderID,
                artisanId: viewModel.order?.artisanId ?? "",
                customerId: viewModel.order?.customerId ?? ""
            )
        }
        .task {
            viewModel.startListening(orderID: orderID)
        }
        .alert(item: $calendarAlert) { alert in
            switch alert {
            case .success(let message):
                return Alert(
                    title: Text("Added to Calendar"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            case .error(let message):
                return Alert(
                    title: Text("Calendar Error"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            case .permissionDenied:
                return Alert(
                    title: Text("Calendar Permission Needed"),
                    message: Text("Please allow Calendar access in Settings to add delivery reminders."),
                    primaryButton: .default(Text("Open Settings"), action: openAppSettings),
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cakeBrown)
            }
            Spacer()
            Text("Order Status")
                .font(.urbanistBold(18))
                .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
            Spacer()
            Color.white.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.white)
    }

    private func orderDetailsCard(
        deliveryDate: String,
        budgetMin: Double,
        budgetMax: Double,
        category: String,
        cakeName: String,
        statusText: String,
        statusColor: Color
    ) -> some View {
        let referenceImages = viewModel.order?.referenceImages ?? fallbackOrder.referenceImages
        let remoteImageURL = viewModel.order?.imageURL
        let displayCategory = resolvedCategory(category)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                cakeThumbnail(
                    referenceImages: referenceImages,
                    imageURLString: remoteImageURL,
                    fallbackImageName: fallbackOrder.imageName
                )
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 10) {
                        Text("Order ID: \(orderID.uppercased())")
                            .font(.urbanistBold(12))
                            .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
                            .lineLimit(2)

                        Spacer(minLength: 6)

                        Text(statusText)
                            .font(.urbanistMedium(12))
                            .foregroundColor(statusColor)
                            .padding(.horizontal, 18)
                            .frame(height: 25)
                            .background(statusColor.opacity(0.18))
                            .clipShape(Capsule())
                    }
                    .padding(.top, 4)

                    Text(cakeName)
                        .font(.urbanistMedium(15))
                        .foregroundColor(Color(red: 0.11, green: 0.11, blue: 0.11))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)

            Spacer(minLength: 2)

            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 13, weight: .medium))
                        Text("Date")
                            .font(.urbanistRegular(11))
                    }
                    .foregroundColor(.cakeGrey)

                    Text(formattedHeaderDate(deliveryDate))
                        .font(.urbanistMedium(11))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 2)
                .padding(.bottom, 4)

                Rectangle()
                    .fill(Color(red: 0.9, green: 0.9, blue: 0.9))
                    .frame(width: 1, height: 58)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "banknote")
                            .font(.system(size: 13, weight: .medium))
                        Text("Budget")
                            .font(.urbanistRegular(11))
                    }
                    .foregroundColor(.cakeGrey)

                    Text("Rs \(Int(budgetMin).formatted()) - \(Int(budgetMax).formatted())")
                        .font(.urbanistMedium(10.5))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 2)
                .padding(.bottom, 4)

                Rectangle()
                    .fill(Color(red: 0.9, green: 0.9, blue: 0.9))
                    .frame(width: 1, height: 58)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "tag")
                            .font(.system(size: 13, weight: .medium))
                        Text("Category")
                            .font(.urbanistRegular(11))
                    }
                    .foregroundColor(.cakeGrey)

                    Text(displayCategory)
                        .font(.urbanistMedium(10.8))
                        .foregroundColor(categoryTextColor(for: displayCategory))
                        .frame(minWidth: 100, minHeight: 25)
                        .padding(.horizontal, 12)
                        .background(categoryBackgroundColor(for: displayCategory))
                        .clipShape(Capsule())
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 2)
                .padding(.bottom, 4)
            }
            .frame(height: 58, alignment: .top)
            .padding(.horizontal, 9)
            .padding(.bottom, 10)
        }
        .frame(width: 363, height: 156)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.07), radius: 12, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
    }

    private func statusTimelineCard(currentStep: Int, deliveryDateText: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(steps, id: \.step) { item in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(circleColor(for: item.step, currentStep: currentStep))
                                .frame(width: 36, height: 36)
                            Circle()
                                .fill(Color.white.opacity(item.step == currentStep ? 0.9 : 0.0))
                                .frame(width: 16, height: 16)
                            if item.step < currentStep {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }

                        if item.step < steps.count {
                            Rectangle()
                                .fill(Color(red: 0.78, green: 0.78, blue: 0.78))
                                .frame(width: 1.2, height: 48)
                                .padding(.top, 4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(item.title)
                                .font(item.step == currentStep ? .urbanistBold(15) : .urbanistMedium(15))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                            Spacer()

                            if item.step == currentStep {
                                Text("Current")
                                    .font(.urbanistSemiBold(11))
                                    .foregroundColor(accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(red: 0.92, green: 0.88, blue: 0.83))
                                    .cornerRadius(9)
                            }
                        }

                        HStack(spacing: 10) {
                            Text("Date : \(stepDateText(step: item.step, statusKey: item.statusKey))")
                                .font(.urbanistRegular(13))
                                .foregroundColor(.cakeGrey)

                            Rectangle()
                                .fill(Color(red: 0.80, green: 0.80, blue: 0.80))
                                .frame(width: 1, height: 14)

                            Text("Time : \(stepTimeText(step: item.step, statusKey: item.statusKey))")
                                .font(.urbanistRegular(13))
                                .foregroundColor(.cakeGrey)
                        }

                        if item.step < steps.count {
                            Divider()
                                .padding(.top, 10)
                                .padding(.bottom, 8)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Expected Date")
                            .font(.urbanistSemiBold(12))
                            .foregroundColor(accent)
                        Text(deliveryDateText)
                            .font(.urbanistBold(14))
                            .foregroundColor(Color(red: 0.08, green: 0.08, blue: 0.08))
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    Rectangle()
                        .fill(Color(red: 0.80, green: 0.80, blue: 0.80))
                        .frame(width: 1, height: 38)
                        .padding(.horizontal, 12)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Expected Time")
                            .font(.urbanistSemiBold(12))
                            .foregroundColor(accent)
                        Text(expectedTimeText().lowercased())
                            .font(.urbanistBold(14))
                            .foregroundColor(Color(red: 0.08, green: 0.08, blue: 0.08))
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .padding(.top, 14)

            Button {
                Task {
                    await addDeliveryEventToCalendar(deliveryDateText: deliveryDateText)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Add Delivery to Calendar")
                        .font(.urbanistSemiBold(14))
                }
                .foregroundColor(accent)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(Color(red: 0.92, green: 0.90, blue: 0.87))
                .cornerRadius(19)
            }
            .padding(.top, 14)
        }
        .padding(16)
        .background(surface)
        .cornerRadius(22)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
    }

    private func bakerInfoCard(name: String, rating: String, address: String, artisanId: String, onReviewTapped: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Baker Details")
                .font(.urbanistBold(16))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                        .frame(width: 48, height: 48)
                    Image(systemName: "person.fill")
                        .font(.system(size: 21))
                        .foregroundColor(.cakeBrown.opacity(0.55))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.urbanistBold(14))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.1))
                        Text(rating)
                            .font(.urbanistRegular(12))
                            .foregroundColor(.cakeGrey)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.cakeGrey)
                        Text(address)
                            .font(.urbanistRegular(12))
                            .foregroundColor(.cakeGrey)
                            .lineLimit(1)
                    }
                }
            }

            Button {
                onReviewTapped()
            } label: {
                Text("Write a Review")
                    .font(.urbanistBold(15))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(accent)
                    .cornerRadius(24)
            }
            .padding(.top, 14)
        }
        .padding(16)
        .background(surface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func cakeThumbnail(referenceImages: [String], imageURLString: String?, fallbackImageName: String) -> some View {
        let size: CGFloat = 80

        Group {
            if let firstReferenceImage = referenceImages.first,
               let imageData = Data(base64Encoded: firstReferenceImage),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let imageURLString, !imageURLString.isEmpty, let imageURL = URL(string: imageURLString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        thumbnailPlaceholder
                    }
                }
            } else if !fallbackImageName.isEmpty {
                Image(fallbackImageName)
                    .resizable()
                    .scaledToFill()
            } else {
                thumbnailPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
    }

    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(red: 0.93, green: 0.90, blue: 0.87))
            .overlay(
                Image(systemName: "photo.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.cakeBrown.opacity(0.35))
            )
    }
    /*
    private func truncatedCakeName(_ name: String) -> String {
        let normalizedName = name
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace)

        guard normalizedName.count > 5 else {
            return normalizedName.joined(separator: " ")
        }

        return normalizedName.prefix(5).joined(separator: " ") + "..."
    } */

    private func resolvedCategory(_ category: String) -> String {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No category" : trimmed
    }

    private func resolvedOrderCategory(_ liveOrder: CakeOrder?) -> String {
        let candidates = [
            liveOrder?.category,
            viewModel.requestCategory,
            fallbackOrder.category
        ]

        for candidate in candidates {
            let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return "No category"
    }

    private func resolvedBudgetMin(_ liveOrder: CakeOrder?) -> Double {
        let liveValue = liveOrder?.budgetMin ?? 0
        if liveValue > 0 { return liveValue }
        if let requestValue = viewModel.requestBudgetMin, requestValue > 0 { return requestValue }
        return fallbackOrder.budgetMin
    }

    private func resolvedBudgetMax(_ liveOrder: CakeOrder?) -> Double {
        let liveValue = liveOrder?.budgetMax ?? 0
        if liveValue > 0 { return liveValue }
        if let requestValue = viewModel.requestBudgetMax, requestValue > 0 { return requestValue }
        return fallbackOrder.budgetMax
    }

    private func formattedHeaderDate(_ rawDate: String) -> String {
        guard let parsedDate = parseHeaderDate(rawDate) else {
            return rawDate
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: parsedDate)
    }

    private func parseHeaderDate(_ rawDate: String) -> Date? {
        let patterns = ["dd/MM/yyyy", "dd/ MM/ yyyy", "d/M/yyyy", "dd MMM yyyy"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for pattern in patterns {
            formatter.dateFormat = pattern
            if let parsed = formatter.date(from: rawDate.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return parsed
            }
        }

        return nil
    }

    private func categoryBackgroundColor(for category: String) -> Color {
        let categoryLower = category.lowercased()
        switch categoryLower {
        case let cat where cat.contains("wedding"):
            return Color(red: 1.0, green: 0.95, blue: 0.97)
        case let cat where cat.contains("birthday"):
            return Color(red: 0.99, green: 0.95, blue: 0.90)
        case let cat where cat.contains("anniversary"):
            return Color(red: 0.95, green: 0.99, blue: 0.95)
        case let cat where cat.contains("baby"):
            return Color(red: 0.98, green: 0.96, blue: 1.0)
        case let cat where cat.contains("cupcake"):
            return Color(red: 1.0, green: 0.98, blue: 0.94)
        case let cat where cat.contains("buttercream"):
            return Color(red: 0.99, green: 1.0, blue: 0.95)
        case let cat where cat.contains("corporate"):
            return Color(red: 0.95, green: 0.98, blue: 1.0)
        case let cat where cat.contains("engagement"):
            return Color(red: 1.0, green: 0.96, blue: 0.92)
        case let cat where cat.contains("graduation"):
            return Color(red: 0.94, green: 0.97, blue: 1.0)
        case let cat where cat.contains("baptism"):
            return Color(red: 0.96, green: 0.99, blue: 1.0)
        case let cat where cat.contains("retirement"):
            return Color(red: 1.0, green: 0.96, blue: 0.94)
        case let cat where cat.contains("farewell"):
            return Color(red: 0.98, green: 0.97, blue: 1.0)
        case let cat where cat.contains("vegan"):
            return Color(red: 0.96, green: 1.0, blue: 0.96)
        case let cat where cat.contains("sculpted"):
            return Color(red: 0.98, green: 0.95, blue: 0.99)
        default:
            return Color(red: 0.96, green: 0.96, blue: 0.96)
        }
    }

    private func categoryTextColor(for category: String) -> Color {
        let categoryLower = category.lowercased()
        switch categoryLower {
        case let cat where cat.contains("wedding"):
            return Color(red: 0.8, green: 0.3, blue: 0.6)
        case let cat where cat.contains("birthday"):
            return Color(red: 0.85, green: 0.5, blue: 0.25)
        case let cat where cat.contains("anniversary"):
            return Color(red: 0.2, green: 0.6, blue: 0.4)
        case let cat where cat.contains("baby"):
            return Color(red: 0.6, green: 0.3, blue: 0.8)
        case let cat where cat.contains("cupcake"):
            return Color(red: 0.8, green: 0.5, blue: 0.2)
        case let cat where cat.contains("buttercream"):
            return Color(red: 0.7, green: 0.6, blue: 0.1)
        case let cat where cat.contains("corporate"):
            return Color(red: 0.2, green: 0.5, blue: 0.8)
        case let cat where cat.contains("engagement"):
            return Color(red: 0.85, green: 0.35, blue: 0.3)
        case let cat where cat.contains("graduation"):
            return Color(red: 0.3, green: 0.5, blue: 0.7)
        case let cat where cat.contains("baptism"):
            return Color(red: 0.2, green: 0.6, blue: 0.7)
        case let cat where cat.contains("retirement"):
            return Color(red: 0.8, green: 0.4, blue: 0.3)
        case let cat where cat.contains("farewell"):
            return Color(red: 0.5, green: 0.3, blue: 0.7)
        case let cat where cat.contains("vegan"):
            return Color(red: 0.2, green: 0.7, blue: 0.2)
        case let cat where cat.contains("sculpted"):
            return Color(red: 0.7, green: 0.2, blue: 0.7)
        default:
            return Color(red: 0.4, green: 0.4, blue: 0.4)
        }
    }

    private func stepDateText(step: Int, statusKey: String) -> String {
        if step == 1, let created = viewModel.timestamp(for: statusKey) ?? viewModel.createdAt {
            return Self.dateFmt.string(from: created)
        }
        guard let date = viewModel.timestamp(for: statusKey) else { return "Pending" }
        return Self.dateFmt.string(from: date)
    }

    private func stepTimeText(step: Int, statusKey: String) -> String {
        if step == 1, let created = viewModel.timestamp(for: statusKey) ?? viewModel.createdAt {
            return Self.timeFmt.string(from: created)
        }
        guard let date = viewModel.timestamp(for: statusKey) else { return "Pending" }
        return Self.timeFmt.string(from: date)
    }

    private func circleColor(for step: Int, currentStep: Int) -> Color {
        if step < currentStep {
            return Color(red: 0.14, green: 0.58, blue: 0.34)
        }
        if step == currentStep {
            return accent
        }
        return Color(red: 0.78, green: 0.78, blue: 0.78)
    }

    private func expectedTimeText() -> String {
        if let dateTime = viewModel.order?.deliveryDateTime {
            return Self.timeFmt.string(from: dateTime)
        }
        if let time = viewModel.order?.deliveryTime {
            return Self.timeFmt.string(from: time)
        }
        return "10:00 AM"
    }

    private func resolvedDeliveryStartDate(deliveryDateText: String) -> Date {
        if let order = viewModel.order {
            if let dateTime = order.deliveryDateTime {
                return dateTime
            }

            if let deliveryTime = order.deliveryTime {
                var calendar = Calendar.current
                calendar.timeZone = .current

                let day = calendar.dateComponents([.year, .month, .day], from: order.deliveryDate)
                let time = calendar.dateComponents([.hour, .minute, .second], from: deliveryTime)

                var merged = DateComponents()
                merged.year = day.year
                merged.month = day.month
                merged.day = day.day
                merged.hour = time.hour ?? 10
                merged.minute = time.minute ?? 0
                merged.second = time.second ?? 0
                return calendar.date(from: merged) ?? order.deliveryDate
            }

            return order.deliveryDate
        }

        return Self.dateFmt.date(from: deliveryDateText) ?? Date()
    }

    private func addDeliveryEventToCalendar(deliveryDateText: String) async {
        let liveOrder = viewModel.order
        let startDate = resolvedDeliveryStartDate(deliveryDateText: deliveryDateText)
        let title = "Cake Delivery - \(liveOrder?.cakeName ?? fallbackOrder.cakeName)"
        let bakerName = liveOrder?.artisanName ?? fallbackOrder.bakerName
        let address = liveOrder?.artisanAddress ?? fallbackOrder.bakerAddress

        let noteLines = [
            "Order ID: \(orderID)",
            "Baker: \(bakerName)",
            "Address: \(address)"
        ]

        do {
            let appUserID = liveOrder?.customerId ?? "customer_unknown"
            _ = try await CalendarEventManager.shared.addOrUpdateDeliveryEvent(
                appUserID: appUserID,
                appUserName: "Customer",
                orderID: orderID,
                eventTitle: title,
                startDate: startDate,
                endDate: startDate.addingTimeInterval(60 * 60),
                location: address,
                notes: noteLines.joined(separator: "\n")
            )
            calendarAlert = .success("Delivery reminder has been added to your phone calendar.")
        } catch let error as CalendarEventManager.CalendarError {
            if error == .accessDenied {
                calendarAlert = .permissionDenied
            } else {
                calendarAlert = .error(error.localizedDescription)
            }
        } catch {
            calendarAlert = .error(error.localizedDescription)
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private enum CalendarAlert: Identifiable {
    case success(String)
    case error(String)
    case permissionDenied

    var id: String {
        switch self {
        case .success(let msg):
            return "success_\(msg)"
        case .error(let msg):
            return "error_\(msg)"
        case .permissionDenied:
            return "permissionDenied"
        }
    }
}

#Preview {
    NavigationStack {
        CustomerOrderStatusView(
            orderID: "B001",
            fallbackOrder: CustomerOrder(
                id: "B001",
                cakeName: "Rainbow Unicorn Birthday Cake",
                status: "Decorating",
                statusColor: Color(red: 1.0, green: 0.55, blue: 0.10),
                deliveryDate: "09/04/2026",
                currentStep: 3,
                bakerName: "Cake Haven by Dinithi",
                bakerRating: "5.0 (41 reviews)",
                bakerAddress: "Colombo 02",
                category: "Birthday Cake",
                budgetMin: 8000,
                budgetMax: 12000
            )
        )
    }
}
