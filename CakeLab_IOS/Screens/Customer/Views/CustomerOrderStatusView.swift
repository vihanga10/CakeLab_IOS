import SwiftUI
import UIKit

struct CustomerOrderStatusView: View {
    let orderID: String
    let fallbackOrder: CustomerOrder
    let showsCalendarAction: Bool

    @StateObject private var viewModel = CustomerOrderStatusViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var calendarAlert: CalendarAlert?
    @State private var showReviewModal = false
    @State private var observedStatusForNotification: String?

    private let steps: [(step: Int, statusKey: String, title: String)] = [
        (1, "confirmed", "Confirmed"),
        (2, "baking", "Baking"),
        (3, "decorating", "Decorating"),
        (4, "quality_check", "Quality Checking"),
        (5, "delivered", "Delivered")
    ]

    private let surface = Color.white
    private let accent = Color.cakeBrown

    init(orderID: String, fallbackOrder: CustomerOrder, showsCalendarAction: Bool = true) {
        self.orderID = orderID
        self.fallbackOrder = fallbackOrder
        self.showsCalendarAction = showsCalendarAction
    }

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
            Color.cakeBackground.ignoresSafeArea()

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
                    let deliveryTimeText = expectedTimeText()
                    let category = resolvedOrderCategory(liveOrder)
                    let budgetMin = resolvedBudgetMin(liveOrder)
                    let budgetMax = resolvedBudgetMax(liveOrder)
                    let amountText = resolvedBidAmountText(liveOrder, budgetMin: budgetMin, budgetMax: budgetMax)
                    let bakerProfile = viewModel.bakerProfile

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Order Details (Date, Budget, Category)
                            orderDetailsCard(
                                deliveryDate: deliveryDateText,
                                category: category,
                                cakeName: cakeName,
                                statusText: statusText,
                                statusColor: statusColor,
                                deliveryTime: deliveryTimeText,
                                amountText: amountText
                            )

                            // Status Timeline
                            statusTimelineCard(currentStep: currentStep, deliveryDateText: deliveryDateText)

                            // Baker Info
                            bakerInfoCard(
                                name: resolvedBakerName(liveOrder, profile: bakerProfile),
                                rating: resolvedBakerRating(liveOrder, profile: bakerProfile),
                                reviewCount: bakerProfile.reviewCount,
                                address: resolvedBakerAddress(liveOrder, profile: bakerProfile),
                                city: bakerProfile.city,
                                phone: bakerProfile.phone,
                                profileImageBase64: bakerProfile.profileImageBase64,
                                imageURL: bakerProfile.imageURL,
                                artisanId: liveOrder?.artisanId ?? "",
                                onReviewTapped: { showReviewModal = true }
                            )
                        }
                        .padding(.horizontal, 15)
                        .padding(.top, 14)
                        .padding(.bottom, 125)
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
        .onChange(of: viewModel.order?.status) { _, newStatus in
            handleLiveStatusNotification(newStatus: newStatus)
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
        .asCustomerSubScreen()
    }

    private func handleLiveStatusNotification(newStatus: String?) {
        guard let newStatus = newStatus?.trimmingCharacters(in: .whitespacesAndNewlines),
              !newStatus.isEmpty else { return }

        if observedStatusForNotification == nil {
            observedStatusForNotification = newStatus
            return
        }

        guard observedStatusForNotification != newStatus else { return }
        observedStatusForNotification = newStatus
        guard newStatus != "confirmed", let order = viewModel.order else { return }

        notificationManager.notifyCustomerOrderStatusUpdated(
            bakerName: resolvedBakerName(order, profile: viewModel.bakerProfile),
            cakeName: order.cakeName,
            stageTitle: order.statusLabel,
            statusKey: newStatus,
            orderID: order.id,
            customerID: order.customerId,
            bakerID: order.artisanId
        )
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
        .background(Color.cakeSurface)
    }

    private func orderDetailsCard(
        deliveryDate: String,
        category: String,
        cakeName: String,
        statusText: String,
        statusColor: Color,
        deliveryTime: String,
        amountText: String
    ) -> some View {
        let referenceImages = viewModel.order?.referenceImages ?? fallbackOrder.referenceImages
        let remoteImageURL = viewModel.order?.imageURL
        let displayCategory = resolvedCategory(category)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                cakeThumbnail(
                    referenceImages: referenceImages,
                    imageURLString: remoteImageURL,
                    fallbackImageName: fallbackOrder.imageName
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 10) {
                        Text("Order ID: \(orderID.uppercased())")
                            .font(.urbanistSemiBold(12))
                            .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer(minLength: 6)

                        Text(statusText)
                            .font(.urbanistMedium(11))
                            .foregroundColor(statusColor)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .frame(height: 24)
                            .background(statusColor.opacity(0.18))
                            .clipShape(Capsule())
                    }

                    Text(cakeName)
                        .font(.urbanistBold(15))
                        .foregroundColor(Color(red: 0.11, green: 0.11, blue: 0.11))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)

                    Text(displayCategory)
                        .font(.urbanistMedium(11))
                        .foregroundColor(categoryTextColor(for: displayCategory))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .frame(height: 23)
                        .background(categoryBackgroundColor(for: displayCategory))
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 80, alignment: .topLeading)
            }

            Divider()

            HStack(spacing: 0) {
                statusMetric(label: "Delivery", value: formattedHeaderDate(deliveryDate))
                Divider().frame(height: 34)
                statusMetric(label: "Time", value: deliveryTime)
                Divider().frame(height: 34)
                statusMetric(label: "Amount", value: amountText)
            }
        }
        .padding(14)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
    }

    private func statusMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.urbanistRegular(10))
                .foregroundColor(.cakeGrey)
            Text(value)
                .font(.urbanistBold(12))
                .foregroundColor(.cakePrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }

    private func statusTimelineCard(currentStep: Int, deliveryDateText: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(steps, id: \.step) { item in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(circleColor(for: item.step, currentStep: currentStep))
                                .frame(width: 30, height: 30)
                            Circle()
                                .fill(Color.white.opacity(item.step == currentStep ? 0.9 : 0.0))
                                .frame(width: 12, height: 12)
                            if item.step < currentStep {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }

                        if item.step < steps.count {
                            Rectangle()
                                .fill(Color(red: 0.78, green: 0.78, blue: 0.78))
                                .frame(width: 1.2, height: 42)
                                .padding(.top, 4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(item.title)
                                .font(item.step == currentStep ? .urbanistBold(15) : .urbanistMedium(15))
                                .foregroundColor(.cakePrimaryText)

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
                            Text("Date : \(timelineDateText(step: item.step, statusKey: item.statusKey, deliveryDateText: deliveryDateText))")
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

            if showsCalendarAction {
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
        }
        .padding(16)
        .background(surface)
        .cornerRadius(22)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
    }

    private func bakerInfoCard(
        name: String,
        rating: String,
        reviewCount: Int,
        address: String,
        city: String,
        phone: String,
        profileImageBase64: String,
        imageURL: String,
        artisanId: String,
        onReviewTapped: @escaping () -> Void
    ) -> some View {
        let locationText = resolvedBakerLocation(address: address, city: city)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Baker Details")
                .font(.urbanistBold(16))
                .foregroundColor(.cakePrimaryText)

            HStack(alignment: .top, spacing: 12) {
                bakerProfileImage(base64: profileImageBase64, imageURL: imageURL)

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.urbanistBold(14))
                        .foregroundColor(.cakePrimaryText)
                        .lineLimit(2)

                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.1))
                        Text(reviewSummaryText(rating: rating, reviewCount: reviewCount))
                            .font(.urbanistRegular(12))
                            .foregroundColor(.cakeGrey)
                            .lineLimit(1)
                    }

                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.cakeGrey)
                            .padding(.top, 2)
                        Text(locationText)
                            .font(.urbanistRegular(12))
                            .foregroundColor(.cakeGrey)
                            .lineLimit(2)
                    }

                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.cakeGrey)
                            .padding(.top, 3)
                        Text(resolvedBakerPhone(phone))
                            .font(.urbanistRegular(12))
                            .foregroundColor(.cakeGrey)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
            .padding(.top, 12)
        }
        .padding(16)
        .background(surface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func bakerProfileImage(base64: String, imageURL: String) -> some View {
        Group {
            if let image = decodeBase64Image(base64) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = URL(string: imageURL), !imageURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        bakerProfilePlaceholder
                    }
                }
            } else {
                bakerProfilePlaceholder
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(Circle())
    }

    private var bakerProfilePlaceholder: some View {
        Circle()
            .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.cakeBrown.opacity(0.65))
            )
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

    private func decodeBase64Image(_ rawBase64: String) -> UIImage? {
        let trimmed = rawBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let payload: String
        if let commaIndex = trimmed.firstIndex(of: ",") {
            payload = String(trimmed[trimmed.index(after: commaIndex)...])
        } else {
            payload = trimmed
        }

        guard let data = Data(base64Encoded: payload) else { return nil }
        return UIImage(data: data)
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

    private func resolvedBidAmountText(_ liveOrder: CakeOrder?, budgetMin: Double, budgetMax: Double) -> String {
        if let amount = liveOrder?.amount, amount > 0 {
            return "LKR \(Int(amount).formatted())"
        }

        let fallbackAmount = max(budgetMin, budgetMax)
        return fallbackAmount > 0 ? "LKR \(Int(fallbackAmount).formatted())" : "N/A"
    }

    private func resolvedBakerName(_ liveOrder: CakeOrder?, profile: OrderStatusBakerProfile) -> String {
        let candidates = [profile.name, liveOrder?.artisanName, fallbackOrder.bakerName]
        return firstNonEmpty(candidates) ?? "Baker"
    }

    private func resolvedBakerRating(_ liveOrder: CakeOrder?, profile: OrderStatusBakerProfile) -> String {
        firstNonEmpty([profile.ratingText, liveOrder?.artisanRating, fallbackOrder.bakerRating]) ?? ""
    }

    private func resolvedBakerAddress(_ liveOrder: CakeOrder?, profile: OrderStatusBakerProfile) -> String {
        firstNonEmpty([profile.address, liveOrder?.artisanAddress, fallbackOrder.bakerAddress]) ?? ""
    }

    private func resolvedBakerLocation(address: String, city: String) -> String {
        let display = SriLankaDistricts.displayLocation(address: address, city: city)
        return display.isEmpty ? "Address not provided" : display
    }

    private func resolvedBakerPhone(_ phone: String) -> String {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Phone not provided" : trimmed
    }

    private func reviewSummaryText(rating: String, reviewCount: Int) -> String {
        let trimmedRating = rating.trimmingCharacters(in: .whitespacesAndNewlines)
        let reviewText = reviewCount == 1 ? "1 review" : "\(reviewCount) reviews"

        if trimmedRating.isEmpty || trimmedRating == "New baker" {
            return reviewCount > 0 ? reviewText : "No reviews yet"
        }

        return reviewCount > 0 ? "\(trimmedRating) (\(reviewText))" : trimmedRating
    }

    private func firstNonEmpty(_ values: [String?]) -> String? {
        values.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
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

    private func timelineDateText(step: Int, statusKey: String, deliveryDateText: String) -> String {
        if step == steps.count {
            return deliveryDateText
        }
        return stepDateText(step: step, statusKey: statusKey)
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
    .environmentObject(NotificationManager())
}
