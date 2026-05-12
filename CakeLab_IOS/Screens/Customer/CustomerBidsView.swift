import SwiftUI
import Combine
import FirebaseFirestore

extension Notification.Name {
    static let orderDidChange = Notification.Name("orderDidChange")
}

enum PaymentMethod: String, CaseIterable {
    case card = "Card"
    case cash = "Cash"
    case googlePay = "Google Pay"
    case applePay = "Apple Pay"
}

struct PaymentPayload {
    let method: PaymentMethod
    let cardholderName: String
    let cardLast4: String
    let deliveryAddress: String
    let deliveryCity: String
}

struct CustomerBidRequest: Identifiable {
    let id: String
    let customerID: String
    let customerName: String
    let title: String
    let category: String
    let categories: [String]
    let location: String
    let customerAddress: String
    let budgetMin: Double
    let budgetMax: Double
    let expectedDate: Date
    let expectedTime: Date
    let bidCount: Int
    let createdAt: Date
    let description: String
    let styles: [String]
    let dietary: [String]
    let tier: Int
    let cakeSize: String
    let sugarLevel: Double
    let flavours: [String]
    let fillingFlavour: String
    let specialInstructions: String
    let allowNearby: Bool
    let status: String
    let isDirectRequest: Bool
    let targetArtisanID: String?
    let targetArtisanName: String?
    let referenceImages: [String]
}

struct CustomerBidOffer: Identifiable {
    let id: String
    let bakerID: String
    let bakerName: String
    let bakerProfileImageBase64: String
    let bakerImageURL: String
    let bakerAddress: String
    let bakerCity: String
    let amount: Double
    let message: String
    let canDeliverOnTime: Bool
    let deliveryDate: Date?
    let submittedAt: Date
    let status: String
}

enum BidsReceivedSheet: Identifiable {
    case payment(CustomerBidOffer)
    case bidDetails(CustomerBidOffer)

    var id: String {
        switch self {
        case .payment(let bid):
            return "payment_\(bid.id)"
        case .bidDetails(let bid):
            return "details_\(bid.id)"
        }
    }
}

@MainActor
final class CustomerBidsViewModel: ObservableObject {
    @Published var requests: [CustomerBidRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    func loadRequests(customerID: String) async {
        isLoading = true
        errorMessage = nil

        do {
            async let primary = db.collection("cakeRequests")
                .whereField("customerID", isEqualTo: customerID)
                .getDocuments()
            async let legacy = db.collection("cakeRequests")
                .whereField("customerId", isEqualTo: customerID)
                .getDocuments()

            let (primarySnap, legacySnap) = try await (primary, legacy)
            var mergedDocs: [String: DocumentSnapshot] = [:]
            for document in primarySnap.documents {
                mergedDocs[document.documentID] = document
            }
            for document in legacySnap.documents {
                mergedDocs[document.documentID] = document
            }

            let parsed = mergedDocs.values
                .compactMap(Self.parseRequest)
                .filter { request in
                    !Self.isClosedRequestStatus(request.status)
                }
            requests = parsed.sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = "Failed to load requests with bids. \(error.localizedDescription)"
        }

        isLoading = false
    }

    private static func parseRequest(document: DocumentSnapshot) -> CustomerBidRequest? {
        guard let data = document.data() else { return nil }

        let expectedDate = parseDate(data["expectedDate"]) ?? Date()
        let expectedTime = parseDate(data["expectedTime"]) ?? expectedDate
        let createdAt = parseDate(data["createdAt"]) ?? Date()

        return CustomerBidRequest(
            id: document.documentID,
            customerID: (data["customerID"] as? String) ?? (data["customerId"] as? String) ?? "",
            customerName: data["customerName"] as? String ?? "Customer",
            title: data["title"] as? String ?? "Cake Request",
            category: data["category"] as? String ?? "Custom Cake",
            categories: data["categories"] as? [String] ?? [],
            location: data["customerCity"] as? String ?? data["customerAddress"] as? String ?? "Customer Location",
            customerAddress: data["customerAddress"] as? String ?? "",
            budgetMin: parseDouble(data["budgetMin"]),
            budgetMax: parseDouble(data["budgetMax"]),
            expectedDate: expectedDate,
            expectedTime: expectedTime,
            bidCount: parseInt(data["bidCount"]),
            createdAt: createdAt,
            description: data["description"] as? String ?? "",
            styles: data["styles"] as? [String] ?? [],
            dietary: data["dietary"] as? [String] ?? [],
            tier: parseInt(data["tier"]),
            cakeSize: data["cakeSize"] as? String ?? "",
            sugarLevel: parseDouble(data["sugarLevel"]),
            flavours: data["flavours"] as? [String] ?? [],
            fillingFlavour: data["fillingFlavour"] as? String ?? "",
            specialInstructions: data["specialInstructions"] as? String ?? "",
            allowNearby: data["allowNearby"] as? Bool ?? false,
            status: data["status"] as? String ?? "open",
            isDirectRequest: data["isDirectRequest"] as? Bool ?? false,
            targetArtisanID: data["targetArtisanId"] as? String,
            targetArtisanName: data["targetArtisanName"] as? String,
            referenceImages: data["referenceImages"] as? [String] ?? []
        )
    }

    private static func isClosedRequestStatus(_ status: String) -> Bool {
        let normalized = status.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized == "confirmed" ||
            normalized == "paid" ||
            normalized == "completed" ||
            normalized == "in_progress"
    }

    private static func parseDate(_ raw: Any?) -> Date? {
        if let ts = raw as? Timestamp { return ts.dateValue() }
        if let seconds = raw as? TimeInterval { return Date(timeIntervalSince1970: seconds) }
        if let intSeconds = raw as? Int { return Date(timeIntervalSince1970: TimeInterval(intSeconds)) }
        return nil
    }

    private static func parseDouble(_ raw: Any?) -> Double {
        if let value = raw as? Double { return value }
        if let value = raw as? Int { return Double(value) }
        if let value = raw as? String { return Double(value) ?? 0 }
        return 0
    }

    private static func parseInt(_ raw: Any?) -> Int {
        if let value = raw as? Int { return value }
        if let value = raw as? Double { return Int(value) }
        if let value = raw as? String { return Int(value) ?? 0 }
        return 0
    }
}

@MainActor
final class BidsReceivedViewModel: ObservableObject {
    @Published var bids: [CustomerBidOffer] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    func loadBids(requestID: String, customerID: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await db.collection("bids")
                .whereField("customerID", isEqualTo: customerID)
                .getDocuments()

            let parsed = snapshot.documents
                .filter { $0.data()["requestDocumentID"] as? String == requestID }
                .compactMap(Self.parseBid)

            var enrichedBids: [CustomerBidOffer] = []
            for bid in parsed where !Self.isClosedBidStatus(bid.status) {
                enrichedBids.append(await enrichBidWithBakerProfile(bid))
            }

            bids = enrichedBids.sorted { $0.submittedAt > $1.submittedAt }
        } catch {
            errorMessage = "Failed to load bids. \(error.localizedDescription)"
        }

        isLoading = false
    }

    private static func parseBid(document: DocumentSnapshot) -> CustomerBidOffer? {
        guard let data = document.data() else { return nil }

        let submittedAt = parseDate(data["submittedAt"]) ?? Date()
        let alternativeDate = parseDate(data["alternativeDate"])
        let canDeliverOnTime = data["canDeliverOnTime"] as? Bool ?? true

        return CustomerBidOffer(
            id: document.documentID,
            bakerID: data["bakerID"] as? String ?? "",
            bakerName: data["bakerName"] as? String ?? "Baker",
            bakerProfileImageBase64: data["bakerProfileImageBase64"] as? String ?? "",
            bakerImageURL: data["bakerImageURL"] as? String ?? "",
            bakerAddress: data["bakerAddress"] as? String ?? "",
            bakerCity: data["bakerCity"] as? String ?? "",
            amount: parseDouble(data["amount"]),
            message: data["message"] as? String ?? "",
            canDeliverOnTime: canDeliverOnTime,
            deliveryDate: canDeliverOnTime ? nil : alternativeDate,
            submittedAt: submittedAt,
            status: data["status"] as? String ?? "submitted"
        )
    }

    private static func isClosedBidStatus(_ status: String) -> Bool {
        let normalized = status.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized == "accepted" || normalized == "paid" || normalized == "confirmed"
    }

    private func enrichBidWithBakerProfile(_ bid: CustomerBidOffer) async -> CustomerBidOffer {
        guard bid.bakerProfileImageBase64.isEmpty && bid.bakerImageURL.isEmpty else { return bid }

        let profileData = await fetchBakerProfileImageData(bakerID: bid.bakerID)
        return CustomerBidOffer(
            id: bid.id,
            bakerID: bid.bakerID,
            bakerName: bid.bakerName,
            bakerProfileImageBase64: profileData.base64,
            bakerImageURL: profileData.url,
            bakerAddress: profileData.address,
            bakerCity: profileData.city,
            amount: bid.amount,
            message: bid.message,
            canDeliverOnTime: bid.canDeliverOnTime,
            deliveryDate: bid.deliveryDate,
            submittedAt: bid.submittedAt,
            status: bid.status
        )
    }

    private func fetchBakerProfileImageData(bakerID: String) async -> (base64: String, url: String, address: String, city: String) {
        let trimmedID = bakerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return ("", "", "", "") }

        if let artisanDoc = try? await db.collection("artisans").document(trimmedID).getDocument(),
           let data = artisanDoc.data() {
            let base64 = data["profileImageBase64"] as? String ?? ""
            let url = data["imageURL"] as? String ?? data["avatarURL"] as? String ?? ""
            let address = data["address"] as? String ?? data["location"] as? String ?? ""
            let city = SriLankaDistricts.canonical(data["city"] as? String) ?? data["city"] as? String ?? ""
            if !base64.isEmpty || !url.isEmpty || !address.isEmpty || !city.isEmpty {
                return (base64, url, address, city)
            }
        }

        if let userDoc = try? await db.collection("users").document(trimmedID).getDocument(),
           let data = userDoc.data() {
            return (
                data["profileImageBase64"] as? String ?? "",
                data["imageURL"] as? String ?? data["avatarURL"] as? String ?? "",
                data["address"] as? String ?? "",
                SriLankaDistricts.canonical(data["city"] as? String) ?? data["city"] as? String ?? ""
            )
        }

        return ("", "", "", "")
    }

    private static func parseDate(_ raw: Any?) -> Date? {
        if let ts = raw as? Timestamp { return ts.dateValue() }
        if let seconds = raw as? TimeInterval { return Date(timeIntervalSince1970: seconds) }
        if let intSeconds = raw as? Int { return Date(timeIntervalSince1970: TimeInterval(intSeconds)) }
        return nil
    }

    private static func parseDouble(_ raw: Any?) -> Double {
        if let value = raw as? Double { return value }
        if let value = raw as? Int { return Double(value) }
        if let value = raw as? NSNumber { return value.doubleValue }
        if let value = raw as? String { return Double(value) ?? 0 }
        return 0
    }
}

struct CustomerBidsView: View {
    let user: AppUser
    @StateObject private var viewModel = CustomerBidsViewModel()
    @EnvironmentObject var notificationManager: NotificationManager

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh.mm a"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cakeBackground.ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("Loading your request bids...")
                        .tint(.cakeBrown)
                } else if viewModel.requests.isEmpty {
                    ContentUnavailableView(
                        "No Requests Yet",
                        systemImage: "tray",
                        description: Text("Publish a cake request to start receiving bids from bakers.")
                    )
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(viewModel.requests) { request in
                                CustomerBidRequestCard(
                                    request: request,
                                    user: user,
                                    dateText: Self.dateFormatter.string(from: request.expectedDate),
                                    timeText: Self.timeFormatter.string(from: request.expectedTime)
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Bids on My Requests")
                        .font(.urbanistBold(18))
                        .foregroundColor(Color(red: 93/255, green: 55/255, blue: 20/255))
                }
            }
            .task {
                await viewModel.loadRequests(customerID: user.id)
            }
            .refreshable {
                await viewModel.loadRequests(customerID: user.id)
            }
            .onReceive(NotificationCenter.default.publisher(for: .bidDidChange)) { _ in
                Task {
                    await viewModel.loadRequests(customerID: user.id)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .orderDidChange)) { _ in
                Task {
                    await viewModel.loadRequests(customerID: user.id)
                }
            }
        }
    }
}

struct CustomerBidRequestCard: View {
    let request: CustomerBidRequest
    let user: AppUser
    let dateText: String
    let timeText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                thumbnailView

                VStack(alignment: .leading, spacing: 0) {
                    Text(request.title)
                        .font(.urbanistSemiBold(14))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .padding(.top, 16)

                    categoryPill
                        .padding(.top, 9)

                    HStack(spacing: 12) {
                        compactMetric(icon: "calendar", label: "Date", value: dateText); footerDivider
                        compactMetric(icon: "banknote", label: "Budget", value: budgetText)
                    }
                    .padding(.top, 9)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                NavigationLink {
                    BidsReceivedView(request: request, user: user)
                } label: {
                    Text("View Bids Received (\(request.bidCount))")
                        .font(.urbanistSemiBold(12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.cakeBrown)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                NavigationLink {
                    PublishedCakeDetailView(request: request.toCakeRequestRecord())
                } label: {
                    Text("View Full Details")
                        .font(.urbanistSemiBold(12))
                        .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                        .padding(.vertical, 10)
                        .frame(width: 148)
                        .background(Color.cakeSurface)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 0.80, green: 0.80, blue: 0.80), lineWidth: 1.2)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 14)
            .padding(.bottom, 14)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: 358, alignment: .leading)
        .frame(height: 150)
        .background(Color.cakeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: 8)
    }

    private var thumbnailView: some View {
        Group {
            if !request.referenceImages.isEmpty,
               let imageData = Data(base64Encoded: request.referenceImages[0]),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 88)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                    .overlay(
                        Image(systemName: "birthday.cake.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.cakeBrown.opacity(0.7))
                    )
            }
        }
        .frame(width: 80, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        .padding(.top, 16)
    }

    private var categoryPill: some View {
        Text(displayCategory)
            .font(.urbanistMedium(11))
            .foregroundColor(categoryTextColor(for: displayCategory))
            .padding(.horizontal, 13)
            .frame(height: 22)
            .background(categoryBackgroundColor(for: displayCategory))
            .clipShape(Capsule())
    }

    private var footerDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.12))
            .frame(width: 1, height: 32)
    }


    private var budgetText: String {
        "Rs \(Int(request.budgetMin).formatted()) - \(Int(request.budgetMax).formatted())"
    }

    private var displayCategory: String {
        let trimmedCategory = request.category.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCategory.isEmpty {
            return trimmedCategory
        }
        return request.categories.first ?? "Custom Cake"
    }

    private func compactMetric(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(.systemGray))

                Text(label)
                    .font(.urbanistRegular(10))
                    .foregroundColor(Color(.systemGray))
            }

            Text(value)
                .font(.urbanistSemiBold(12))
                .foregroundColor(.black)
                .lineLimit(1)
        }
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
}

private extension CustomerBidRequest {
    func toCakeRequestRecord() -> CakeRequestRecord {
        CakeRequestRecord(
            id: id,
            title: title,
            description: description,
            customerID: customerID,
            customerName: customerName,
            customerCity: location,
            customerAddress: customerAddress,
            category: category,
            categories: categories,
            styles: styles,
            dietary: dietary,
            tier: tier,
            cakeSize: cakeSize,
            sugarLevel: sugarLevel,
            flavours: flavours,
            fillingFlavour: fillingFlavour,
            specialInstructions: specialInstructions,
            budgetMin: budgetMin,
            budgetMax: budgetMax,
            expectedDate: expectedDate,
            expectedTime: expectedTime,
            allowNearby: allowNearby,
            createdAt: createdAt,
            savedAt: nil,
            status: status,
            bidCount: bidCount,
            referenceImages: referenceImages,
            isDirectRequest: isDirectRequest,
            targetArtisanId: targetArtisanID,
            targetArtisanName: targetArtisanName
        )
    }
}

struct BidsReceivedView: View {
    let request: CustomerBidRequest
    let user: AppUser
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationManager: NotificationManager
    @StateObject private var viewModel = BidsReceivedViewModel()
    @State private var activeSheet: BidsReceivedSheet?
    @State private var isSubmittingPayment = false
    @State private var errorMessage: String?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh.mm a"
        return formatter
    }()

    var body: some View {
        ZStack {
            Color.cakeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        requestSummaryCard
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        if viewModel.isLoading {
                            ProgressView("Loading bids...")
                                .tint(.cakeBrown)
                                .padding(.top, 20)
                        } else if viewModel.bids.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "person.2.slash")
                                    .font(.system(size: 28, weight: .regular))
                                    .foregroundColor(.cakeBrown.opacity(0.35))

                                Text("No Bids Yet")
                                    .font(.urbanistSemiBold(15))
                                    .foregroundColor(.cakeBrown)

                                Text("Bakers have not placed bids for this request yet.")
                                    .font(.urbanistRegular(12))
                                    .foregroundColor(.cakeGrey)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                        } else {
                            ForEach(viewModel.bids) { bid in
                                BakerBidOfferCard(
                                    bid: bid,
                                    onAcceptBid: {
                                        activeSheet = .payment(bid)
                                    },
                                    onViewBidDetails: {
                                        activeSheet = .bidDetails(bid)
                                    }
                                )
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isSubmittingPayment {
                ZStack {
                    Color.black.opacity(0.22).ignoresSafeArea()
                    ProgressView("Processing payment...")
                        .padding(22)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                }
            }
        }
        .task {
            await viewModel.loadBids(requestID: request.id, customerID: request.customerID)
        }
        .refreshable {
            await viewModel.loadBids(requestID: request.id, customerID: request.customerID)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .payment(let bid):
                PaymentCheckoutView(request: request, bid: bid, user: user) { payload in
                    Task {
                        await processAcceptedBid(bid: bid, payment: payload)
                    }
                }
            case .bidDetails(let bid):
                BidFullDetailsSheet(request: request, bid: bid)
            }
        }
        .alert("Payment Failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .asCustomerSubScreen()
    }

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cakeBrown)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("Bids Received")
                    .font(.urbanistBold(18))
                    .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
            }
            Spacer()
            Color.white.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.cakeSurface)
    }

    private func processAcceptedBid(bid: CustomerBidOffer, payment: PaymentPayload) async {
        isSubmittingPayment = true
        defer { isSubmittingPayment = false }

        let db = Firestore.firestore()
        let orderID = "\(request.id)_\(bid.bakerID)"
        let orderRef = db.collection("orders").document(orderID)
        let paymentRef = db.collection("payments").document()
        let requestRef = db.collection("cakeRequests").document(request.id)
        let bidRef = db.collection("bids").document(bid.id)

        let finalDeliveryDate = bid.canDeliverOnTime ? request.expectedDate : (bid.deliveryDate ?? request.expectedDate)
        let deliveryDateTime = mergeDateAndTime(date: finalDeliveryDate, time: request.expectedTime)
        let serviceFee = 250.0
        let totalPaid = bid.amount + serviceFee
        let requestSnapshot: [String: Any] = [
            "id": request.id,
            "title": request.title,
            "description": request.description,
            "customerName": request.customerName,
            "customerCity": request.location,
            "category": request.category,
            "budgetText": "LKR \(Int(request.budgetMin).formatted()) - \(Int(request.budgetMax).formatted())",
            "expectedDateText": Self.dateFormatter.string(from: request.expectedDate),
            "expectedTimeText": Self.timeFormatter.string(from: request.expectedTime),
            "tier": request.tier,
            "cakeSize": request.cakeSize,
            "sugarLevel": request.sugarLevel,
            "flavours": request.flavours,
            "styles": request.styles,
            "dietary": request.dietary,
            "fillingFlavour": request.fillingFlavour,
            "specialInstructions": request.specialInstructions,
            "referenceImages": request.referenceImages
        ]

        let orderData: [String: Any] = [
            "customerId": request.customerID,
            "artisanId": bid.bakerID,
            "bakerID": bid.bakerID,
            "bakerId": bid.bakerID,
            "cakeName": request.title,
            "category": request.category,
            "categories": request.category.isEmpty ? [] : [request.category],
            "description": request.description,
            "styles": request.styles,
            "dietary": request.dietary,
            "tier": request.tier,
            "cakeSize": request.cakeSize,
            "sugarLevel": request.sugarLevel,
            "flavours": request.flavours,
            "fillingFlavour": request.fillingFlavour,
            "specialInstructions": request.specialInstructions,
            "budgetMin": request.budgetMin,
            "budgetMax": request.budgetMax,
            "status": "confirmed",
            "currentStep": 1,
            "deliveryDate": Timestamp(date: finalDeliveryDate),
            "deliveryTime": Timestamp(date: request.expectedTime),
            "deliveryDateTime": Timestamp(date: deliveryDateTime),
            "deliveryAddress": payment.deliveryAddress,
            "deliveryCity": payment.deliveryCity,
            "customerAddress": payment.deliveryAddress,
            "customerCity": payment.deliveryCity,
            "artisanName": bid.bakerName,
            "artisanRating": "New baker",
            "artisanAddress": "Address not provided",
            "imageURL": "",
            "referenceImages": request.referenceImages,
            "createdAt": Timestamp(date: Date()),
            "requestDocumentID": request.id,
            "bidID": bid.id,
            "requestSnapshot": requestSnapshot,
            "amount": bid.amount,
            "paymentStatus": "paid",
            "selected": true
        ]

        let paymentData: [String: Any] = [
            "orderID": orderID,
            "requestDocumentID": request.id,
            "bidID": bid.id,
            "cakeName": request.title,
            "customerId": request.customerID,
            "customerID": request.customerID,
            "customerName": request.customerName,
            "bakerId": bid.bakerID,
            "bakerID": bid.bakerID,
            "bakerName": bid.bakerName,
            "amount": bid.amount,
            "serviceFee": serviceFee,
            "total": totalPaid,
            "method": payment.method.rawValue,
            "cardholderName": payment.cardholderName,
            "cardLast4": payment.cardLast4,
            "deliveryAddress": payment.deliveryAddress,
            "deliveryCity": payment.deliveryCity,
            "status": "success",
            "createdAt": Timestamp(date: Date())
        ]

        do {
            let batch = db.batch()
            batch.setData(orderData, forDocument: orderRef, merge: true)
            batch.setData(paymentData, forDocument: paymentRef)
            batch.updateData([
                "status": "confirmed",
                "acceptedBidID": bid.id,
                "acceptedBakerID": bid.bakerID,
                "selectedPrice": bid.amount,
                "updatedAt": Timestamp(date: Date())
            ], forDocument: requestRef)
            batch.updateData([
                "status": "accepted",
                "orderID": orderID,
                "requestSnapshot": requestSnapshot,
                "updatedAt": Timestamp(date: Date())
            ], forDocument: bidRef)

            try await batch.commit()

            // Trigger notifications
            // Notify CUSTOMER: Order Confirmed
            self.notificationManager.notifyOrderConfirmed(
                bakerName: bid.bakerName,
                deliveryDate: finalDeliveryDate,
                orderID: orderID,
                customerID: request.customerID
            )
            print(" Customer notified: Order confirmed with \(bid.bakerName)")

            self.notificationManager.notifyPaymentReceipt(
                amount: totalPaid,
                bakerName: bid.bakerName,
                orderID: orderID,
                customerID: request.customerID
            )
            print(" Customer notified: Payment receipt saved for \(request.title)")
            
            // Notify BAKER: Order Confirmed  
            self.notificationManager.notifyBakerOrderConfirmed(
                customerName: self.user.name.isEmpty ? self.user.email : self.user.name,
                requestTitle: request.title,
                deliveryDate: finalDeliveryDate,
                orderID: orderID,
                customerID: request.customerID,
                bakerID: bid.bakerID,
                showPopup: false
            )
            print(" Baker notified: Order confirmed for \(request.title)")

            self.notificationManager.notifyBakerPaymentReceived(
                customerName: self.user.name.isEmpty ? self.user.email : self.user.name,
                amount: bid.amount,
                orderID: orderID,
                customerID: request.customerID,
                bakerID: bid.bakerID,
                showPopup: false
            )
            print(" Baker notified: Payment received for \(request.title)")

            activeSheet = nil
            viewModel.bids.removeAll { $0.id == bid.id }
            NotificationCenter.default.post(name: .bidDidChange, object: nil)
            NotificationCenter.default.post(name: .orderDidChange, object: nil)
            WidgetDataSyncManager.shared.refreshFromCurrentSession()

            await self.viewModel.loadBids(requestID: request.id, customerID: request.customerID)
        } catch {
            errorMessage = "Could not complete payment. \(error.localizedDescription)"
        }
    }

    private func mergeDateAndTime(date: Date, time: Date) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = .current

        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)

        var merged = DateComponents()
        merged.year = dateComponents.year
        merged.month = dateComponents.month
        merged.day = dateComponents.day
        merged.hour = timeComponents.hour ?? 10
        merged.minute = timeComponents.minute ?? 0
        merged.second = timeComponents.second ?? 0

        return calendar.date(from: merged) ?? date
    }

    private var requestSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(request.title)
                .font(.urbanistBold(16))
                .foregroundColor(.cakePrimaryText)

            HStack(spacing: 10) {
                Label(Self.dateFormatter.string(from: request.expectedDate), systemImage: "calendar")
                Text("|").foregroundColor(Color.black.opacity(0.25))
                Label(Self.timeFormatter.string(from: request.expectedTime).lowercased(), systemImage: "clock")
            }
            .font(.urbanistSemiBold(13))
            .foregroundColor(.cakeGrey)

            Text("Budget (LKR) : \(Int(request.budgetMin).formatted()) - \(Int(request.budgetMax).formatted())")
                .font(.urbanistSemiBold(14))
                .foregroundColor(Color(red: 93/255, green: 55/255, blue: 20/255))

            Text(request.description)
                .font(.urbanistRegular(13))      
                .foregroundColor(.cakeGrey)    
                .lineLimit(3)
        }
        .padding(16)
        .background(Color.cakeSurface)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
    }
}

struct BakerBidOfferCard: View {
    let bid: CustomerBidOffer
    let onAcceptBid: () -> Void
    let onViewBidDetails: () -> Void

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh.mm a"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                bakerProfileImage

                VStack(alignment: .leading, spacing: 3) {
                    Text(bid.bakerName)
                        .font(.urbanistBold(16))
                        .foregroundColor(.cakePrimaryText)

                    Text("Bid placed on \(Self.dateFormatter.string(from: bid.submittedAt)) at \(Self.timeFormatter.string(from: bid.submittedAt).lowercased())")
                        .font(.urbanistRegular(11))
                        .foregroundColor(.cakeGrey)
                }
                Spacer()
            }

            Divider()

            detailsRow(label: "Bid Amount", value: "LKR \(Int(bid.amount).formatted())")

            detailsRow(
                label: "Delivery",
                value: bid.canDeliverOnTime
                ? "Can deliver on requested date"
                : "Alternative: \(bid.deliveryDate.map { Self.dateFormatter.string(from: $0) } ?? "Not provided")",
                valueColor: .gray
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Message from baker")
                    .font(.urbanistSemiBold(13))
                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                Text(previewMessage(bid.message))
                    .font(.urbanistRegular(13))
                    .foregroundColor(.cakeGrey)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                Button(action: onAcceptBid) {
                    Text("Accept Bid")
                        .font(.urbanistSemiBold(13))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.cakeBrown)
                        .clipShape(Capsule())
                }

                Button(action: onViewBidDetails) {
                    Text("View Bid Details")
                        .font(.urbanistSemiBold(13))
                        .foregroundColor(.cakeGrey)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.cakeSurface)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.cakeGrey, lineWidth: 1.2)
                        )
                }
            }
        }
        .padding(14)
        .background(Color.cakeSurface)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
    }

    private var bakerProfileImage: some View {
        Group {
            if let image = decodeBase64Image(bid.bakerProfileImageBase64) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = URL(string: bid.bakerImageURL), !bid.bakerImageURL.isEmpty {
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
        .frame(width: 52, height: 52)
        .clipShape(Circle())
    }

    private var bakerProfileFallback: some View {
        Circle()
            .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.cakeBrown.opacity(0.75))
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

    private func detailsRow(label: String, value: String, valueColor: Color = Color(red: 93/255, green: 55/255, blue: 20/255)) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.urbanistRegular(14))
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                .frame(width: 88, alignment: .leading)
            Text(": \(value)")
                .font(.urbanistSemiBold(14))
                .foregroundColor(valueColor)
            Spacer()
        }
    }

    private func previewMessage(_ text: String) -> String {
        let words = text
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace)

        guard !words.isEmpty else { return "No message provided." }

        let truncated = words.prefix(20).joined(separator: " ")
        return words.count > 20 ? truncated + "..." : truncated
    }
}

struct PaymentCheckoutView: View {
    let request: CustomerBidRequest
    let bid: CustomerBidOffer
    let user: AppUser
    let onPay: (PaymentPayload) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMethod: PaymentMethod = .card
    @State private var cardNumber = ""
    @State private var cardholderName = ""
    @State private var expiry = ""
    @State private var cvv = ""
    @State private var deliveryAddress = ""
    @State private var deliveryCity = ""
    @State private var showDeliveryLocationSheet = false

    private var serviceFee: Double { 250 }
    private var totalAmount: Double { bid.amount + serviceFee }
    
    private var displayAddress: String {
        let address = deliveryAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let city = deliveryCity.trimmingCharacters(in: .whitespacesAndNewlines)
        if !address.isEmpty && !city.isEmpty {
            return "\(address), \(city)"
        } else if !address.isEmpty {
            return address
        } else if !city.isEmpty {
            return city
        }
        return "-"
    }

    var body: some View {
        ZStack {
            Color.cakeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        paymentSummaryCard
                        paymentMethodCard

                        if selectedMethod == .card {
                            cardDetailsCard
                        }

                        warningMessage

                        Button {
                            onPay(
                                PaymentPayload(
                                    method: selectedMethod,
                                    cardholderName: cardholderName.isEmpty ? "Cardholder" : cardholderName,
                                    cardLast4: String(cardNumber.suffix(4)),
                                    deliveryAddress: deliveryAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                                    deliveryCity: deliveryCity.trimmingCharacters(in: .whitespacesAndNewlines)
                                )
                            )
                        } label: {
                            Text("Pay LKR \(Int(totalAmount).formatted())")
                                .font(.urbanistBold(16))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color.cakeBrown)
                                .clipShape(Capsule())
                        }
                        .disabled(!isValidPayment)
                        .opacity(isValidPayment ? 1 : 0.45)
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
        .onAppear {
            if deliveryAddress.isEmpty {
                deliveryAddress = user.address ?? ""
                deliveryCity = user.city ?? ""
            }
        }
            }
        }
        .sheet(isPresented: $showDeliveryLocationSheet) {
            EditDeliveryLocationSheet(
                userID: user.id,
                address: $deliveryAddress,
                city: $deliveryCity,
                isPresented: $showDeliveryLocationSheet
            )
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
            VStack(spacing: 2) {
                Text("Checkout")
                    .font(.urbanistBold(18))
                    .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
            }
            Spacer()
            Color.white.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.cakeSurface)
    }

    private var isValidPayment: Bool {
        switch selectedMethod {
        case .applePay, .cash, .googlePay:
            return true
        case .card:
            return cardNumber.count >= 12 && !cardholderName.isEmpty && expiry.count >= 4 && cvv.count >= 3
        }
    }

    private var paymentSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Delivery Location Section
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.cakeBrown)
                        Text("Delivery Location")
                            .font(.urbanistSemiBold(13))
                            .foregroundColor(.cakePrimaryText)
                    }
                    Text(displayAddress)
                        .font(.urbanistRegular(12))
                        .foregroundColor(.cakeGrey)
                }
                Spacer()
                Button(action: { showDeliveryLocationSheet = true }) {
                    Text("Change")
                        .font(.urbanistSemiBold(12))
                        .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.93, green: 0.91, blue: 0.88))
                        .cornerRadius(6)
                }
            }
            .padding(12)
            .background(Color(red: 0.98, green: 0.98, blue: 0.98))
            .cornerRadius(10)

            Divider()
                .padding(.vertical, 4)

            // Payment Summary
            VStack(alignment: .leading, spacing: 10) {
                summaryRow(label: "Sub Total (LKR)", value: "LKR \(Int(bid.amount).formatted())")
                summaryRow(label: "Delivery Fee (LKR)", value: "LKR \(Int(serviceFee).formatted())")
                
                Divider()
                    .padding(.vertical, 4)
                
                summaryRow(label: "Total Cost (LKR)", value: "LKR \(Int(totalAmount).formatted())", isBold: true)
            }
        }
        .padding(16)
        .background(Color.cakeSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private var paymentMethodCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment Method")
                .font(.urbanistBold(15))
                .foregroundColor(.cakePrimaryText)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    methodChip(.card, icon: "creditcard.fill")
                    methodChip(.cash, icon: "banknote.fill", label: "Cash")
                }
                HStack(spacing: 10) {
                    methodChip(.googlePay, icon: "g.circle.fill", label: "Google Pay")
                    methodChip(.applePay, icon: "applelogo", label: "Apple Pay")
                }
            }
        }
        .padding(16)
        .background(Color.cakeSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private var cardDetailsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Card Details")
                .font(.urbanistBold(15))
                .foregroundColor(.cakePrimaryText)

            formField(title: "Card Number", placeholder: "4000 1234 5678 9010", text: $cardNumber)
            formField(title: "Cardholder Name", placeholder: "Your name", text: $cardholderName)

            HStack(spacing: 10) {
                formField(title: "Expiry", placeholder: "MM/YY", text: $expiry)
                formField(title: "CVV", placeholder: "123", text: $cvv)
            }
        }
        .padding(16)
        .background(Color.cakeSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private func methodChip(_ method: PaymentMethod, icon: String, label: String? = nil) -> some View {
        Button {
            selectedMethod = method
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(label ?? method.rawValue)
                    .font(.urbanistSemiBold(13))
            }
            .foregroundColor(selectedMethod == method ? .white : Color(red: 0.72, green: 0.72, blue: 0.72))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(selectedMethod == method ? Color.cakeBrown : Color(red: 0.94, green: 0.94, blue: 0.95))
            .cornerRadius(10)
        }
    }

    private func summaryRow(label: String, value: String, isBold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(isBold ? .urbanistSemiBold(14) : .urbanistRegular(13))
                .foregroundColor(Color(red: 0.32, green: 0.32, blue: 0.32))
            Spacer()
            Text(value)
                .font(isBold ? .urbanistBold(15) : .urbanistSemiBold(14))
                .foregroundColor(Color(red: 93/255, green: 55/255, blue: 20/255))
        }
    }

    private var warningMessage: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(Color(.systemGray))
            Text("Before proceeding to payment, please review your order details.")
                .font(.urbanistRegular(12))
                .foregroundColor(Color(.systemGray))
            Spacer()
        }
        .padding(12)
        .background(Color(red: 0.96, green: 0.96, blue: 0.96))
        .cornerRadius(10)
    }

    private func formField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.urbanistRegular(12))
                .foregroundColor(.cakeGrey)
            TextField(placeholder, text: text)
                .font(.urbanistMedium(14))
                .padding(12)
                .background(Color(red: 0.97, green: 0.97, blue: 0.98))
                .cornerRadius(10)
        }
    }
}

struct EditDeliveryLocationSheet: View {
    let userID: String
    @Binding var address: String
    @Binding var city: String
    @Binding var isPresented: Bool
    @State private var tempAddress = ""
    @State private var tempCity = ""
    @State private var showDistrictPicker = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cakeBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBar

                    VStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Address")
                                .font(.urbanistSemiBold(12))
                                .foregroundColor(.cakeGrey)
                            TextField("Enter your address", text: $tempAddress)
                                .font(.urbanistRegular(14))
                                .padding(12)
                                .background(Color(red: 0.97, green: 0.97, blue: 0.98))
                                .cornerRadius(10)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("City")
                                .font(.urbanistSemiBold(12))
                                .foregroundColor(.cakeGrey)
                            Button {
                                showDistrictPicker = true
                            } label: {
                                HStack(spacing: 10) {
                                    Text(tempCity.isEmpty ? "Select city" : tempCity)
                                        .font(.urbanistRegular(14))
                                        .foregroundColor(tempCity.isEmpty ? Color(hex: "7D7D7D") : Color(red: 0.1, green: 0.1, blue: 0.1))
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.cakeBrown)
                                }
                                .padding(12)
                                .background(Color(red: 0.97, green: 0.97, blue: 0.98))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.urbanistRegular(12))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.08))
                                .cornerRadius(10)
                        }

                        Spacer()

                        Button {
                            Task { await saveLocation() }
                        } label: {
                            Group {
                                if isSaving {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .tint(.white)
                                        Text("Saving...")
                                    }
                                } else {
                                    Text("Save Location")
                                }
                            }
                            .font(.urbanistBold(16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.cakeBrown)
                            .cornerRadius(14)
                        }
                        .disabled(!canSave || isSaving)
                        .opacity(canSave && !isSaving ? 1 : 0.5)
                    }
                    .padding(16)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showDistrictPicker) {
                DistrictPickerSheet(
                    districts: SriLankaDistricts.all,
                    selectedDistrict: tempCity.isEmpty ? nil : tempCity,
                    onSelect: { district in
                        tempCity = district
                        showDistrictPicker = false
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
        .onAppear {
            tempAddress = address
            tempCity = SriLankaDistricts.canonical(city) ?? city
        }
    }

    private var canSave: Bool {
        !tempAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !tempCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var headerBar: some View {
        HStack {
            Button { isPresented = false } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cakeBrown)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("Edit Delivery Location")
                    .font(.urbanistBold(18))
                    .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
            }
            Spacer()
            Color.clear.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.cakeSurface)
    }

    private func saveLocation() async {
        let savedAddress = tempAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedCity = SriLankaDistricts.canonical(tempCity) ?? tempCity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !savedAddress.isEmpty, !savedCity.isEmpty else { return }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await Firestore.firestore().collection("users").document(userID).setData([
                "address": savedAddress,
                "city": savedCity
            ], merge: true)

            address = savedAddress
            city = savedCity
            NotificationCenter.default.post(name: NSNotification.Name("customerProfileDidChange"), object: nil)
            isPresented = false
        } catch {
            errorMessage = "Could not save delivery location. \(error.localizedDescription)"
        }
    }
}

private struct DistrictPickerSheet: View {
    let districts: [String]
    let selectedDistrict: String?
    let onSelect: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(districts, id: \.self) { district in
                    Button {
                        onSelect(district)
                    } label: {
                        HStack {
                            Text(district)
                                .font(.urbanistMedium(15))
                                .foregroundColor(.cakePrimaryText)
                            Spacer()
                            if selectedDistrict == district {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.cakeBrown)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select City")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct BidFullDetailsSheet: View {
    let request: CustomerBidRequest
    let bid: CustomerBidOffer
    @Environment(\.dismiss) private var dismiss

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh.mm a"
        return formatter
    }()

    var body: some View {
        ZStack {
            Color.cakeBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerBar
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        heroCard
                        
                        detailCard(
                            icon: "doc.text",
                            title: "Cake Request",
                            value: request.title
                        )
                        detailCard(
                            icon: "person.circle.fill",
                            title: "Baker",
                            value: bid.bakerName
                        )
                        detailCard(
                            icon: "mappin.circle.fill",
                            title: "Baker Location",
                            value: bakerLocationText
                        )
                        detailCard(
                            icon: "banknote.fill",
                            title: "Bid Amount",
                            value: "LKR \(Int(bid.amount).formatted())"
                        )
                        detailCard(
                            icon: "calendar",
                            title: "Delivery Commitment",
                            value: bid.canDeliverOnTime
                            ? "Can deliver on requested date"
                            : "Alternative: \(bid.deliveryDate.map { Self.dateFormatter.string(from: $0) } ?? "Not provided")"
                        )
                        detailCard(
                            icon: "bubble.left.fill",
                            title: "Message",
                            value: bid.message.isEmpty ? "No message provided." : bid.message
                        )
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cakeBrown)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("Bid Details")
                    .font(.urbanistBold(18))
                    .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
            }
            Spacer()
            Color.white.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.cakeSurface)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                bakerProfileImage
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(bid.bakerName)
                        .font(.urbanistBold(15))
                        .foregroundColor(.cakePrimaryText)
                    Text("Bid placed on \(Self.dateFormatter.string(from: bid.submittedAt)) at \(Self.timeFormatter.string(from: bid.submittedAt).lowercased())")
                        .font(.urbanistRegular(12))
                        .foregroundColor(.cakeGrey)
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                        Text(bakerLocationText)
                            .lineLimit(1)
                    }
                    .font(.urbanistRegular(11))
                    .foregroundColor(.cakeGrey)
                }
                Spacer()
            }
            
            Divider()
            
            HStack(spacing: 14) {
                summaryItemCard(label: "Bid Amount", value: "LKR \(Int(bid.amount).formatted())")
                summaryItemCard(label: "Delivery", value: bid.canDeliverOnTime ? "On Time" : "Alternative")
            }
        }
        .padding(14)
        .background(Color.cakeSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
    }

    private var bakerProfileImage: some View {
        Group {
            if let image = decodeBase64Image(bid.bakerProfileImageBase64) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = URL(string: bid.bakerImageURL), !bid.bakerImageURL.isEmpty {
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
        .frame(width: 48, height: 48)
        .clipShape(Circle())
    }

    private var bakerProfileFallback: some View {
        Circle()
            .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
            )
    }

    private var bakerLocationText: String {
        let display = SriLankaDistricts.displayLocation(address: bid.bakerAddress, city: bid.bakerCity)
        return display.isEmpty ? "Address not provided" : display
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
    
    private func summaryItemCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.urbanistRegular(11))
                .foregroundColor(.cakeGrey)
            Text(value)
                .font(.urbanistSemiBold(13))
                .foregroundColor(.cakePrimaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
        .cornerRadius(12)
    }

    private func detailCard(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
                    .frame(width: 32, height: 32)
                    .background(Color(red: 0.98, green: 0.96, blue: 0.93))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                Text(title)
                    .font(.urbanistSemiBold(13))
                    .foregroundColor(.cakeGrey)
                
                Spacer()
            }
            
            Text(value)
                .font(.urbanistRegular(14))
                .foregroundColor(.cakePrimaryText)
                .lineLimit(4)
        }
        .padding(12)
        .background(Color.cakeSurface)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    CustomerBidsView(user: AppUser.mock)
}
