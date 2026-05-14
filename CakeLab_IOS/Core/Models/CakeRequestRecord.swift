import SwiftUI
import FirebaseFirestore

struct CakeRequestStatusBadge {
    let label: String
    let textColor: Color
    let bgColor: Color
}

struct CakeRequestRecord: Identifiable {
    let id: String
    let title: String
    let description: String
    let customerID: String
    let customerName: String
    let customerCity: String
    let customerAddress: String
    let category: String
    let categories: [String]
    let styles: [String]
    let dietary: [String]
    let tier: Int
    let cakeSize: String
    let sugarLevel: Double
    let flavours: [String]
    let fillingFlavour: String
    let specialInstructions: String
    let budgetMin: Double
    let budgetMax: Double
    let expectedDate: Date
    let expectedTime: Date
    let allowNearby: Bool
    let createdAt: Date
    let savedAt: Date?
    let status: String
    let bidCount: Int
    let isDirectRequest: Bool
    let targetArtisanId: String?
    let targetArtisanName: String?
    let referenceImages: [String]

    init(
        id: String,
        title: String,
        description: String,
        customerID: String,
        customerName: String,
        customerCity: String,
        customerAddress: String,
        category: String,
        categories: [String],
        styles: [String],
        dietary: [String],
        tier: Int,
        cakeSize: String,
        sugarLevel: Double,
        flavours: [String],
        fillingFlavour: String,
        specialInstructions: String,
        budgetMin: Double,
        budgetMax: Double,
        expectedDate: Date,
        expectedTime: Date,
        allowNearby: Bool,
        createdAt: Date,
        savedAt: Date?,
        status: String,
        bidCount: Int,
        referenceImages: [String] = [],
        isDirectRequest: Bool,
        targetArtisanId: String?,
        targetArtisanName: String?
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.customerID = customerID
        self.customerName = customerName
        self.customerCity = customerCity
        self.customerAddress = customerAddress
        self.category = category
        self.categories = categories
        self.styles = styles
        self.dietary = dietary
        self.tier = tier
        self.cakeSize = cakeSize
        self.sugarLevel = sugarLevel
        self.flavours = flavours
        self.fillingFlavour = fillingFlavour
        self.specialInstructions = specialInstructions
        self.budgetMin = budgetMin
        self.budgetMax = budgetMax
        self.expectedDate = expectedDate
        self.expectedTime = expectedTime
        self.allowNearby = allowNearby
        self.createdAt = createdAt
        self.savedAt = savedAt
        self.status = status
        self.bidCount = bidCount
        self.referenceImages = referenceImages
        self.isDirectRequest = isDirectRequest
        self.targetArtisanId = targetArtisanId
        self.targetArtisanName = targetArtisanName
    }

    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let customerID = Self.stringValue(in: data, keys: ["customerID", "customerId"]) else {
            return nil
        }

        self.id = document.documentID
        self.title = data["title"] as? String ?? ""
        self.description = data["description"] as? String ?? ""
        self.customerID = customerID
        self.customerName = data["customerName"] as? String ?? "Customer"
        self.customerCity = data["customerCity"] as? String ?? ""
        self.customerAddress = data["customerAddress"] as? String ?? ""
        self.category = data["category"] as? String ?? ""
        self.categories = data["categories"] as? [String] ?? []
        self.styles = data["styles"] as? [String] ?? []
        self.dietary = data["dietary"] as? [String] ?? []
        self.tier = Self.intValue(in: data, key: "tier")
        self.cakeSize = data["cakeSize"] as? String ?? ""
        self.sugarLevel = Self.doubleValue(in: data, key: "sugarLevel", defaultValue: 0.5)
        self.flavours = data["flavours"] as? [String] ?? []
        self.fillingFlavour = data["fillingFlavour"] as? String ?? ""
        self.specialInstructions = data["specialInstructions"] as? String ?? ""
        self.budgetMin = Self.doubleValue(in: data, key: "budgetMin")
        self.budgetMax = Self.doubleValue(in: data, key: "budgetMax")
        self.allowNearby = data["allowNearby"] as? Bool ?? false
        self.status = data["status"] as? String ?? "open"
        self.bidCount = Self.intValue(in: data, key: "bidCount")
        self.isDirectRequest = data["isDirectRequest"] as? Bool ?? false
        self.targetArtisanId = data["targetArtisanId"] as? String
        self.targetArtisanName = data["targetArtisanName"] as? String
        self.expectedDate = Self.dateValue(in: data, key: "expectedDate") ?? Date()
        self.expectedTime = Self.dateValue(in: data, key: "expectedTime") ?? Date()
        self.createdAt = Self.dateValue(in: data, key: "createdAt") ?? Date()
        self.savedAt = Self.dateValue(in: data, key: "savedAt")
        self.referenceImages = data["referenceImages"] as? [String] ?? []
    }

    func ownedBy(userID: String) -> Bool {
        customerID == userID
    }

    var sortDate: Date {
        savedAt ?? createdAt
    }

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Request" : title
    }

    var displayCategory: String {
        if !category.isEmpty {
            return category
        }
        return categories.first ?? "No category"
    }

    var budgetText: String {
        "Rs. \(Int(budgetMin).formatted()) – \(Int(budgetMax).formatted())"
    }

    var statusBadge: CakeRequestStatusBadge {
        switch status {
        case "completed":
            return CakeRequestStatusBadge(
                label: "Completed",
                textColor: Color(red: 0.3, green: 0.3, blue: 0.3),
                bgColor: Color(red: 0.92, green: 0.92, blue: 0.92)
            )
        case "in_progress":
            return CakeRequestStatusBadge(
                label: "In Progress",
                textColor: Color(red: 0.80, green: 0.45, blue: 0.0),
                bgColor: Color(red: 0.99, green: 0.91, blue: 0.78)
            )
        case "draft":
            return CakeRequestStatusBadge(
                label: "Draft",
                textColor: Color(red: 0.55, green: 0.45, blue: 0.35),
                bgColor: Color(red: 0.93, green: 0.88, blue: 0.82)
            )
        default:
            return CakeRequestStatusBadge(
                label: "Open",
                textColor: Color(red: 0.10, green: 0.53, blue: 0.27),
                bgColor: Color(red: 0.85, green: 0.96, blue: 0.89)
            )
        }
    }

    var completionPercent: Int {
        let checks: [Bool] = [
            !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !displayCategory.isEmpty && displayCategory != "No category",
            budgetMin > 0 || budgetMax > 0,
            !styles.isEmpty,
            !flavours.isEmpty,
            tier > 0,
            !cakeSize.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !specialInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            allowNearby
        ]

        let completed = checks.filter { $0 }.count
        return Int((Double(completed) / Double(checks.count) * 100).rounded())
    }

    func toCakeRequest() -> CakeRequest {
        CakeRequest(
            requestDocumentID: id,
            customerID: customerID,
            title: displayTitle,
            category: CakeCategory(name: displayCategory, icon: categoryIcon(for: displayCategory)),
            location: customerCity.isEmpty ? "Customer Location" : customerCity,
            deliveryDate: formattedDate(expectedDate),
            budgetRange: budgetText.replacingOccurrences(of: "Rs.", with: "LKR"),
            bidCount: bidCount,
            description: description.isEmpty ? "No description provided." : description,
            servings: tier,
            flavours: flavours,
            customerName: customerName,
            postedTime: postedTimeText(from: createdAt),
            referenceImages: referenceImages,
            deliveryTime: formattedTime(expectedTime),
            cakeSize: cakeSize.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not specified" : cakeSize,
            sugarLevel: sugarLevel,
            styles: styles,
            dietary: dietary,
            fillingFlavour: fillingFlavour,
            specialInstructions: specialInstructions,
            isMatching: true
        )
    }

    private static func stringValue(in data: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = data[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func intValue(in data: [String: Any], key: String) -> Int {
        if let value = data[key] as? Int {
            return value
        }

        if let value = data[key] as? NSNumber {
            return value.intValue
        }

        return 0
    }

    private static func doubleValue(in data: [String: Any], key: String, defaultValue: Double = 0) -> Double {
        if let value = data[key] as? Double {
            return value
        }

        if let value = data[key] as? NSNumber {
            return value.doubleValue
        }

        return defaultValue
    }

    private static func dateValue(in data: [String: Any], key: String) -> Date? {
        if let value = data[key] as? Timestamp {
            return value.dateValue()
        }

        if let value = data[key] as? Date {
            return value
        }

        if let value = data[key] as? NSNumber {
            return Date(timeIntervalSince1970: value.doubleValue)
        }

        return nil
    }
}

extension CakeRequestRecord {
    static let mock = CakeRequestRecord(
        id: "mock-123",
        title: "3-Tier Elegant Wedding Cake With Fresh Flowers",
        description: "I want a classic elegant 3-tier cake with fresh flowers. Please use smooth fondant finish.",
        customerID: "customer-123",
        customerName: "Sarah Johnson",
        customerCity: "Colombo",
        customerAddress: "123 Main St",
        category: "Wedding",
        categories: ["Wedding"],
        styles: ["Elegant/Classic", "Floral"],
        dietary: ["None"],
        tier: 3,
        cakeSize: "3 kg - 20 People",
        sugarLevel: 0.25,
        flavours: ["Vanilla"],
        fillingFlavour: "Strawberry",
        specialInstructions: "None",
        budgetMin: 22000,
        budgetMax: 28000,
        expectedDate: Date().addingTimeInterval(7 * 24 * 3600),
        expectedTime: Date(),
        allowNearby: true,
        createdAt: Date(),
        savedAt: nil,
        status: "open",
        bidCount: 3,
        isDirectRequest: false,
        targetArtisanId: nil,
        targetArtisanName: nil
    )
}

func categoryIcon(for category: String) -> String {
    switch category.lowercased() {
    case let value where value.contains("wedding"):
        return "heart.fill"
    case let value where value.contains("birthday"):
        return "birthday.cake"
    case let value where value.contains("anniversary"):
        return "heart.circle"
    case let value where value.contains("baby"):
        return "star.fill"
    case let value where value.contains("engagement"):
        return "heart.fill"
    case let value where value.contains("cupcake"):
        return "cup.and.saucer"
    case let value where value.contains("corporate"):
        return "building.2.fill"
    case let value where value.contains("vegan"):
        return "leaf.fill"
    case let value where value.contains("3d"):
        return "cube.fill"
    default:
        return "birthday.cake"
    }
}

func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter.string(from: date)
}

func formattedTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

func postedTimeText(from date: Date) -> String {
    let interval = Date().timeIntervalSince(date)
    let minutes = Int(interval / 60)
    let hours = Int(interval / 3600)
    let days = Int(interval / 86_400)

    if minutes < 1 {
        return "Just now"
    } else if hours < 1 {
        return "\(minutes)m ago"
    } else if hours < 24 {
        return "\(hours)h ago"
    } else {
        return "\(days)d ago"
    }
}
