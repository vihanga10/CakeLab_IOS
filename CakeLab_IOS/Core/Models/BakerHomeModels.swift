import SwiftUI

struct CakeRequest: Identifiable {
    let id: String
    let requestDocumentID: String
    let customerID: String
    let title: String
    let category: CakeCategory
    let location: String
    let deliveryDate: String
    let budgetRange: String
    let bidCount: Int
    let description: String
    let servings: Int
    let flavours: [String]
    let customerName: String
    let postedTime: String
    let referenceImages: [String]
    let deliveryTime: String
    let cakeSize: String
    let sugarLevel: Double
    let styles: [String]
    let dietary: [String]
    let fillingFlavour: String
    let specialInstructions: String
    var isMatching: Bool

    init(
        id: String = UUID().uuidString,
        requestDocumentID: String = "",
        customerID: String = "",
        title: String,
        category: CakeCategory,
        location: String,
        deliveryDate: String,
        budgetRange: String,
        bidCount: Int,
        description: String,
        servings: Int,
        flavours: [String],
        customerName: String,
        postedTime: String,
        referenceImages: [String] = [],
        deliveryTime: String = "Not specified",
        cakeSize: String = "Not specified",
        sugarLevel: Double = 0.5,
        styles: [String] = [],
        dietary: [String] = [],
        fillingFlavour: String = "",
        specialInstructions: String = "",
        isMatching: Bool = true
    ) {
        self.id = id
        self.requestDocumentID = requestDocumentID
        self.customerID = customerID
        self.title = title
        self.category = category
        self.location = location
        self.deliveryDate = deliveryDate
        self.budgetRange = budgetRange
        self.bidCount = bidCount
        self.description = description
        self.servings = servings
        self.flavours = flavours
        self.customerName = customerName
        self.postedTime = postedTime
        self.referenceImages = referenceImages
        self.deliveryTime = deliveryTime
        self.cakeSize = cakeSize
        self.sugarLevel = sugarLevel
        self.styles = styles
        self.dietary = dietary
        self.fillingFlavour = fillingFlavour
        self.specialInstructions = specialInstructions
        self.isMatching = isMatching
    }
}

struct CakeCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
}

struct BakerOrder: Identifiable {
    let id = UUID()
    let cakeName: String
    let customerName: String
    let deliveryDate: String
    let status: String
    let amount: String

    var statusColor: Color {
        switch status {
        case "baking":
            return Color.orange
        case "decorating":
            return Color(red: 0.3, green: 0.45, blue: 0.8)
        case "ready":
            return Color.green
        default:
            return Color.cakeBrown
        }
    }

    var statusLabel: String {
        switch status {
        case "baking":
            return "Baking"
        case "decorating":
            return "Decorating"
        case "ready":
            return "Ready"
        default:
            return "Confirmed"
        }
    }
}

enum BakerHomePreviewData {
    static let matchingRequests: [CakeRequest] = [
        CakeRequest(title: "3-Tier Wedding Cake", category: CakeCategory(name: "Wedding", icon: "heart.fill"), location: "Colombo 07", deliveryDate: "Apr 12, 2026", budgetRange: "LKR 15,000–25,000", bidCount: 3, description: "Looking for a luxurious 3-tier wedding cake with white fondant, gold accents and floral decorations. Serves around 150 guests.", servings: 150, flavours: ["Vanilla", "Chocolate"], customerName: "Amali Perera", postedTime: "2 hrs ago"),
        CakeRequest(title: "Unicorn Birthday Cake", category: CakeCategory(name: "Birthday", icon: "birthday.cake.fill"), location: "Nugegoda", deliveryDate: "Apr 09, 2026", budgetRange: "LKR 5,000–8,000", bidCount: 5, description: "Need a magical unicorn theme birthday cake for my daughter's 5th birthday. Pink and purple colours preferred.", servings: 20, flavours: ["Strawberry", "Vanilla"], customerName: "Nimal Silva", postedTime: "5 hrs ago"),
        CakeRequest(title: "Corporate Anniversary Cake", category: CakeCategory(name: "Corporate", icon: "building.2.fill"), location: "Colombo 03", deliveryDate: "Apr 15, 2026", budgetRange: "LKR 10,000–18,000", bidCount: 2, description: "Elegant corporate cake for our 10th anniversary event. Should include company logo (edible print).", servings: 80, flavours: ["Chocolate", "Red Velvet"], customerName: "Saman Fernando", postedTime: "1 day ago")
    ]

    static let activeOrders: [BakerOrder] = [
        BakerOrder(cakeName: "Wedding Cake — 2 Tier", customerName: "Kavya Naidoo", deliveryDate: "Apr 08, 2026", status: "baking", amount: "LKR 18,500"),
        BakerOrder(cakeName: "Chocolate Fondant Cake", customerName: "Rohan Gupta", deliveryDate: "Apr 10, 2026", status: "decorating", amount: "LKR 6,200")
    ]

    static let otherRequests: [CakeRequest] = [
        CakeRequest(title: "Japanese Cheesecake", category: CakeCategory(name: "Dessert", icon: "fork.knife"), location: "Dehiwala", deliveryDate: "Apr 11, 2026", budgetRange: "LKR 3,500–5,000", bidCount: 1, description: "Fluffy Japanese-style cheesecake, 8-inch diameter.", servings: 10, flavours: ["Cheese"], customerName: "Priya Raj", postedTime: "3 hrs ago", isMatching: false),
        CakeRequest(title: "Gluten-Free Carrot Cake", category: CakeCategory(name: "Special Diet", icon: "leaf.fill"), location: "Mount Lavinia", deliveryDate: "Apr 13, 2026", budgetRange: "LKR 4,000–6,000", bidCount: 0, description: "Gluten-free carrot cake with cream cheese frosting. No nuts.", servings: 15, flavours: ["Carrot"], customerName: "Layla Ahmad", postedTime: "6 hrs ago", isMatching: false),
        CakeRequest(title: "Geode Crystal Cake", category: CakeCategory(name: "Artistic", icon: "sparkles"), location: "Rajagiriya", deliveryDate: "Apr 16, 2026", budgetRange: "LKR 12,000–20,000", bidCount: 2, description: "Stunning geode-style cake with sugar crystals in blue and purple tones.", servings: 40, flavours: ["Vanilla", "Blueberry"], customerName: "Malini Senanayake", postedTime: "8 hrs ago", isMatching: false)
    ]
}
