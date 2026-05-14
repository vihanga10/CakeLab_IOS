import Foundation
import FirebaseFirestore

// MARK: - Baker Profile Data

struct BakerProfileData {
    let shopName: String
    let address: String
    let city: String
    let isOnline: Bool
    let rating: Double
    let reviewCount: Int
    let completedOrders: Int
    let about: String
    let createdAt: Date
    let specialties: [String]
    let profileImageURL: String
    let profileImageBase64: String
    let coverImageURL: String
    let coverImageBase64: String
    let portfolioWorks: [PortfolioPreviewWork]

    static let empty = BakerProfileData(
        shopName: "Baker Shop",
        address: "No address added",
        city: "",
        isOnline: true,
        rating: 0,
        reviewCount: 0,
        completedOrders: 0,
        about: "No profile description added yet.",
        createdAt: Date(),
        specialties: ["Custom Cakes"],
        profileImageURL: "",
        profileImageBase64: "",
        coverImageURL: "",
        coverImageBase64: "",
        portfolioWorks: []
    )
}

// MARK: - Portfolio Preview Work

struct PortfolioPreviewWork: Identifiable {
    let id: String
    let title: String
    let description: String
    let imageReference: String
    let traits: [PortfolioTrait]
    let updatedAt: Date

    init(id: String, title: String, description: String, imageReference: String, traits: [PortfolioTrait], updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.description = description
        self.imageReference = imageReference
        self.traits = traits
        self.updatedAt = updatedAt
    }

    init?(dictionary: [String: Any]) {
        let id = (dictionary["workID"] as? String ?? UUID().uuidString).trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (dictionary["title"] as? String ?? "Portfolio Work").trimmingCharacters(in: .whitespacesAndNewlines)
        let description = (dictionary["description"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let imageReference = (dictionary["imageBase64"] as? String ?? dictionary["imageURL"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let traitsData = dictionary["traits"] as? [[String: Any]] ?? []
        let updatedAt = (dictionary["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        guard !imageReference.isEmpty else { return nil }

        self.id = id
        self.title = title.isEmpty ? "Portfolio Work" : title
        self.description = description
        self.imageReference = imageReference
        self.traits = traitsData.compactMap(PortfolioTrait.init(dictionary:))
        self.updatedAt = updatedAt
    }

    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        let title = (data["title"] as? String ?? "Portfolio Work").trimmingCharacters(in: .whitespacesAndNewlines)
        let imageReference = (data["imageBase64"] as? String ?? data["imageURL"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !imageReference.isEmpty else { return nil }

        let description = (data["description"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let traitsData = data["traits"] as? [[String: Any]] ?? []
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()

        self.id = document.documentID
        self.title = title.isEmpty ? "Portfolio Work" : title
        self.description = description
        self.imageReference = imageReference
        self.traits = traitsData.compactMap(PortfolioTrait.init(dictionary:))
        self.updatedAt = updatedAt
    }
}

// MARK: - Monthly Order Data

struct MonthlyOrderData: Identifiable {
    let id = UUID()
    let month: String
    let count: Int
}

// MARK: - Earnings Data

struct EarningsData {
    let totalEarningsThisMonth: Double
    let totalEarningsLastMonth: Double
    let totalEarningsThisYear: Double
    let avgPerOrder: Double

    var thisMonthFormatted: String { String(format: "LKR %.0f", totalEarningsThisMonth) }
    var lastMonthFormatted: String { String(format: "LKR %.0f", totalEarningsLastMonth) }
    var thisYearFormatted: String { String(format: "LKR %.0f", totalEarningsThisYear) }
    var avgPerOrderFormatted: String { String(format: "LKR %.0f", avgPerOrder) }

    static let empty = EarningsData(
        totalEarningsThisMonth: 0,
        totalEarningsLastMonth: 0,
        totalEarningsThisYear: 0,
        avgPerOrder: 0
    )
}

// MARK: - RatingData

struct RatingData: Identifiable {
    let id = UUID()
    let stars: Int
    let count: Int
    let fraction: CGFloat
}
