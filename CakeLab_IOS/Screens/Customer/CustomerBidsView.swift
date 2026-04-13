import SwiftUI
import Combine
import FirebaseFirestore

struct CustomerBidRequest: Identifiable {
    let id: String
    let customerID: String
    let title: String
    let category: String
    let location: String
    let budgetMin: Double
    let budgetMax: Double
    let expectedDate: Date
    let expectedTime: Date
    let bidCount: Int
    let createdAt: Date
    let description: String
}

struct CustomerBidOffer: Identifiable {
    let id: String
    let bakerID: String
    let bakerName: String
    let amount: Double
    let message: String
    let canDeliverOnTime: Bool
    let deliveryDate: Date?
    let submittedAt: Date
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

            let parsed = mergedDocs.values.compactMap(Self.parseRequest)
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
            title: data["title"] as? String ?? "Cake Request",
            category: data["category"] as? String ?? "Custom Cake",
            location: data["customerCity"] as? String ?? data["customerAddress"] as? String ?? "Customer Location",
            budgetMin: parseDouble(data["budgetMin"]),
            budgetMax: parseDouble(data["budgetMax"]),
            expectedDate: expectedDate,
            expectedTime: expectedTime,
            bidCount: parseInt(data["bidCount"]),
            createdAt: createdAt,
            description: data["description"] as? String ?? ""
        )
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
            bids = parsed.sorted { $0.submittedAt > $1.submittedAt }
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
            amount: parseDouble(data["amount"]),
            message: data["message"] as? String ?? "",
            canDeliverOnTime: canDeliverOnTime,
            deliveryDate: canDeliverOnTime ? nil : alternativeDate,
            submittedAt: submittedAt
        )
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
}

struct CustomerBidsView: View {
    let user: AppUser
    @StateObject private var viewModel = CustomerBidsViewModel()

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
                Color(red: 0.97, green: 0.97, blue: 0.97).ignoresSafeArea()

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
                    Text("Bids On My Requests")
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
        }
    }
}

struct CustomerBidRequestCard: View {
    let request: CustomerBidRequest
    let dateText: String
    let timeText: String

    var body: some View {
        NavigationLink {
            BidsReceivedView(request: request)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                        .frame(width: 74, height: 74)
                        .overlay(
                            Image(systemName: "birthday.cake.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.cakeBrown.opacity(0.7))
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(request.title)
                            .font(.urbanistBold(14))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            Text(dateText)
                                .font(.urbanistSemiBold(12))
                            Text("|")
                                .foregroundColor(Color.black.opacity(0.25))
                            Text(timeText.lowercased())
                                .font(.urbanistSemiBold(12))
                        }
                        .foregroundColor(Color(red: 93/255, green: 55/255, blue: 20/255))

                        Text("Category : \(request.category)")
                            .font(.urbanistRegular(12))
                            .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.35))
                            .lineLimit(1)
                    }

                    Spacer()
                }

                HStack(spacing: 6) {
                    Text("Budget (LKR) :")
                        .font(.urbanistRegular(12))
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                    Text("\(Int(request.budgetMin).formatted()) - \(Int(request.budgetMax).formatted())")
                        .font(.urbanistBold(14))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                }

                HStack(spacing: 10) {
                    Text("View Bids Received (\(request.bidCount))")
                        .font(.urbanistSemiBold(12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.cakeBrown)
                        .clipShape(Capsule())

                    Text("View Full Details")
                        .font(.urbanistSemiBold(12))
                        .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 0.80, green: 0.80, blue: 0.80), lineWidth: 1.2)
                        )

                    Spacer()
                }
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

struct BidsReceivedView: View {
    let request: CustomerBidRequest
    @StateObject private var viewModel = BidsReceivedViewModel()

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
            Color(red: 0.97, green: 0.97, blue: 0.97).ignoresSafeArea()

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
                        ContentUnavailableView(
                            "No Bids Yet",
                            systemImage: "person.2.slash",
                            description: Text("Bakers have not placed bids for this request yet.")
                        )
                        .padding(.top, 20)
                    } else {
                        ForEach(viewModel.bids) { bid in
                            BakerBidOfferCard(bid: bid)
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Bids Received")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadBids(requestID: request.id, customerID: request.customerID)
        }
        .refreshable {
            await viewModel.loadBids(requestID: request.id, customerID: request.customerID)
        }
    }

    private var requestSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(request.title)
                .font(.urbanistBold(20))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

            HStack(spacing: 10) {
                Label(Self.dateFormatter.string(from: request.expectedDate), systemImage: "calendar")
                Text("|").foregroundColor(Color.black.opacity(0.25))
                Label(Self.timeFormatter.string(from: request.expectedTime).lowercased(), systemImage: "clock")
            }
            .font(.urbanistSemiBold(13))
            .foregroundColor(Color(red: 93/255, green: 55/255, blue: 20/255))

            Text("Budget (LKR) : \(Int(request.budgetMin).formatted()) - \(Int(request.budgetMax).formatted())")
                .font(.urbanistSemiBold(14))
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))

            Text(request.description)
                .font(.urbanistRegular(13))
                .foregroundColor(.cakeGrey)
                .lineLimit(3)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
    }
}

struct BakerBidOfferCard: View {
    let bid: CustomerBidOffer

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
                Circle()
                    .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.cakeBrown.opacity(0.75))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(bid.bakerName)
                        .font(.urbanistBold(20))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

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
                : "Alternative: \(bid.deliveryDate.map { Self.dateFormatter.string(from: $0) } ?? "Not provided")"
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Message from baker")
                    .font(.urbanistSemiBold(13))
                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                Text(bid.message.isEmpty ? "No message provided." : bid.message)
                    .font(.urbanistRegular(13))
                    .foregroundColor(.cakeGrey)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                Button {
                } label: {
                    Text("Accept Bid")
                        .font(.urbanistSemiBold(13))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.cakeBrown)
                        .clipShape(Capsule())
                }

                Button {
                } label: {
                    Text("View Bid Details")
                        .font(.urbanistSemiBold(13))
                        .foregroundColor(Color(red: 93/255, green: 55/255, blue: 20/255))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 93/255, green: 55/255, blue: 20/255), lineWidth: 1.2)
                        )
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
    }

    private func detailsRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.urbanistRegular(14))
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                .frame(width: 88, alignment: .leading)
            Text(": \(value)")
                .font(.urbanistSemiBold(14))
                .foregroundColor(Color(red: 93/255, green: 55/255, blue: 20/255))
            Spacer()
        }
    }
}

#Preview {
    CustomerBidsView(user: AppUser.mock)
}
