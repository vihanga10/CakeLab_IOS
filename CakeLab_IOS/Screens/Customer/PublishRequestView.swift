import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Publish Request View (Customer's published cake requests)
@MainActor
struct PublishRequestView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var requests: [CakeRequestRecord] = []
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.97, blue: 0.97).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.cakeBrown)
                    }
                    Spacer()
                    Text("Publish Requests")
                        .font(.urbanistBold(18))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    Spacer()
                    Color.clear.frame(width: 24)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 2)

                if isLoading {
                    Spacer()
                    ProgressView("Loading requests...")
                        .tint(.cakeBrown)
                    Spacer()
                } else if requests.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 44))
                            .foregroundColor(.cakeGrey)
                        Text("No published requests yet")
                            .font(.urbanistSemiBold(15))
                            .foregroundColor(.cakeGrey)
                        Text("Publish a cake request to see it here")
                            .font(.urbanistRegular(13))
                            .foregroundColor(.cakeGrey)
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(requests) { request in
                                PublishedRequestCard(request: request)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 30)
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
    
    private func fetchPublishedRequests() async {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await Firestore.firestore()
                .collection("cakeRequests")
                .whereField("customerID", isEqualTo: userID)
                .getDocuments()
            
            requests = snapshot.documents
                .compactMap(CakeRequestRecord.init(document:))
                .filter { $0.status != "draft" }
                .sorted { $0.sortDate > $1.sortDate }
        } catch {
            print("Error fetching published requests: \(error)")
        }
    }
}

// MARK: - Published Request Card
private struct PublishedRequestCard: View {
    let request: CakeRequestRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.displayTitle)
                        .font(.urbanistSemiBold(15))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    Text(request.displayCategory)
                        .font(.urbanistRegular(12))
                        .foregroundColor(.cakeGrey)
                }
                Spacer()
                StatusBadge(status: request.statusBadge)
            }

            Divider()

            HStack(spacing: 16) {
                infoItem(icon: "calendar", label: dateText(request.sortDate))
                infoItem(icon: "banknote", label: request.budgetText)
                infoItem(icon: "person.2.fill", label: "\(request.bidCount) bids")
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func infoItem(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.cakeBrown)
            Text(label)
                .font(.urbanistRegular(12))
                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
        }
    }

    private func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}

// MARK: - Status Badge
private struct StatusBadge: View {
    let status: CakeRequestStatusBadge

    var body: some View {
        Text(status.label)
            .font(.urbanistSemiBold(11))
            .foregroundColor(status.textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status.bgColor)
            .cornerRadius(10)
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
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let customerID = data["customerID"] as? String else {
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
        self.tier = data["tier"] as? Int ?? 0
        self.cakeSize = data["cakeSize"] as? String ?? ""
        self.sugarLevel = data["sugarLevel"] as? Double ?? 0.5
        self.flavours = data["flavours"] as? [String] ?? []
        self.fillingFlavour = data["fillingFlavour"] as? String ?? ""
        self.specialInstructions = data["specialInstructions"] as? String ?? ""
        self.budgetMin = data["budgetMin"] as? Double ?? 0
        self.budgetMax = data["budgetMax"] as? Double ?? 0
        self.allowNearby = data["allowNearby"] as? Bool ?? false
        self.status = data["status"] as? String ?? "open"
        self.bidCount = data["bidCount"] as? Int ?? 0
        
        let expectedDateValue = data["expectedDate"] as? Double ?? Date().timeIntervalSince1970
        let expectedTimeValue = data["expectedTime"] as? Double ?? Date().timeIntervalSince1970
        let createdAtValue = data["createdAt"] as? Double ?? Date().timeIntervalSince1970
        
        self.expectedDate = Date(timeIntervalSince1970: expectedDateValue)
        self.expectedTime = Date(timeIntervalSince1970: expectedTimeValue)
        self.createdAt = Date(timeIntervalSince1970: createdAtValue)
        
        if let savedAtValue = data["savedAt"] as? Double {
            self.savedAt = Date(timeIntervalSince1970: savedAtValue)
        } else {
            self.savedAt = nil
        }
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
    NavigationStack { PublishRequestView() }
}
