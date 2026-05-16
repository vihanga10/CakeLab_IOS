import SwiftUI

// MARK: - Customer Orders View
struct CustomerOrdersView: View {
    let user: AppUser

    @State private var selectedTab = 0
    @State private var selectedBakerProfileOrder: CustomerOrder?
    @StateObject private var viewModel = CustomerOrdersViewModel()
    @EnvironmentObject var notificationManager: NotificationManager

    private let stepLabels = ["Confirmed", "Baking", "Decorating", "Quality\nChecking", "Delivered"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cakeBackground.ignoresSafeArea()

                VStack(spacing: 0) {

                    HStack(spacing: 0) {
                        tabButton(title: "Active Orders", tag: 0)
                        tabButton(title: "Completed Orders", tag: 1)
                    }
                    .padding(4)
                    .background(Color(red: 0.92, green: 0.92, blue: 0.92))
                    .clipShape(Capsule())
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                    if selectedTab == 0 {
                        // MARK: Active Orders List - orders still in progress
                        if viewModel.isLoading {
                            ProgressView("Loading orders...")
                                .tint(.cakeBrown)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if viewModel.activeOrders.isEmpty {
                            emptyState(message: "No active orders")
                        } else {
                            ScrollView(showsIndicators: false) {
                                VStack(spacing: 16) {
                                    ForEach(viewModel.activeOrders, id: \.id) { order in
                                        NavigationLink {
                                            CustomerOrderStatusView(orderID: order.id, fallbackOrder: order)
                                        } label: {
                                            OrderCard(
                                                order: order,
                                                stepLabels: stepLabels,
                                                onBakerProfileTapped: {
                                                    selectedBakerProfileOrder = order
                                                }
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                            }
                        }
                    } else {
                        // MARK: Completed Orders List - delivered order history
                        if viewModel.completedOrders.isEmpty {
                            emptyState(message: "No completed orders")
                        } else {
                            ScrollView(showsIndicators: false) {
                                VStack(spacing: 16) {
                                    ForEach(viewModel.completedOrders, id: \.id) { order in
                                        NavigationLink {
                                            CustomerOrderStatusView(
                                                orderID: order.id,
                                                fallbackOrder: order,
                                                showsCalendarAction: false
                                            )
                                        } label: {
                                            CompletedOrderCard(
                                                order: order,
                                                onBakerProfileTapped: {
                                                    selectedBakerProfileOrder = order
                                                }
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Order Details")
                        .font(.urbanistBold(18))
                        .foregroundColor(Color(red: 93/255, green: 55/255, blue: 20/255))
                }
            }
        }
        .task {
            await notificationManager.syncCustomerOrderStatusNotifications(customerID: user.id)
            await viewModel.loadOrders(customerID: user.id)
        }
        .onReceive(NotificationCenter.default.publisher(for: .orderDidChange)) { _ in
            // Refresh order cards when an order status changes.
            Task {
                await notificationManager.syncCustomerOrderStatusNotifications(customerID: user.id)
                await viewModel.loadOrders(customerID: user.id)
            }
        }
        .sheet(item: $selectedBakerProfileOrder) { order in
            // Public baker profile from order card baker photo.
            CustomerPublicBakerProfileView(
                bakerID: order.bakerID,
                fallbackName: order.bakerName,
                fallbackProfileImageBase64: order.bakerProfileImageBase64,
                fallbackImageURL: order.bakerImageURL,
                fallbackAddress: order.bakerAddress,
                fallbackCity: order.bakerCity
            )
        }
    }

    private func tabButton(title: String, tag: Int) -> some View {
        Button { withAnimation { selectedTab = tag } } label: {
            Text(title)
                .font(selectedTab == tag ? .urbanistSemiBold(13) : .urbanistRegular(13))
                .foregroundColor(selectedTab == tag ? .white : Color(red: 0.4, green: 0.4, blue: 0.4))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(selectedTab == tag ? Color.cakeBrown : Color.clear)
                .clipShape(Capsule())
        }
    }

    private func emptyState(message: String) -> some View {
        VStack {
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundColor(.cakeGrey)
                .padding(.bottom, 8)
            Text(message)
                .font(.urbanistRegular(15))
                .foregroundColor(.cakeGrey)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Order Card
struct OrderCard: View {
    let order: CustomerOrder
    let stepLabels: [String]
    let onBakerProfileTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Top card area: cake image, name, status, and delivery date.
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                        .frame(width: 80, height: 80)

                    if !order.referenceImages.isEmpty,
                       let imageData = Data(base64Encoded: order.referenceImages[0]),
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable().scaledToFill()
                            .frame(width: 80, height: 80).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else if UIImage(named: order.imageName) != nil {
                        Image(order.imageName)
                            .resizable().scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "birthday.cake.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.cakeBrown.opacity(0.4))
                    }
                }
                .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: 0) {
                    Text(order.cakeName)
                        .font(.urbanistBold(15))
                        .foregroundColor(.cakePrimaryText)
                        .lineLimit(2)

                    HStack(alignment: .top, spacing: 10) {
                        statusBadge
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Delivery Date:")
                                .font(.urbanistRegular(11)).foregroundColor(.cakeGrey)
                            Text(order.deliveryDate)
                                .font(.urbanistSemiBold(12))
                                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                        }
                    }
                    .padding(.top, 14)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)

            OrderProgressTracker(currentStep: order.currentStep, labels: stepLabels)
                .padding(.horizontal, 14).padding(.top, 4).padding(.bottom, 10)

            Divider().padding(.horizontal, 18)

            // Baker details row at the bottom of active order card.
            HStack(spacing: 12) {
                bakerProfileImage
                    .contentShape(Circle())
                    .highPriorityGesture(
                        TapGesture().onEnded {
                            onBakerProfileTapped()
                        }
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text(order.bakerName).font(.urbanistBold(14)).foregroundColor(.cakePrimaryText)
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.1))
                        Text(bakerRatingText).font(.urbanistRegular(12)).foregroundColor(.cakeGrey)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11)).foregroundColor(.cakeGrey)
                        Text(bakerLocationText)
                            .font(.urbanistRegular(11)).foregroundColor(.cakeGrey).lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .background(Color.cakeSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 3)
    }

    private var statusBadge: some View {
        Text(order.status)
            .font(.urbanistSemiBold(11)).foregroundColor(statusBadgeTextColor)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(order.statusColor.opacity(0.12)).cornerRadius(8)
    }

    private var statusBadgeTextColor: Color {
        order.status.lowercased() == "baking" ? Color(hex: "B7791F") : order.statusColor
    }

    private var bakerProfileImage: some View {
        Group {
            if let image = decodeBase64Image(order.bakerProfileImageBase64) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let url = URL(string: order.bakerImageURL), !order.bakerImageURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: bakerProfileFallback
                    }
                }
            } else { bakerProfileFallback }
        }
        .frame(width: 48, height: 48).clipShape(Circle())
    }

    private var bakerProfileFallback: some View {
        Circle().fill(Color(red: 0.92, green: 0.90, blue: 0.87))
            .overlay(Image(systemName: "person.fill").font(.system(size: 22)).foregroundColor(.cakeBrown.opacity(0.5)))
    }

    private var bakerRatingText: String {
        let rating = order.bakerRating.trimmingCharacters(in: .whitespacesAndNewlines)
        let reviewText = "\(order.bakerReviewCount) review\(order.bakerReviewCount == 1 ? "" : "s")"
        if rating.isEmpty || rating == "New baker" {
            return order.bakerReviewCount > 0 ? reviewText : "No reviews yet"
        }
        return order.bakerReviewCount > 0 ? "\(rating) (\(reviewText))" : rating
    }

    private var bakerLocationText: String {
        let display = SriLankaDistricts.displayLocation(address: order.bakerAddress, city: order.bakerCity)
        return display.isEmpty ? "Address not provided" : display
    }

    private func decodeBase64Image(_ rawBase64: String) -> UIImage? {
        let trimmed = rawBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let payload: String
        if let commaIndex = trimmed.firstIndex(of: ",") {
            payload = String(trimmed[trimmed.index(after: commaIndex)...])
        } else { payload = trimmed }
        guard let data = Data(base64Encoded: payload) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - Completed Order Card
struct CompletedOrderCard: View {
    let order: CustomerOrder
    let onBakerProfileTapped: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Completed order card with cake image, baker, date, and delivered badge.
            orderImage
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 8) {
                    Text(order.cakeName)
                        .font(.urbanistSemiBold(15))
                        .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.10))
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.70, green: 0.70, blue: 0.70))
                        .padding(.top, 3)
                }
                HStack(spacing: 6) {
                    bakerProfileImage
                        .contentShape(Circle())
                        .highPriorityGesture(
                            TapGesture().onEnded {
                                onBakerProfileTapped()
                            }
                        )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(order.bakerName).font(.urbanistSemiBold(12))
                            .foregroundColor(Color(red: 0.22, green: 0.22, blue: 0.22)).lineLimit(1)
                        Text(bakerLocationText).font(.urbanistRegular(11)).foregroundColor(.cakeGrey).lineLimit(1)
                    }
                }
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar").font(.system(size: 10, weight: .semibold))
                        Text(order.deliveryDate).font(.urbanistSemiBold(11))
                    }
                    .foregroundColor(.cakeBrown).padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Color(red: 0.96, green: 0.94, blue: 0.91)).clipShape(Capsule())
                    statusBadge
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.cakeSurface)
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var orderImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(red: 0.95, green: 0.93, blue: 0.90))
            if !order.referenceImages.isEmpty,
               let imageData = Data(base64Encoded: order.referenceImages[0]),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage).resizable().scaledToFill()
                    .frame(width: 72, height: 72).clipped()
            } else if UIImage(named: order.imageName) != nil {
                Image(order.imageName).resizable().scaledToFill().frame(width: 72, height: 72).clipped()
            } else {
                Image(systemName: "birthday.cake.fill").font(.system(size: 28)).foregroundColor(.cakeBrown.opacity(0.42))
            }
        }
        .frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 10, weight: .semibold))
            Text("Delivered").font(.urbanistSemiBold(11))
        }
        .foregroundColor(Color(red: 0.18, green: 0.58, blue: 0.25))
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Color(red: 0.90, green: 0.97, blue: 0.91)).clipShape(Capsule())
    }

    private var bakerProfileImage: some View {
        Group {
            if let image = decodeBase64Image(order.bakerProfileImageBase64) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let url = URL(string: order.bakerImageURL), !order.bakerImageURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: bakerProfileFallback
                    }
                }
            } else { bakerProfileFallback }
        }
        .frame(width: 28, height: 28).clipShape(Circle())
    }

    private var bakerProfileFallback: some View {
        Circle().fill(Color(red: 0.92, green: 0.90, blue: 0.87))
            .overlay(Image(systemName: "person.fill").font(.system(size: 13)).foregroundColor(.cakeBrown.opacity(0.5)))
    }

    private var bakerLocationText: String {
        let display = SriLankaDistricts.displayLocation(address: order.bakerAddress, city: order.bakerCity)
        return display.isEmpty ? "Address not provided" : display
    }

    private func decodeBase64Image(_ rawBase64: String) -> UIImage? {
        let trimmed = rawBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let payload: String
        if let commaIndex = trimmed.firstIndex(of: ",") {
            payload = String(trimmed[trimmed.index(after: commaIndex)...])
        } else { payload = trimmed }
        guard let data = Data(base64Encoded: payload) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - Order Progress Tracker
struct OrderProgressTracker: View {
    let currentStep: Int
    let labels: [String]
    private let totalSteps = 5
    private let circleSize: CGFloat = 30
    private let labelWidth: CGFloat = 64

    var body: some View {
        VStack(spacing: 6) {
            // Progress circles and connector line.
            HStack(spacing: 0) {
                ForEach(1...totalSteps, id: \.self) { step in
                    stepCircle(step: step)
                    if step < totalSteps { connectorLine(step: step) }
                }
            }

            GeometryReader { proxy in
                // Progress labels aligned under each circle.
                ZStack(alignment: .topLeading) {
                    ForEach(0..<totalSteps, id: \.self) { idx in
                        Text(labels[idx])
                            .font(.urbanistRegular(9))
                            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                            .multilineTextAlignment(labelTextAlignment(for: idx))
                            .lineLimit(2)
                            .frame(width: labelWidth, alignment: labelFrameAlignment(for: idx))
                            .position(
                                x: labelXPosition(index: idx, width: proxy.size.width),
                                y: 12
                            )
                    }
                }
            }
            .frame(height: 28)
        }
    }

    private func stepCircle(step: Int) -> some View {
        ZStack {
            if step < currentStep {
                Circle().fill(Color(red: 0.15, green: 0.60, blue: 0.22)).frame(width: circleSize, height: circleSize)
                Text("\(step)").font(.urbanistBold(12)).foregroundColor(.white)
            } else if step == currentStep {
                Circle().fill(Color(red: 0.92, green: 0.86, blue: 0.76)).frame(width: circleSize, height: circleSize)
                Circle().stroke(Color(red: 0.80, green: 0.72, blue: 0.60), lineWidth: 1.5).frame(width: circleSize, height: circleSize)
                Text("\(step)").font(.urbanistBold(12)).foregroundColor(Color(red: 0.5, green: 0.35, blue: 0.15))
            } else {
                Circle().fill(Color(red: 0.82, green: 0.82, blue: 0.82)).frame(width: circleSize, height: circleSize)
                Text("\(step)").font(.urbanistBold(12)).foregroundColor(.white)
            }
        }
        .frame(width: circleSize)
    }

    private func connectorLine(step: Int) -> some View {
        Rectangle()
            .fill(step < currentStep ? Color(red: 0.15, green: 0.60, blue: 0.22) : Color(red: 0.80, green: 0.80, blue: 0.80))
            .frame(height: 2).frame(maxWidth: .infinity)
    }

    private func labelXPosition(index: Int, width: CGFloat) -> CGFloat {
        let connectorWidth = max(0, (width - (CGFloat(totalSteps) * circleSize)) / CGFloat(totalSteps - 1))
        let circleCenter = (circleSize / 2) + CGFloat(index) * (circleSize + connectorWidth)
        return min(max(circleCenter, labelWidth / 2), width - (labelWidth / 2))
    }

    private func labelFrameAlignment(for index: Int) -> Alignment {
        if index == 0 { return .leading }
        if index == totalSteps - 1 { return .trailing }
        return .center
    }

    private func labelTextAlignment(for index: Int) -> TextAlignment {
        if index == 0 { return .leading }
        if index == totalSteps - 1 { return .trailing }
        return .center
    }
}

#Preview {
    CustomerOrdersView(user: AppUser.mock)
        .environmentObject(NotificationManager())
}
