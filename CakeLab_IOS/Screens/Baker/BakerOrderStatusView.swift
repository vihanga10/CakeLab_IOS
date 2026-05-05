import SwiftUI
import Combine
import FirebaseFirestore
import UIKit

struct OrderPartyDetails {
    let name: String
    let phone: String
    let address: String
    let notes: String
}

@MainActor
final class BakerOrderStatusViewModel: ObservableObject {
    @Published var order: CakeOrder?
    @Published var selectedStep = 1
    @Published var isLoading = true
    @Published var isSaving = false
    @Published var successMessage: String?
    @Published var errorMessage: String?
    @Published var progressTimestamps: [String: Date] = [:]
    @Published var createdAt: Date?
    @Published var partyDetails = OrderPartyDetails(
        name: "Customer",
        phone: "Not provided",
        address: "Not provided",
        notes: "No special notes"
    )

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    let steps: [(step: Int, statusKey: String, title: String)] = [
        (1, "confirmed", "Confirmed"),
        (2, "baking", "Baking"),
        (3, "decorating", "Decorating"),
        (4, "quality_check", "Quality Checking"),
        (5, "delivered", "Delivered")
    ]

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
                self.errorMessage = "Unable to load order. \(error.localizedDescription)"
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
            self.selectedStep = max(1, min(5, order.currentStep))
            self.createdAt = Self.parseDate(data["createdAt"])
            self.progressTimestamps = Self.parseProgressTimestamps(data["progressTimestamps"])

            Task {
                await self.loadPartyDetails(order: order, data: data)
            }

            self.isLoading = false
        }
    }

    func updateStatus(orderID: String) async {
        guard !isSaving else { return }
        guard let stepInfo = steps.first(where: { $0.step == selectedStep }) else { return }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            var updates: [String: Any] = [
                "currentStep": stepInfo.step,
                "status": stepInfo.statusKey,
                "updatedAt": FieldValue.serverTimestamp(),
                "progressTimestamps.\(stepInfo.statusKey)": FieldValue.serverTimestamp()
            ]

            if stepInfo.statusKey == "delivered" {
                updates["completedAt"] = FieldValue.serverTimestamp()
            }

            try await db.collection("orders").document(orderID).updateData(updates)
            NotificationCenter.default.post(name: .orderDidChange, object: nil)
            WidgetDataSyncManager.shared.refreshFromCurrentSession()
            successMessage = "Order status updated to \(stepInfo.title)."
        } catch {
            errorMessage = "Failed to update order status. \(error.localizedDescription)"
        }
    }

    func timestamp(for statusKey: String) -> Date? {
        progressTimestamps[statusKey]
    }

    private func loadPartyDetails(order: CakeOrder, data: [String: Any]) async {
        let fallbackName    = (data["customerName"]    as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackPhone   = (data["customerPhone"]   as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackAddress = (data["customerAddress"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackNotes   = (data["notes"]           as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? (data["specialNotes"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let userSnapshot = try await db.collection("users").document(order.customerId).getDocument()
            let userData = userSnapshot.data() ?? [:]

            let profileName    = (userData["name"]        as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let profilePhone   = (userData["phoneNumber"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let profileAddress = (userData["address"]     as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let profileCity    = (userData["city"]        as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

            let composedAddress: String? = {
                if let a = profileAddress, !a.isEmpty, let c = profileCity, !c.isEmpty { return "\(a), \(c)" }
                if let a = profileAddress, !a.isEmpty { return a }
                if let c = profileCity, !c.isEmpty { return c }
                return nil
            }()

            partyDetails = OrderPartyDetails(
                name:    profileName?.isEmpty    == false ? profileName!    : (fallbackName?.isEmpty    == false ? fallbackName!    : order.customerId),
                phone:   profilePhone?.isEmpty   == false ? profilePhone!   : (fallbackPhone?.isEmpty   == false ? fallbackPhone!   : "Not provided"),
                address: composedAddress         ?? (fallbackAddress?.isEmpty == false ? fallbackAddress! : "Not provided"),
                notes:   fallbackNotes?.isEmpty  == false ? fallbackNotes!  : "No special notes"
            )
        } catch {
            partyDetails = OrderPartyDetails(
                name:    fallbackName?.isEmpty    == false ? fallbackName!    : order.customerId,
                phone:   fallbackPhone?.isEmpty   == false ? fallbackPhone!   : "Not provided",
                address: fallbackAddress?.isEmpty == false ? fallbackAddress! : "Not provided",
                notes:   fallbackNotes?.isEmpty   == false ? fallbackNotes!   : "No special notes"
            )
        }
    }

    private static func parseDate(_ raw: Any?) -> Date? {
        if let ts = raw as? Timestamp { return ts.dateValue() }
        if let s  = raw as? TimeInterval { return Date(timeIntervalSince1970: s) }
        if let s  = raw as? Int          { return Date(timeIntervalSince1970: TimeInterval(s)) }
        return nil
    }

    private static func parseProgressTimestamps(_ raw: Any?) -> [String: Date] {
        guard let map = raw as? [String: Any] else { return [:] }
        var result: [String: Date] = [:]
        for (key, value) in map {
            if let date = parseDate(value) { result[key] = date }
        }
        return result
    }
}

// MARK: - Baker Order Status View
struct BakerOrderStatusView: View {
    let orderID: String

    @StateObject private var viewModel = BakerOrderStatusViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var calendarAlert: BakerCalendarAlert?

    private let surface = Color.white
    private let accent  = Color.cakeBrown

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy"; return f
    }()
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "hh:mm a"; return f
    }()

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                if viewModel.isLoading {
                    ProgressView("Loading order...")
                        .tint(.cakeBrown)
                        .frame(maxHeight: .infinity)
                } else if let error = viewModel.errorMessage, viewModel.order == nil {
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
                } else if let order = viewModel.order {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            orderDetailsCard(order: order)
                            progressEditorCard(order: order)
                            customerInfoCard
                        }
                        .padding(.horizontal, 15)
                        .padding(.top, 14)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            viewModel.startListening(orderID: orderID)
        }
        .alert("Updated", isPresented: Binding(
            get: { viewModel.successMessage != nil },
            set: { if !$0 { viewModel.successMessage = nil } }
        )) {
            Button("OK") { viewModel.successMessage = nil }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.order != nil && viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert(item: $calendarAlert) { alert in
            switch alert {
            case .success(let msg):
                return Alert(title: Text("Added to Calendar"), message: Text(msg), dismissButton: .default(Text("OK")))
            case .error(let msg):
                return Alert(title: Text("Calendar Error"), message: Text(msg), dismissButton: .default(Text("OK")))
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

    // MARK: - Custom Header (matches CustomerOrderStatusView)
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

    // MARK: - Order Details Card (matches CustomerOrderStatusView.orderDetailsCard)
    private func orderDetailsCard(order: CakeOrder) -> some View {
        let displayCategory  = resolvedCategory(order.category)
        let deliveryDateText = Self.dateFmt.string(from: order.deliveryDate)

        return VStack(alignment: .leading, spacing: 0) {

            // ── Top row: thumbnail + Order ID / status / cake name ──────
            HStack(alignment: .top, spacing: 12) {
                cakeThumbnail(referenceImages: order.referenceImages, imageURLString: order.imageURL)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 10) {
                        Text("Order ID: \(orderID.uppercased())")
                            .font(.urbanistBold(12))
                            .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
                            .lineLimit(2)
                        Spacer(minLength: 6)
                        Text(order.statusLabel)
                            .font(.urbanistMedium(12))
                            .foregroundColor(order.statusColor)
                            .padding(.horizontal, 18)
                            .frame(height: 25)
                            .background(order.statusColor.opacity(0.18))
                            .clipShape(Capsule())
                    }
                    .padding(.top, 4)

                    Text(order.cakeName)
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

            // ── Footer: Date | Budget | Category ───────────────────────
            HStack(alignment: .center, spacing: 0) {

                // Date
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar").font(.system(size: 13, weight: .medium))
                        Text("Date").font(.urbanistRegular(11))
                    }
                    .foregroundColor(.cakeGrey)
                    Text(formattedHeaderDate(deliveryDateText))
                        .font(.urbanistMedium(11))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 2).padding(.bottom, 4)

                Rectangle().fill(Color(red: 0.9, green: 0.9, blue: 0.9)).frame(width: 1, height: 58)

                // Budget
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "banknote").font(.system(size: 13, weight: .medium))
                        Text("Budget").font(.urbanistRegular(11))
                    }
                    .foregroundColor(.cakeGrey)
                    Text(order.budgetMin > 0 && order.budgetMax > 0
                         ? "Rs \(Int(order.budgetMin).formatted()) – \(Int(order.budgetMax).formatted())"
                         : "N/A")
                        .font(.urbanistMedium(10.5))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 2).padding(.bottom, 4)

                Rectangle().fill(Color(red: 0.9, green: 0.9, blue: 0.9)).frame(width: 1, height: 58)

                // Category
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "tag").font(.system(size: 13, weight: .medium))
                        Text("Category").font(.urbanistRegular(11))
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
                .padding(.top, 2).padding(.bottom, 4)
            }
            .frame(height: 58, alignment: .top)
            .padding(.horizontal, 9)
            .padding(.bottom, 10)
        }
        .frame(width: 363, height: 156)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.07), radius: 12, x: 0, y: 4)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black.opacity(0.04), lineWidth: 1))
        .frame(maxWidth: .infinity)
    }

    // MARK: - Progress Editor Card
    private func progressEditorCard(order: CakeOrder) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Step timeline (tappable — baker can select step) ────────
            ForEach(viewModel.steps, id: \.step) { item in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(circleColor(for: item.step))
                                .frame(width: 36, height: 36)
                            Circle()
                                .fill(Color.white.opacity(item.step == viewModel.selectedStep ? 0.9 : 0.0))
                                .frame(width: 16, height: 16)
                            if item.step < viewModel.selectedStep {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        if item.step < viewModel.steps.count {
                            Rectangle()
                                .fill(Color(red: 0.78, green: 0.78, blue: 0.78))
                                .frame(width: 1.2, height: 48)
                                .padding(.top, 4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(item.title)
                                .font(item.step == viewModel.selectedStep ? .urbanistBold(15) : .urbanistMedium(15))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            Spacer()
                            if item.step == viewModel.selectedStep {
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

                        if item.step < viewModel.steps.count {
                            Divider().padding(.top, 10).padding(.bottom, 8)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) { viewModel.selectedStep = item.step }
                }
            }

            // ── Expected Date / Time (matches CustomerOrderStatusView) ──
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Expected Date")
                        .font(.urbanistSemiBold(12)).foregroundColor(accent)
                    Text(Self.dateFmt.string(from: order.deliveryDate))
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
                        .font(.urbanistSemiBold(12)).foregroundColor(accent)
                    Text(expectedTimeText(for: order).lowercased())
                        .font(.urbanistBold(14))
                        .foregroundColor(Color(red: 0.08, green: 0.08, blue: 0.08))
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(.top, 14)

            // ── Add to Calendar ─────────────────────────────────────────
            Button {
                Task { await addDeliveryEventToCalendar(order: order) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar").font(.system(size: 12, weight: .semibold))
                    Text("Add Delivery to Calendar").font(.urbanistSemiBold(14))
                }
                .foregroundColor(accent)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(Color(red: 0.92, green: 0.90, blue: 0.87))
                .cornerRadius(19)
            }
            .padding(.top, 14)

            // ── Update button (baker-specific backend action) ───────────
            Button {
                Task { await viewModel.updateStatus(orderID: order.id) }
            } label: {
                if viewModel.isSaving {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text("Updating...").font(.urbanistBold(15))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                } else {
                    Text("Update")
                        .font(.urbanistBold(15))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
            }
            .background(accent)
            .cornerRadius(18)
            .disabled(viewModel.isSaving)
            .opacity(viewModel.isSaving ? 0.8 : 1.0)
            .padding(.top, 16)
        }
        .padding(16)
        .background(surface)
        .cornerRadius(22)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
    }

    // MARK: - Customer Info Card
    private var customerInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            detailRow(icon: "person.fill",         title: "Name",             value: viewModel.partyDetails.name)
            detailRow(icon: "mappin.circle.fill",  title: "Delivery Address", value: viewModel.partyDetails.address)
            detailRow(icon: "phone.fill",          title: "Phone",            value: viewModel.partyDetails.phone)
            detailRow(icon: "text.bubble.fill",    title: "Special Notes",    value: viewModel.partyDetails.notes)
        }
        .padding(16)
        .background(surface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Cake Thumbnail (matches CustomerOrderStatusView)
    @ViewBuilder
    private func cakeThumbnail(referenceImages: [String], imageURLString: String?) -> some View {
        let size: CGFloat = 80
        Group {
            if let first = referenceImages.first,
               let data  = Data(base64Encoded: first),
               let img   = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
            } else if let urlStr = imageURLString, !urlStr.isEmpty, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: thumbnailPlaceholder
                    }
                }
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

    // MARK: - Step helpers
    private func stepDateText(step: Int, statusKey: String) -> String {
        if step == 1, let d = viewModel.timestamp(for: statusKey) ?? viewModel.createdAt {
            return Self.dateFmt.string(from: d)
        }
        guard let d = viewModel.timestamp(for: statusKey) else { return "Pending" }
        return Self.dateFmt.string(from: d)
    }

    private func stepTimeText(step: Int, statusKey: String) -> String {
        if step == 1, let d = viewModel.timestamp(for: statusKey) ?? viewModel.createdAt {
            return Self.timeFmt.string(from: d)
        }
        guard let d = viewModel.timestamp(for: statusKey) else { return "Pending" }
        return Self.timeFmt.string(from: d)
    }

    private func circleColor(for step: Int) -> Color {
        if step < viewModel.selectedStep  { return Color(red: 0.14, green: 0.58, blue: 0.34) }
        if step == viewModel.selectedStep { return accent }
        return Color(red: 0.78, green: 0.78, blue: 0.78)
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.cakeBrown)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.urbanistRegular(11)).foregroundColor(.cakeGrey)
                Text(value).font(.urbanistMedium(14)).foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            }
        }
    }

    // MARK: - Category colours (matches CustomerOrderStatusView)
    private func categoryBackgroundColor(for category: String) -> Color {
        switch category.lowercased() {
        case let c where c.contains("wedding"):     return Color(red: 1.0,  green: 0.95, blue: 0.97)
        case let c where c.contains("birthday"):    return Color(red: 0.99, green: 0.95, blue: 0.90)
        case let c where c.contains("anniversary"): return Color(red: 0.95, green: 0.99, blue: 0.95)
        case let c where c.contains("baby"):        return Color(red: 0.98, green: 0.96, blue: 1.0)
        case let c where c.contains("cupcake"):     return Color(red: 1.0,  green: 0.98, blue: 0.94)
        case let c where c.contains("buttercream"): return Color(red: 0.99, green: 1.0,  blue: 0.95)
        case let c where c.contains("corporate"):   return Color(red: 0.95, green: 0.98, blue: 1.0)
        case let c where c.contains("engagement"):  return Color(red: 1.0,  green: 0.96, blue: 0.92)
        case let c where c.contains("graduation"):  return Color(red: 0.94, green: 0.97, blue: 1.0)
        case let c where c.contains("baptism"):     return Color(red: 0.96, green: 0.99, blue: 1.0)
        case let c where c.contains("retirement"):  return Color(red: 1.0,  green: 0.96, blue: 0.94)
        case let c where c.contains("farewell"):    return Color(red: 0.98, green: 0.97, blue: 1.0)
        case let c where c.contains("vegan"):       return Color(red: 0.96, green: 1.0,  blue: 0.96)
        case let c where c.contains("sculpted"):    return Color(red: 0.98, green: 0.95, blue: 0.99)
        default:                                    return Color(red: 0.96, green: 0.96, blue: 0.96)
        }
    }

    private func categoryTextColor(for category: String) -> Color {
        switch category.lowercased() {
        case let c where c.contains("wedding"):     return Color(red: 0.8,  green: 0.3,  blue: 0.6)
        case let c where c.contains("birthday"):    return Color(red: 0.85, green: 0.5,  blue: 0.25)
        case let c where c.contains("anniversary"): return Color(red: 0.2,  green: 0.6,  blue: 0.4)
        case let c where c.contains("baby"):        return Color(red: 0.6,  green: 0.3,  blue: 0.8)
        case let c where c.contains("cupcake"):     return Color(red: 0.8,  green: 0.5,  blue: 0.2)
        case let c where c.contains("buttercream"): return Color(red: 0.7,  green: 0.6,  blue: 0.1)
        case let c where c.contains("corporate"):   return Color(red: 0.2,  green: 0.5,  blue: 0.8)
        case let c where c.contains("engagement"):  return Color(red: 0.85, green: 0.35, blue: 0.3)
        case let c where c.contains("graduation"):  return Color(red: 0.3,  green: 0.5,  blue: 0.7)
        case let c where c.contains("baptism"):     return Color(red: 0.2,  green: 0.6,  blue: 0.7)
        case let c where c.contains("retirement"):  return Color(red: 0.8,  green: 0.4,  blue: 0.3)
        case let c where c.contains("farewell"):    return Color(red: 0.5,  green: 0.3,  blue: 0.7)
        case let c where c.contains("vegan"):       return Color(red: 0.2,  green: 0.7,  blue: 0.2)
        case let c where c.contains("sculpted"):    return Color(red: 0.7,  green: 0.2,  blue: 0.7)
        default:                                    return Color(red: 0.4,  green: 0.4,  blue: 0.4)
        }
    }

    private func resolvedCategory(_ category: String) -> String {
        let t = category.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "No category" : t
    }

    // MARK: - Date / Time helpers
    private func formattedHeaderDate(_ raw: String) -> String {
        guard let d = parseHeaderDate(raw) else { return raw }
        let f = DateFormatter(); f.dateFormat = "dd MMM yyyy"; return f.string(from: d)
    }

    private func parseHeaderDate(_ raw: String) -> Date? {
        let patterns = ["dd/MM/yyyy", "dd/ MM/ yyyy", "d/M/yyyy", "dd MMM yyyy"]
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        for p in patterns {
            f.dateFormat = p
            if let d = f.date(from: raw.trimmingCharacters(in: .whitespacesAndNewlines)) { return d }
        }
        return nil
    }

    private func expectedTimeText(for order: CakeOrder) -> String {
        if let dt = order.deliveryDateTime { return Self.timeFmt.string(from: dt) }
        if let t  = order.deliveryTime     { return Self.timeFmt.string(from: t) }
        return "10:00 AM"
    }

    // MARK: - Calendar
    private func resolvedDeliveryStartDate(for order: CakeOrder) -> Date {
        if let dt = order.deliveryDateTime { return dt }
        if let t  = order.deliveryTime {
            var cal = Calendar.current; cal.timeZone = .current
            let day  = cal.dateComponents([.year, .month, .day], from: order.deliveryDate)
            let time = cal.dateComponents([.hour, .minute, .second], from: t)
            var merged = DateComponents()
            merged.year = day.year; merged.month = day.month; merged.day = day.day
            merged.hour = time.hour ?? 10; merged.minute = time.minute ?? 0; merged.second = time.second ?? 0
            return cal.date(from: merged) ?? order.deliveryDate
        }
        return order.deliveryDate
    }

    private func addDeliveryEventToCalendar(order: CakeOrder) async {
        let startDate = resolvedDeliveryStartDate(for: order)
        let noteLines = [
            "Order ID: \(order.id)",
            "Customer: \(viewModel.partyDetails.name)",
            "Address: \(viewModel.partyDetails.address)",
            "Notes: \(viewModel.partyDetails.notes)"
        ]
        do {
            _ = try await CalendarEventManager.shared.addOrUpdateDeliveryEvent(
                appUserID:  order.artisanId.isEmpty ? "baker_unknown" : order.artisanId,
                appUserName: order.artisanName,
                orderID:    order.id,
                eventTitle: "Cake Delivery - \(order.cakeName)",
                startDate:  startDate,
                endDate:    startDate.addingTimeInterval(3600),
                location:   viewModel.partyDetails.address,
                notes:      noteLines.joined(separator: "\n")
            )
            calendarAlert = .success("Delivery reminder has been added to your phone calendar.")
        } catch let error as CalendarEventManager.CalendarError {
            calendarAlert = error == .accessDenied ? .permissionDenied : .error(error.localizedDescription)
        } catch {
            calendarAlert = .error(error.localizedDescription)
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private enum BakerCalendarAlert: Identifiable {
    case success(String)
    case error(String)
    case permissionDenied

    var id: String {
        switch self {
        case .success(let m):  return "success_\(m)"
        case .error(let m):    return "error_\(m)"
        case .permissionDenied: return "permissionDenied"
        }
    }
}

#Preview {
    NavigationStack {
        BakerOrderStatusView(orderID: "order_001")
    }
}
