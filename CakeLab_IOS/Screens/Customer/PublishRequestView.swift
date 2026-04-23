import SwiftUI
import FirebaseAuth
import FirebaseFirestore

enum CustomerRequestCollection {
    case published
    case draft

    var firestoreName: String {
        switch self {
        case .published:
            return "cakeRequests"
        case .draft:
            return "draftRequests"
        }
    }

    func includes(_ request: CakeRequestRecord) -> Bool {
        switch self {
        case .published:
            return request.status != "draft"
        case .draft:
            return true
        }
    }
}

struct CustomerRequestStore {
    private let db = Firestore.firestore()

    func fetchRequests(for userID: String, from collection: CustomerRequestCollection) async throws -> [CakeRequestRecord] {
        async let currentFieldSnapshot = db.collection(collection.firestoreName)
            .whereField("customerID", isEqualTo: userID)
            .getDocuments()
        async let legacyFieldSnapshot = db.collection(collection.firestoreName)
            .whereField("customerId", isEqualTo: userID)
            .getDocuments()

        let snapshots = try await [currentFieldSnapshot, legacyFieldSnapshot]
        var requestsByID: [String: CakeRequestRecord] = [:]

        for snapshot in snapshots {
            for document in snapshot.documents {
                guard let request = CakeRequestRecord(document: document) else {
                    continue
                }

                guard collection.includes(request), request.ownedBy(userID: userID) else {
                    continue
                }

                requestsByID[request.id] = request
            }
        }

        return requestsByID.values.sorted { $0.sortDate > $1.sortDate }
    }
}

// MARK: - Publish Request View (Customer's published cake requests)
@MainActor
struct PublishRequestView: View {
    let user: AppUser
    @Environment(\.dismiss) private var dismiss
    
    @State private var requests: [CakeRequestRecord] = []
    @State private var isLoading = false
    private let requestStore = CustomerRequestStore()

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.cakeBrown)
                        Text("Loading requests...")
                            .font(.urbanistRegular(13))
                            .foregroundColor(.cakeGrey)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if requests.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(requests) { request in
                                NavigationLink(destination: PublishedCakeDetailView(request: request)) {
                                    PublishedRequestCard(request: request)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 28)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await fetchPublishedRequests()
        }
        .refreshable {
            await fetchPublishedRequests()
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
                Text("Published Requests")
                    .font(.urbanistBold(18))
                    .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
                
            }
            Spacer()
            Color.clear.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.white)
        
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 70, height: 70)
                Image(systemName: "doc.text")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.cakeBrown)
            }
            Text("No published requests yet")
                .font(.urbanistSemiBold(16))
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
            Text("Publish a cake request to see it here")
                .font(.urbanistRegular(13))
                .foregroundColor(.cakeGrey)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var backgroundLayer: some View {
        Color.white.ignoresSafeArea()
    }
    
    private func fetchPublishedRequests() async {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("Error fetching published requests: no authenticated Firebase session")
            requests = []
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            requests = try await requestStore.fetchRequests(for: userID, from: .published)
        } catch {
            print("Error fetching published requests: \(error)")
        }
    }
}

// MARK: - Published Request Card
private struct PublishedRequestCard: View {
    let request: CakeRequestRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(request.displayTitle)
                        .font(.urbanistSemiBold(16))
                        .foregroundColor(Color(.label))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 10)

                StatusBadge(status: request.statusBadge)
            }

            // Category badge with pastel color
            Text(request.displayCategory)
                .font(.urbanistMedium(12))
                .foregroundColor(categoryTextColor(for: request.displayCategory))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(categoryBackgroundColor(for: request.displayCategory))
                .clipShape(Capsule())

            Divider()

            HStack(spacing: 0) {
                infoColumn(icon: "calendar", label: "Date", value: dateText(request.sortDate))
                infoDivider
                infoColumn(icon: "banknote", label: "Budget", value: request.budgetText)
                infoDivider
                infoColumn(icon: "person.2.fill", label: "Bids", value: "\(request.bidCount)")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private func infoColumn(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.cakeBrown)

                Text(label)
                    .font(.urbanistRegular(11))
                    .foregroundColor(Color(.secondaryLabel))
            }

            Text(value)
                .font(.urbanistSemiBold(12))
                .foregroundColor(Color(.label))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var infoDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.08))
            .frame(width: 1, height: 34)
    }

    private func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
    
    // MARK: - Category Color Mapping
    private func categoryBackgroundColor(for category: String) -> Color {
        let categoryLower = category.lowercased()
        switch categoryLower {
        case let cat where cat.contains("wedding"):
            return Color(red: 1.0, green: 0.95, blue: 0.97) // Pink pastel
        case let cat where cat.contains("birthday"):
            return Color(red: 0.99, green: 0.95, blue: 0.90) // Peach pastel
        case let cat where cat.contains("anniversary"):
            return Color(red: 0.95, green: 0.99, blue: 0.95) // Mint pastel
        case let cat where cat.contains("baby"):
            return Color(red: 0.98, green: 0.96, blue: 1.0) // Lavender pastel
        case let cat where cat.contains("cupcake"):
            return Color(red: 1.0, green: 0.98, blue: 0.94) // Cream pastel
        case let cat where cat.contains("buttercream"):
            return Color(red: 0.99, green: 1.0, blue: 0.95) // Light yellow pastel
        case let cat where cat.contains("corporate"):
            return Color(red: 0.95, green: 0.98, blue: 1.0) // Sky blue pastel
        case let cat where cat.contains("engagement"):
            return Color(red: 1.0, green: 0.96, blue: 0.92) // Coral pastel
        case let cat where cat.contains("graduation"):
            return Color(red: 0.94, green: 0.97, blue: 1.0) // Light blue pastel
        case let cat where cat.contains("baptism"):
            return Color(red: 0.96, green: 0.99, blue: 1.0) // Ice blue pastel
        case let cat where cat.contains("retirement"):
            return Color(red: 1.0, green: 0.96, blue: 0.94) // Salmon pastel
        case let cat where cat.contains("farewell"):
            return Color(red: 0.98, green: 0.97, blue: 1.0) // Soft purple pastel
        case let cat where cat.contains("vegan"):
            return Color(red: 0.96, green: 1.0, blue: 0.96) // Pale green pastel
        case let cat where cat.contains("sculpted"):
            return Color(red: 0.98, green: 0.95, blue: 0.99) // Lilac pastel
        default:
            return Color(red: 0.96, green: 0.96, blue: 0.96) // Gray pastel
        }
    }
    
    private func categoryTextColor(for category: String) -> Color {
        let categoryLower = category.lowercased()
        switch categoryLower {
        case let cat where cat.contains("wedding"):
            return Color(red: 0.8, green: 0.3, blue: 0.6) // Rose
        case let cat where cat.contains("birthday"):
            return Color(red: 0.85, green: 0.5, blue: 0.25) // Burnt orange
        case let cat where cat.contains("anniversary"):
            return Color(red: 0.2, green: 0.6, blue: 0.4) // Teal
        case let cat where cat.contains("baby"):
            return Color(red: 0.6, green: 0.3, blue: 0.8) // Purple
        case let cat where cat.contains("cupcake"):
            return Color(red: 0.8, green: 0.5, blue: 0.2) // Orange
        case let cat where cat.contains("buttercream"):
            return Color(red: 0.7, green: 0.6, blue: 0.1) // Golden
        case let cat where cat.contains("corporate"):
            return Color(red: 0.2, green: 0.5, blue: 0.8) // Blue
        case let cat where cat.contains("engagement"):
            return Color(red: 0.85, green: 0.35, blue: 0.3) // Red
        case let cat where cat.contains("graduation"):
            return Color(red: 0.3, green: 0.5, blue: 0.7) // Slate blue
        case let cat where cat.contains("baptism"):
            return Color(red: 0.2, green: 0.6, blue: 0.7) // Cyan
        case let cat where cat.contains("retirement"):
            return Color(red: 0.8, green: 0.4, blue: 0.3) // Terracotta
        case let cat where cat.contains("farewell"):
            return Color(red: 0.5, green: 0.3, blue: 0.7) // Plum
        case let cat where cat.contains("vegan"):
            return Color(red: 0.2, green: 0.7, blue: 0.2) // Forest green
        case let cat where cat.contains("sculpted"):
            return Color(red: 0.7, green: 0.2, blue: 0.7) // Magenta
        default:
            return Color(red: 0.4, green: 0.4, blue: 0.4) // Dark gray
        }
    }
}

// MARK: - Status Badge
private struct StatusBadge: View {
    let status: CakeRequestStatusBadge

    var body: some View {
        Text(status.label)
            .font(.urbanistSemiBold(11))
            .foregroundColor(status.textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(status.bgColor)
            .clipShape(Capsule())
    }
}

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

#Preview {
    NavigationStack { PublishRequestView(user: .mock) }
}
