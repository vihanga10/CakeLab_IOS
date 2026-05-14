import Foundation
import FirebaseFirestore

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

