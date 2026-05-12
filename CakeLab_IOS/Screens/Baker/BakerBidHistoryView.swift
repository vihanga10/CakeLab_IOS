import SwiftUI
import Combine
import FirebaseFirestore
import UIKit

// MARK: - Baker Bid History
@MainActor
struct BakerBidHistoryView: View {
    let user: AppUser
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BakerBidHistoryViewModel()
    @State private var selectedItem: BakerBidHistoryItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cakeBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBar

                    if viewModel.isLoading {
                        Spacer()
                        ProgressView("Loading bid history...")
                            .tint(.cakeBrown)
                        Spacer()
                    } else if let errorMessage = viewModel.errorMessage {
                        emptyState(icon: "exclamationmark.circle", title: "Could Not Load Bids", message: errorMessage)
                    } else if viewModel.items.isEmpty {
                        emptyState(
                            icon: "tray",
                            title: "No Bid History",
                            message: "Requests you place bids on will move here from Matching Requests."
                        )
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 14) {
                                HStack {
                                    Text("\(viewModel.items.count) placed bid\(viewModel.items.count == 1 ? "" : "s")")
                                        .font(.urbanistRegular(13))
                                        .foregroundColor(.cakeGrey)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)

                                ForEach(viewModel.items) { item in
                                    Button {
                                        selectedItem = item
                                    } label: {
                                        BakerBidHistoryCard(item: item)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.top, 16)
                            .padding(.bottom, 104)
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedItem) { item in
                BakerBidHistoryDetailView(item: item)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.loadBidHistory(bakerID: user.id)
            }
            .refreshable {
                await viewModel.loadBidHistory(bakerID: user.id)
            }
        }
        .asBakerSubScreen()
    }

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cakeBrown)
            }

            Spacer()

            Text("Bid History")
                .font(.urbanistBold(18))
                .foregroundColor(Color(hex: "5D3714"))

            Spacer()

            Color.clear.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.cakeSurface)
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(Color.cakeGrey.opacity(0.5))
            Text(title)
                .font(.urbanistSemiBold(17))
                .foregroundColor(.cakeBrown)
            Text(message)
                .font(.urbanistRegular(13))
                .foregroundColor(.cakeGrey)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@MainActor
final class BakerBidHistoryViewModel: ObservableObject {
    @Published var items: [BakerBidHistoryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    func loadBidHistory(bakerID: String) async {
        let trimmedBakerID = bakerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBakerID.isEmpty else {
            items = []
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let bidSnapshot = try await db.collection("bids")
                .whereField("bakerID", isEqualTo: trimmedBakerID)
                .getDocuments()

            let requestIDs = Set(
                bidSnapshot.documents.compactMap { document in
                    document.data()["requestDocumentID"] as? String
                }
            )
            let bidIDs = Set(bidSnapshot.documents.map(\.documentID))
            let customerIDs = Set(
                bidSnapshot.documents.compactMap { document in
                    firstString(document.data()["customerID"], document.data()["customerId"])
                }.filter { !$0.isEmpty }
            )
            let openRequests = await loadAccessibleRequests(requestIDs: requestIDs)
            let directRequests = await loadDirectRequestDocuments(requestIDs: requestIDs)
            let accessibleRequests = openRequests.merging(directRequests) { current, direct in
                current.enriched(with: direct)
            }
            let accessibleOrders = await loadAccessibleOrders(
                bakerID: trimmedBakerID,
                requestIDs: requestIDs,
                bidIDs: bidIDs
            )
            let customerNames = await loadCustomerNames(customerIDs: customerIDs)
            var loadedItems: [BakerBidHistoryItem] = []

            for bidDocument in bidSnapshot.documents {
                let bidData = bidDocument.data()
                guard let bid = BakerBidHistoryBid(document: bidDocument) else { continue }
                let snapshotRequest = BakerBidHistoryRequest(bidData: bidData, bid: bid)
                let orderRequest = accessibleOrders[bid.requestDocumentID] ?? accessibleOrders[bid.id]
                let request = (accessibleRequests[bid.requestDocumentID] ?? snapshotRequest)
                    .enriched(
                        with: orderRequest,
                        customerNameOverride: customerNames[bid.customerID]
                    )
                loadedItems.append(BakerBidHistoryItem(bid: bid, request: request))
            }

            items = loadedItems.sorted { $0.bid.submittedAt > $1.bid.submittedAt }
        } catch {
            errorMessage = error.localizedDescription
            items = []
        }

        isLoading = false
    }

    private func loadAccessibleRequests(requestIDs: Set<String>) async -> [String: BakerBidHistoryRequest] {
        guard !requestIDs.isEmpty else { return [:] }

        var result: [String: BakerBidHistoryRequest] = [:]
        let statuses = ["open"]

        for status in statuses {
            do {
                let snapshot = try await db.collection("cakeRequests")
                    .whereField("status", isEqualTo: status)
                    .getDocuments()

                for document in snapshot.documents {
                    guard requestIDs.contains(document.documentID),
                          let record = CakeRequestRecord(document: document) else { continue }
                    result[document.documentID] = BakerBidHistoryRequest(record: record)
                }
            } catch {
                print("Bid history could not load \(status) request records: \(error.localizedDescription)")
            }
        }

        return result
    }

    private func loadDirectRequestDocuments(requestIDs: Set<String>) async -> [String: BakerBidHistoryRequest] {
        guard !requestIDs.isEmpty else { return [:] }

        var result: [String: BakerBidHistoryRequest] = [:]
        for requestID in requestIDs {
            do {
                let snapshot = try await db.collection("cakeRequests").document(requestID).getDocument()
                guard let record = CakeRequestRecord(document: snapshot) else { continue }
                result[requestID] = BakerBidHistoryRequest(record: record)
            } catch {
                print("Bid history could not load request \(requestID): \(error.localizedDescription)")
            }
        }

        return result
    }

    private func loadAccessibleOrders(
        bakerID: String,
        requestIDs: Set<String>,
        bidIDs: Set<String>
    ) async -> [String: BakerBidHistoryRequest] {
        guard !requestIDs.isEmpty || !bidIDs.isEmpty else { return [:] }

        var result: [String: BakerBidHistoryRequest] = [:]
        var seenOrderIDs: Set<String> = []

        for key in ["bakerID", "bakerId", "artisanId"] {
            do {
                let snapshot = try await db.collection("orders")
                    .whereField(key, isEqualTo: bakerID)
                    .getDocuments()

                for document in snapshot.documents where !seenOrderIDs.contains(document.documentID) {
                    let data = document.data()
                    let requestID = firstString(data["requestDocumentID"], data["cakeRequestID"], data["requestID"])
                    let bidID = firstString(data["bidID"], data["acceptedBidID"])
                    let matchesRequest = (!requestID.isEmpty && requestIDs.contains(requestID))
                        || requestIDs.contains { document.documentID.hasPrefix("\($0)_") }
                    let matchesBid = (!bidID.isEmpty && bidIDs.contains(bidID))
                        || bidIDs.contains(document.documentID)

                    guard matchesRequest || matchesBid else { continue }

                    let request = BakerBidHistoryRequest(orderID: document.documentID, orderData: data)
                    if !requestID.isEmpty {
                        result[requestID] = request
                    }
                    if !bidID.isEmpty {
                        result[bidID] = request
                    }
                    result[document.documentID] = request
                    seenOrderIDs.insert(document.documentID)
                }
            } catch {
                print("Bid history could not load completed orders for \(key): \(error.localizedDescription)")
            }
        }

        return result
    }

    private func loadCustomerNames(customerIDs: Set<String>) async -> [String: String] {
        guard !customerIDs.isEmpty else { return [:] }

        var result: [String: String] = [:]
        for customerID in customerIDs {
            do {
                let snapshot = try await db.collection("users").document(customerID).getDocument()
                let data = snapshot.data() ?? [:]
                let name = firstString(data["name"], data["fullName"], data["email"])
                if !name.isEmpty {
                    result[customerID] = name
                }
            } catch {
                print("Bid history could not load customer \(customerID): \(error.localizedDescription)")
            }
        }
        return result
    }

    private func firstString(_ values: Any?...) -> String {
        values.compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }
}

struct BakerBidHistoryItem: Identifiable, Hashable {
    let bid: BakerBidHistoryBid
    let request: BakerBidHistoryRequest

    var id: String { bid.id }

    static func == (lhs: BakerBidHistoryItem, rhs: BakerBidHistoryItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct BakerBidHistoryRequest: Hashable {
    let id: String
    let title: String
    let description: String
    let customerName: String
    let customerCity: String
    let displayCategory: String
    let budgetText: String
    let expectedDateText: String
    let expectedTimeText: String
    let tier: Int
    let cakeSize: String
    let sugarLevel: Double
    let flavours: [String]
    let styles: [String]
    let dietary: [String]
    let fillingFlavour: String
    let specialInstructions: String
    let referenceImages: [String]

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Cake Request" : title
    }

    init(
        id: String,
        title: String,
        description: String,
        customerName: String,
        customerCity: String,
        displayCategory: String,
        budgetText: String,
        expectedDateText: String,
        expectedTimeText: String,
        tier: Int,
        cakeSize: String,
        sugarLevel: Double,
        flavours: [String],
        styles: [String],
        dietary: [String],
        fillingFlavour: String,
        specialInstructions: String,
        referenceImages: [String]
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.customerName = customerName
        self.customerCity = customerCity
        self.displayCategory = displayCategory
        self.budgetText = budgetText
        self.expectedDateText = expectedDateText
        self.expectedTimeText = expectedTimeText
        self.tier = tier
        self.cakeSize = cakeSize
        self.sugarLevel = sugarLevel
        self.flavours = flavours
        self.styles = styles
        self.dietary = dietary
        self.fillingFlavour = fillingFlavour
        self.specialInstructions = specialInstructions
        self.referenceImages = referenceImages
    }

    init(record: CakeRequestRecord) {
        self.id = record.id
        self.title = record.displayTitle
        self.description = record.description
        self.customerName = record.customerName
        self.customerCity = record.customerCity
        self.displayCategory = record.displayCategory
        self.budgetText = record.budgetText.replacingOccurrences(of: "Rs.", with: "LKR")
        self.expectedDateText = formattedDate(record.expectedDate)
        self.expectedTimeText = formattedTime(record.expectedTime)
        self.tier = record.tier
        self.cakeSize = record.cakeSize
        self.sugarLevel = record.sugarLevel
        self.flavours = record.flavours
        self.styles = record.styles
        self.dietary = record.dietary
        self.fillingFlavour = record.fillingFlavour
        self.specialInstructions = record.specialInstructions
        self.referenceImages = record.referenceImages
    }

    init(bidData: [String: Any], bid: BakerBidHistoryBid) {
        let snapshot = bidData["requestSnapshot"] as? [String: Any] ?? [:]
        self.id = Self.firstString(snapshot["id"], bid.requestDocumentID)
        self.title = Self.firstString(snapshot["title"], bidData["requestTitle"], bidData["cakeName"], "Cake Request")
        self.description = Self.firstString(snapshot["description"], bidData["description"], bidData["specialInstructions"], "Cake request details are not available for this older bid.")
        self.customerName = Self.firstString(snapshot["customerName"], bidData["customerName"], "Customer")
        self.customerCity = Self.firstString(snapshot["customerCity"], bidData["customerCity"], bidData["customerAddress"], "Customer Location")
        self.displayCategory = Self.firstString(snapshot["category"], bidData["category"], "Custom Cake")
        self.budgetText = Self.firstString(snapshot["budgetText"], bidData["budgetText"], Self.budgetText(budgetMin: bidData["budgetMin"], budgetMax: bidData["budgetMax"], amount: bidData["amount"]), "Not specified")
        self.expectedDateText = Self.firstString(snapshot["expectedDateText"], bidData["expectedDateText"], Self.formattedDateText(bidData["expectedDate"]), "Not specified")
        self.expectedTimeText = Self.firstString(snapshot["expectedTimeText"], bidData["expectedTimeText"], Self.formattedTimeText(bidData["expectedTime"]), "Not specified")
        self.tier = Self.intValue(Self.firstValue(snapshot, bidData, keys: ["tier", "servings", "tiers"]))
        self.cakeSize = Self.firstString(snapshot["cakeSize"], bidData["cakeSize"])
        self.sugarLevel = Self.doubleValue(Self.firstValue(snapshot, bidData, keys: ["sugarLevel"]), defaultValue: 0.5)
        self.flavours = Self.stringArrayValue(Self.firstValue(snapshot, bidData, keys: ["flavours", "flavors"]))
        self.styles = Self.stringArrayValue(Self.firstValue(snapshot, bidData, keys: ["styles", "cakeStyles"]))
        self.dietary = Self.stringArrayValue(Self.firstValue(snapshot, bidData, keys: ["dietary", "dietaryRestrictions"]))
        self.fillingFlavour = Self.firstString(snapshot["fillingFlavour"], snapshot["fillingFlavor"], bidData["fillingFlavour"], bidData["fillingFlavor"])
        self.specialInstructions = Self.firstString(snapshot["specialInstructions"], bidData["specialInstructions"], bidData["notes"])
        self.referenceImages = Self.stringArrayValue(Self.firstValue(snapshot, bidData, keys: ["referenceImages", "images"]))
    }

    init(orderID: String, orderData: [String: Any]) {
        let snapshot = orderData["requestSnapshot"] as? [String: Any] ?? [:]
        let requestID = Self.firstString(orderData["requestDocumentID"], orderData["cakeRequestID"], orderData["requestID"], snapshot["id"])
        let budgetText = Self.budgetText(
            budgetMin: orderData["budgetMin"],
            budgetMax: orderData["budgetMax"],
            amount: orderData["amount"]
        )
        let orderReferenceImages = orderData["referenceImages"] as? [String] ?? []
        let snapshotReferenceImages = snapshot["referenceImages"] as? [String] ?? []

        self.id = requestID.isEmpty ? orderID : requestID
        self.title = Self.firstString(orderData["cakeName"], snapshot["title"], orderData["title"], "Cake Request")
        self.description = Self.firstString(
            snapshot["description"],
            orderData["description"],
            orderData["specialInstructions"],
            "Cake request details are not available for this older bid."
        )
        self.customerName = Self.firstString(snapshot["customerName"], orderData["customerName"], orderData["customerFullName"], "Customer")
        self.customerCity = Self.firstString(
            orderData["deliveryCity"],
            orderData["customerCity"],
            snapshot["customerCity"],
            orderData["deliveryAddress"],
            orderData["customerAddress"],
            "Customer Location"
        )
        self.displayCategory = Self.firstString(orderData["category"], snapshot["category"], "Custom Cake")
        self.budgetText = Self.firstString(snapshot["budgetText"], budgetText, "Not specified")
        self.expectedDateText = Self.firstString(
            Self.formattedDateText(orderData["deliveryDate"]),
            snapshot["expectedDateText"],
            "Not specified"
        )
        self.expectedTimeText = Self.firstString(
            Self.formattedTimeText(orderData["deliveryTime"]),
            Self.formattedTimeText(orderData["deliveryDateTime"]),
            snapshot["expectedTimeText"],
            "Not specified"
        )
        self.tier = Self.intValue(Self.firstValue(snapshot, orderData, keys: ["tier", "servings", "tiers"]))
        self.cakeSize = Self.firstString(snapshot["cakeSize"], orderData["cakeSize"])
        self.sugarLevel = Self.doubleValue(Self.firstValue(snapshot, orderData, keys: ["sugarLevel"]), defaultValue: 0.5)
        self.flavours = Self.stringArrayValue(Self.firstValue(snapshot, orderData, keys: ["flavours", "flavors"]))
        self.styles = Self.stringArrayValue(Self.firstValue(snapshot, orderData, keys: ["styles", "cakeStyles"]))
        self.dietary = Self.stringArrayValue(Self.firstValue(snapshot, orderData, keys: ["dietary", "dietaryRestrictions"]))
        self.fillingFlavour = Self.firstString(snapshot["fillingFlavour"], snapshot["fillingFlavor"], orderData["fillingFlavour"], orderData["fillingFlavor"])
        self.specialInstructions = Self.firstString(snapshot["specialInstructions"], orderData["specialInstructions"], orderData["notes"])
        self.referenceImages = orderReferenceImages.isEmpty ? snapshotReferenceImages : orderReferenceImages
    }

    func enriched(with fallback: BakerBidHistoryRequest?, customerNameOverride: String? = nil) -> BakerBidHistoryRequest {
        guard let fallback else {
            return withCustomerNameOverride(customerNameOverride)
        }

        return BakerBidHistoryRequest(
            id: Self.bestString(id, fallback.id),
            title: Self.bestString(title, fallback.title, defaultValue: "Cake Request"),
            description: Self.bestDescription(description, fallback.description),
            customerName: Self.bestCustomerName(customerNameOverride, customerName, fallback.customerName),
            customerCity: Self.bestString(customerCity, fallback.customerCity, defaultValue: "Customer Location"),
            displayCategory: Self.bestString(displayCategory, fallback.displayCategory, defaultValue: "Custom Cake"),
            budgetText: Self.bestSpecifiedString(budgetText, fallback.budgetText),
            expectedDateText: Self.bestSpecifiedString(expectedDateText, fallback.expectedDateText),
            expectedTimeText: Self.bestSpecifiedString(expectedTimeText, fallback.expectedTimeText),
            tier: tier > 0 ? tier : fallback.tier,
            cakeSize: Self.bestSpecifiedString(cakeSize, fallback.cakeSize),
            sugarLevel: hasCakeCustomizationDetails ? sugarLevel : fallback.sugarLevel,
            flavours: flavours.isEmpty ? fallback.flavours : flavours,
            styles: styles.isEmpty ? fallback.styles : styles,
            dietary: dietary.isEmpty ? fallback.dietary : dietary,
            fillingFlavour: Self.bestSpecifiedString(fillingFlavour, fallback.fillingFlavour),
            specialInstructions: Self.bestSpecifiedString(specialInstructions, fallback.specialInstructions),
            referenceImages: referenceImages.isEmpty ? fallback.referenceImages : referenceImages
        )
    }

    private var hasCakeCustomizationDetails: Bool {
        tier > 0 ||
            !cakeSize.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !flavours.isEmpty ||
            !styles.isEmpty ||
            !dietary.isEmpty ||
            !fillingFlavour.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !specialInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func withCustomerNameOverride(_ override: String?) -> BakerBidHistoryRequest {
        BakerBidHistoryRequest(
            id: id,
            title: title,
            description: description,
            customerName: Self.bestCustomerName(override, customerName),
            customerCity: customerCity,
            displayCategory: displayCategory,
            budgetText: budgetText,
            expectedDateText: expectedDateText,
            expectedTimeText: expectedTimeText,
            tier: tier,
            cakeSize: cakeSize,
            sugarLevel: sugarLevel,
            flavours: flavours,
            styles: styles,
            dietary: dietary,
            fillingFlavour: fillingFlavour,
            specialInstructions: specialInstructions,
            referenceImages: referenceImages
        )
    }

    private static func firstString(_ values: Any?...) -> String {
        values.compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    private static func firstValue(_ primary: [String: Any], _ fallback: [String: Any], keys: [String]) -> Any? {
        for key in keys {
            if let value = primary[key] { return value }
        }
        for key in keys {
            if let value = fallback[key] { return value }
        }
        return nil
    }

    private static func stringArrayValue(_ value: Any?) -> [String] {
        if let values = value as? [String] {
            return values
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        if let values = value as? [Any] {
            return values.compactMap { $0 as? String }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        if let value = value as? String {
            return value
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        return []
    }

    private static func bestString(_ primary: String, _ fallback: String, defaultValue: String = "") -> String {
        let primary = primary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !primary.isEmpty { return primary }
        let fallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? defaultValue : fallback
    }

    private static func bestSpecifiedString(_ primary: String, _ fallback: String) -> String {
        let primary = primary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !primary.isEmpty && primary != "Not specified" { return primary }
        let fallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fallback.isEmpty && fallback != "Not specified" { return fallback }
        return "Not specified"
    }

    private static func bestCustomerName(_ values: String?...) -> String {
        for value in values {
            let candidate = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !candidate.isEmpty && candidate != "Customer" {
                return candidate
            }
        }
        return "Customer"
    }

    private static func bestDescription(_ primary: String, _ fallback: String) -> String {
        let unavailable = "Cake request details are not available for this older bid."
        let primary = primary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !primary.isEmpty && primary != unavailable && primary != "No description provided." {
            return primary
        }

        let fallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fallback.isEmpty && fallback != unavailable && fallback != "No description provided." {
            return fallback
        }

        return unavailable
    }

    private static func budgetText(budgetMin: Any?, budgetMax: Any?, amount: Any?) -> String {
        let min = doubleValue(budgetMin)
        let max = doubleValue(budgetMax)
        if min > 0 && max > 0 {
            return "LKR \(Int(min).formatted()) - \(Int(max).formatted())"
        }

        let amount = doubleValue(amount)
        if amount > 0 {
            return "LKR \(Int(amount).formatted())"
        }

        return ""
    }

    private static func formattedDateText(_ value: Any?) -> String {
        guard let date = dateValue(value) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }

    private static func formattedTimeText(_ value: Any?) -> String {
        guard let date = dateValue(value) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: date)
    }

    private static func dateValue(_ value: Any?) -> Date? {
        if let value = value as? Timestamp { return value.dateValue() }
        if let value = value as? Date { return value }
        if let value = value as? NSNumber { return Date(timeIntervalSince1970: value.doubleValue) }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) ?? 0 }
        return 0
    }

    private static func doubleValue(_ value: Any?, defaultValue: Double = 0) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) ?? defaultValue }
        return defaultValue
    }
}

struct BakerBidHistoryBid: Identifiable, Hashable {
    let id: String
    let requestDocumentID: String
    let customerID: String
    let bakerID: String
    let bakerName: String
    let amount: Double
    let message: String
    let deliveryNote: String
    let canDeliverOnTime: Bool
    let alternativeDate: Date?
    let submittedAt: Date
    let status: String

    init?(document: DocumentSnapshot) {
        let data = document.data() ?? [:]
        let requestDocumentID = (data["requestDocumentID"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestDocumentID.isEmpty else { return nil }

        self.id = document.documentID
        self.requestDocumentID = requestDocumentID
        self.customerID = data["customerID"] as? String ?? ""
        self.bakerID = data["bakerID"] as? String ?? ""
        self.bakerName = data["bakerName"] as? String ?? "Baker"
        self.amount = Self.doubleValue(data["amount"])
        self.message = data["message"] as? String ?? ""
        self.deliveryNote = data["deliveryNote"] as? String ?? ""
        self.canDeliverOnTime = data["canDeliverOnTime"] as? Bool ?? true
        self.alternativeDate = Self.dateValue(data["alternativeDate"])
        self.submittedAt = Self.dateValue(data["submittedAt"]) ?? Date()
        self.status = data["status"] as? String ?? "submitted"
    }

    private static func doubleValue(_ value: Any?) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String {
            let cleaned = value.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(cleaned) ?? 0
        }
        return 0
    }

    private static func dateValue(_ value: Any?) -> Date? {
        if let value = value as? Timestamp { return value.dateValue() }
        if let value = value as? Date { return value }
        if let value = value as? NSNumber { return Date(timeIntervalSince1970: value.doubleValue) }
        return nil
    }
}

private struct BakerBidHistoryCard: View {
    let item: BakerBidHistoryItem

    private var request: BakerBidHistoryRequest { item.request }
    private var bid: BakerBidHistoryBid { item.bid }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                requestImage

                VStack(alignment: .leading, spacing: 7) {
                    Text(request.displayTitle)
                        .font(.urbanistBold(15))
                        .foregroundColor(.cakePrimaryText)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Label(request.customerName, systemImage: "person.fill")
                        Spacer()
                        Label(request.customerCity.isEmpty ? "Customer Location" : request.customerCity, systemImage: "mappin.and.ellipse")
                    }
                    .font(.urbanistRegular(11))
                    .foregroundColor(.cakeGrey)

                    HStack(spacing: 8) {
                        statusChip
                        Spacer()
                        Text(Self.submittedFormatter.string(from: bid.submittedAt))
                            .font(.urbanistRegular(11))
                            .foregroundColor(.cakeGrey)
                    }
                }
            }

            Divider()

            HStack {
                metric(label: "Bid Amount", value: "LKR \(Int(bid.amount).formatted())")
                Divider().frame(height: 34)
                metric(label: "Budget", value: request.budgetText)
                Divider().frame(height: 34)
                metric(label: "Delivery", value: request.expectedDateText)
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
    }

    private var requestImage: some View {
        Group {
            if let firstImage = request.referenceImages.first,
               let imageData = Data(base64Encoded: firstImage),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.cakeBrown.opacity(0.12))
                    Image(systemName: categoryIcon(for: request.displayCategory))
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.cakeBrown)
                }
            }
        }
        .frame(width: 78, height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var statusChip: some View {
        Text(bid.status.capitalized)
            .font(.urbanistMedium(11))
            .foregroundColor(.cakeBrown)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.cakeBrown.opacity(0.1))
            .cornerRadius(6)
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.urbanistRegular(10))
                .foregroundColor(.cakeGrey)
            Text(value)
                .font(.urbanistBold(12))
                .foregroundColor(.cakePrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let submittedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter
    }()
}

private struct BakerBidHistoryDetailView: View {
    let item: BakerBidHistoryItem
    @Environment(\.dismiss) private var dismiss

    private var request: BakerBidHistoryRequest { item.request }
    private var bid: BakerBidHistoryBid { item.bid }

    var body: some View {
        ZStack {
            Color.cakeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        summarySection
                        cakeDetailsSection
                        bidDetailsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cakeBrown)
            }

            Spacer()

            Text("Bid Details")
                .font(.urbanistBold(18))
                .foregroundColor(Color(hex: "5D3714"))

            Spacer()

            Color.clear.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.cakeSurface)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(request.displayTitle)
                .font(.urbanistBold(20))
                .foregroundColor(.cakePrimaryText)

            Text(request.description.isEmpty ? "No description provided." : request.description)
                .font(.urbanistRegular(14))
                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                .lineSpacing(4)

            HStack(spacing: 10) {
                summaryChip(icon: "person.fill", text: request.customerName)
                summaryChip(icon: "birthday.cake.fill", text: request.displayCategory)
            }
        }
        .padding(18)
        .background(Color.cakeSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private var cakeDetailsSection: some View {
        detailSection(title: "Cake Details") {
            detailRow(label: "Customer Location", value: request.customerCity.isEmpty ? "Customer Location" : request.customerCity)
            detailRow(label: "Delivery Date", value: request.expectedDateText)
            detailRow(label: "Delivery Time", value: request.expectedTimeText)
            detailRow(label: "Budget", value: request.budgetText)
            detailRow(label: "Tiers", value: request.tier > 0 ? "\(request.tier)" : "Not specified")
            detailRow(label: "Cake Size", value: fallback(request.cakeSize))
            detailRow(label: "Sugar Level", value: "\(Int((request.sugarLevel * 100).rounded()))%")
            detailRow(label: "Flavours", value: joined(request.flavours))
            detailRow(label: "Styles", value: joined(request.styles))
            detailRow(label: "Dietary", value: joined(request.dietary))
            detailRow(label: "Filling Flavour", value: fallback(request.fillingFlavour))
            detailRow(label: "Special Instructions", value: fallback(request.specialInstructions))
        }
    }

    private var bidDetailsSection: some View {
        detailSection(title: "Bid Details") {
            detailRow(label: "Bid Amount", value: "LKR \(Int(bid.amount).formatted())")
            detailRow(label: "Status", value: bid.status.capitalized)
            detailRow(label: "Submitted", value: Self.dateTimeFormatter.string(from: bid.submittedAt))
            detailRow(
                label: "Delivery Promise",
                value: bid.canDeliverOnTime
                    ? "Can deliver on requested date"
                    : "Alternative: \(bid.alternativeDate.map { formattedDate($0) } ?? "Not provided")"
            )
            detailRow(label: "Message to Customer", value: fallback(bid.message))
            detailRow(label: "Delivery Note", value: fallback(bid.deliveryNote))
        }
    }

    private func detailSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.urbanistBold(16))
                .foregroundColor(.cakePrimaryText)

            content()
        }
        .padding(18)
        .background(Color.cakeSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.urbanistRegular(11))
                .foregroundColor(.cakeGrey)
            Text(value)
                .font(.urbanistSemiBold(13))
                .foregroundColor(.cakePrimaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.cakeInsetSurface)
        .cornerRadius(12)
    }

    private func summaryChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
        }
        .font(.urbanistMedium(12))
        .foregroundColor(.cakeBrown)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.cakeBrown.opacity(0.1))
        .cornerRadius(8)
    }

    private func fallback(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not specified" : trimmed
    }

    private func joined(_ values: [String]) -> String {
        let cleaned = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return cleaned.isEmpty ? "Not specified" : cleaned.joined(separator: ", ")
    }

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy 'at' h:mm a"
        return formatter
    }()
}
