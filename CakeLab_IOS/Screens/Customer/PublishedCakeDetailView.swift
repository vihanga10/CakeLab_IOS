import SwiftUI

// MARK: - Published Cake Detail View
@MainActor
struct PublishedCakeDetailView: View {
    let request: CakeRequestRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header matching PublishRequestView pattern
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        // Title and Description
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Title")
                                .font(.urbanistMedium(12))
                                .foregroundColor(.cakeGrey)
                            Text(request.displayTitle)
                                .font(.urbanistSemiBold(16))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                .lineLimit(nil)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Description")
                                .font(.urbanistMedium(12))
                                .foregroundColor(.cakeGrey)
                            Text(request.description.isEmpty ? "No description provided" : request.description)
                                .font(.urbanistRegular(14))
                                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                                .lineSpacing(2)
                                .lineLimit(nil)
                        }

                        // Image placeholder
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(red: 0.93, green: 0.91, blue: 0.88))
                            
                            VStack(spacing: 8) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.cakeBrown.opacity(0.5))
                                Text("Full View Image")
                                    .font(.urbanistSemiBold(14))
                                    .foregroundColor(.cakeBrown)
                            }
                        }
                        .frame(height: 200)

                        // Budget
                        infoRow(label: "Budget (LKR)", value: request.budgetText)

                        // Category
                        infoRow(label: "Category", value: request.displayCategory)

                        // Cake Style
                        infoRow(label: "Cake Style", value: request.styles.isEmpty ? "Not specified" : request.styles.joined(separator: ", "))

                        // Dietary
                        infoRow(label: "Dietary", value: request.dietary.isEmpty ? "None" : request.dietary.joined(separator: ", "))

                        // Tiers
                        infoRow(label: "Tiers", value: "\(request.tier)")

                        // Cake Size
                        infoRow(label: "Cake Size", value: request.cakeSize.isEmpty ? "Not specified" : request.cakeSize)

                        // Sugar Level
                        infoRow(label: "Sugar Level", value: String(format: "%.0f", request.sugarLevel * 100))

                        // Cake Flavour
                        infoRow(label: "Cake Flavour", value: request.flavours.isEmpty ? "Not specified" : request.flavours.joined(separator: ", "))

                        // Filling Flavour
                        infoRow(label: "Filling Flavour", value: request.fillingFlavour.isEmpty ? "Not specified" : request.fillingFlavour)

                        // Special Instructions
                        if !request.specialInstructions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Special Instructions")
                                    .font(.urbanistMedium(12))
                                    .foregroundColor(.cakeGrey)
                                Text(request.specialInstructions)
                                    .font(.urbanistRegular(14))
                                    .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                                    .lineSpacing(2)
                                    .lineLimit(nil)
                            }
                        }

                        // Expected Date
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Expected Date")
                                .font(.urbanistMedium(12))
                                .foregroundColor(.cakeGrey)
                            
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.cakeBrown)
                                    .font(.system(size: 14, weight: .semibold))
                                
                                Text(formattedDate(request.expectedDate))
                                    .font(.urbanistRegular(14))
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.98, green: 0.96, blue: 0.93))
                            .cornerRadius(10)
                        }

                        // Expected Time
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Expected Time")
                                .font(.urbanistMedium(12))
                                .foregroundColor(.cakeGrey)
                            
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.cakeBrown)
                                    .font(.system(size: 14, weight: .semibold))
                                
                                Text(formattedTime(request.expectedTime))
                                    .font(.urbanistRegular(14))
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.98, green: 0.96, blue: 0.93))
                            .cornerRadius(10)
                        }

                        Spacer().frame(height: 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
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
                Text("Cake Details")
                    .font(.urbanistBold(18))
                    .foregroundColor(.cakeBrown)
            }
            Spacer()
            Color.clear.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.white)
    }

    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.urbanistMedium(12))
                .foregroundColor(.cakeGrey)
            Text(value)
                .font(.urbanistRegular(14))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                .lineLimit(nil)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        PublishedCakeDetailView(request: CakeRequestRecord.mock)
    }
}

// MARK: - Mock Preview Data
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
        self.isDirectRequest = isDirectRequest
        self.targetArtisanId = targetArtisanId
        self.targetArtisanName = targetArtisanName
    }
}
