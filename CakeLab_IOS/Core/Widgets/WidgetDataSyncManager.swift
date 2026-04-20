import Foundation
import FirebaseAuth
import FirebaseFirestore
import WidgetKit

enum WidgetSharedConstants {
    static let appGroupID = "group.com.vihanga.CakeLab-IOS"
    static let snapshotKey = "widget.snapshot.v1"
}

enum WidgetUserRole: String, Codable {
    case customer
    case baker
    case unknown
}

struct WidgetOrderSummary: Codable, Hashable {
    let id: String
    let cakeName: String
    let status: String
    let currentStep: Int
    let deliveryDate: Date
    let counterpartName: String
}

struct WidgetMatchingRequestSummary: Codable, Hashable {
    let id: String
    let title: String
    let category: String
    let expectedDate: Date
    let bidCount: Int
    let budgetMin: Double
    let budgetMax: Double
}

struct WidgetSnapshotPayload: Codable {
    let isLoggedIn: Bool
    let role: WidgetUserRole
    let userID: String
    let updatedAt: Date
    let customerNearestOrder: WidgetOrderSummary?
    let customerActiveOrders: [WidgetOrderSummary]
    let bakerNearestOrder: WidgetOrderSummary?
    let bakerLatestMatchingRequest: WidgetMatchingRequestSummary?

    static var loggedOut: WidgetSnapshotPayload {
        WidgetSnapshotPayload(
            isLoggedIn: false,
            role: .unknown,
            userID: "",
            updatedAt: Date(),
            customerNearestOrder: nil,
            customerActiveOrders: [],
            bakerNearestOrder: nil,
            bakerLatestMatchingRequest: nil
        )
    }
}

final class WidgetDataSyncManager {
    static let shared = WidgetDataSyncManager()

    private let db = Firestore.firestore()

    private init() {}

    func refreshFromCurrentSession() {
        Task {
            await refreshFromCurrentSessionAsync()
        }
    }

    @MainActor
    func refreshFromCurrentSessionAsync() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            clearWidgetData()
            return
        }

        do {
            let role = try await fetchRole(for: uid)
            let snapshot = try await buildSnapshot(uid: uid, role: role)
            persist(snapshot: snapshot)
        } catch {
            print("Widget sync failed: \(error.localizedDescription)")
            clearWidgetData()
        }
    }

    func clearWidgetData() {
        persist(snapshot: .loggedOut)
    }

    private func fetchRole(for uid: String) async throws -> WidgetUserRole {
        let doc = try await db.collection("users").document(uid).getDocument()
        let rawRole = (doc.data()?["role"] as? String ?? "").lowercased()

        switch rawRole {
        case "customer": return .customer
        case "baker": return .baker
        default: return .unknown
        }
    }

    private func buildSnapshot(uid: String, role: WidgetUserRole) async throws -> WidgetSnapshotPayload {
        switch role {
        case .customer:
            let orders = try await fetchCustomerActiveOrders(customerID: uid)
            return WidgetSnapshotPayload(
                isLoggedIn: true,
                role: .customer,
                userID: uid,
                updatedAt: Date(),
                customerNearestOrder: orders.first,
                customerActiveOrders: Array(orders.prefix(5)),
                bakerNearestOrder: nil,
                bakerLatestMatchingRequest: nil
            )
        case .baker:
            let orders = try await fetchBakerActiveOrders(bakerID: uid)
            let latest = try await fetchLatestMatchingRequest(bakerID: uid)
            return WidgetSnapshotPayload(
                isLoggedIn: true,
                role: .baker,
                userID: uid,
                updatedAt: Date(),
                customerNearestOrder: nil,
                customerActiveOrders: [],
                bakerNearestOrder: orders.first,
                bakerLatestMatchingRequest: latest
            )
        case .unknown:
            return .loggedOut
        }
    }

    private func fetchCustomerActiveOrders(customerID: String) async throws -> [WidgetOrderSummary] {
        let statuses = ["confirmed", "baking", "decorating", "quality_check"]

        let snapshot = try await db.collection("orders")
            .whereField("customerId", isEqualTo: customerID)
            .whereField("status", in: statuses)
            .getDocuments()

        return snapshot.documents
            .compactMap(makeOrderSummary)
            .sorted { $0.deliveryDate < $1.deliveryDate }
    }

    private func fetchBakerActiveOrders(bakerID: String) async throws -> [WidgetOrderSummary] {
        let statuses = ["confirmed", "baking", "decorating", "quality_check"]
        let bakerKeys = ["artisanId", "bakerID", "bakerId"]

        var map: [String: WidgetOrderSummary] = [:]

        for key in bakerKeys {
            let snapshot = try await db.collection("orders")
                .whereField(key, isEqualTo: bakerID)
                .whereField("status", in: statuses)
                .getDocuments()

            for doc in snapshot.documents {
                if let order = makeOrderSummary(document: doc) {
                    map[order.id] = order
                }
            }
        }

        return map.values.sorted { $0.deliveryDate < $1.deliveryDate }
    }

    private func fetchLatestMatchingRequest(bakerID: String) async throws -> WidgetMatchingRequestSummary? {
        let bakerDoc = try await db.collection("artisans").document(bakerID).getDocument()
        let specialties = (bakerDoc.data()?["specialties"] as? [String] ?? [])
            .map(normalizedCategory)
            .filter { !$0.isEmpty }

        guard !specialties.isEmpty else { return nil }
        let specialtySet = Set(specialties)

        let snapshot = try await db.collection("cakeRequests")
            .whereField("status", isEqualTo: "open")
            .getDocuments()

        let requests = snapshot.documents.compactMap { doc -> WidgetMatchingRequestSummary? in
            guard let data = doc.data() as [String: Any]? else { return nil }

            let title = (data["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let category = (data["category"] as? String) ?? ""
            let categories = data["categories"] as? [String] ?? []
            let categoryCandidates = categories.isEmpty ? [category] : categories
            let normalized = Set(categoryCandidates.map(normalizedCategory).filter { !$0.isEmpty })
            guard !normalized.isDisjoint(with: specialtySet) else { return nil }

            guard let expectedDate = dateFromAny(data["expectedDate"]) else { return nil }
            let createdAt = dateFromAny(data["createdAt"]) ?? Date.distantPast

            return WidgetMatchingRequestSummary(
                id: doc.documentID,
                title: (title?.isEmpty == false) ? title! : "Untitled Request",
                category: categoryCandidates.first ?? "Cake",
                expectedDate: expectedDate,
                bidCount: intFromAny(data["bidCount"]),
                budgetMin: doubleFromAny(data["budgetMin"]),
                budgetMax: doubleFromAny(data["budgetMax"])
            )
        }

        return requests.sorted { lhs, rhs in
            let lhsDoc = snapshot.documents.first { $0.documentID == lhs.id }
            let rhsDoc = snapshot.documents.first { $0.documentID == rhs.id }
            let lhsDate = dateFromAny(lhsDoc?.data()["createdAt"])
            let rhsDate = dateFromAny(rhsDoc?.data()["createdAt"])
            return (lhsDate ?? .distantPast) > (rhsDate ?? .distantPast)
        }.first
    }

    private func makeOrderSummary(document: DocumentSnapshot) -> WidgetOrderSummary? {
        guard let data = document.data() else { return nil }
        guard let cakeName = data["cakeName"] as? String else { return nil }
        guard let status = data["status"] as? String else { return nil }
        guard let deliveryDate = dateFromAny(data["deliveryDate"]) else { return nil }

        let currentStep = intFromAny(data["currentStep"])
        let counterpart = (data["artisanName"] as? String)
            ?? (data["customerName"] as? String)
            ?? (data["customerEmail"] as? String)
            ?? "CakeLab"

        return WidgetOrderSummary(
            id: document.documentID,
            cakeName: cakeName,
            status: status,
            currentStep: max(1, min(5, currentStep == 0 ? 1 : currentStep)),
            deliveryDate: deliveryDate,
            counterpartName: counterpart
        )
    }

    private func persist(snapshot: WidgetSnapshotPayload) {
        guard let defaults = UserDefaults(suiteName: WidgetSharedConstants.appGroupID) else {
            return
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(snapshot) {
            defaults.set(data, forKey: WidgetSharedConstants.snapshotKey)
        } else {
            defaults.removeObject(forKey: WidgetSharedConstants.snapshotKey)
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    private func normalizedCategory(_ raw: String) -> String {
        let cleaned = raw
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "cakes", with: "")
            .replacingOccurrences(of: "cake", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func dateFromAny(_ raw: Any?) -> Date? {
        if let ts = raw as? Timestamp { return ts.dateValue() }
        if let date = raw as? Date { return date }
        if let seconds = raw as? TimeInterval { return Date(timeIntervalSince1970: seconds) }
        if let seconds = raw as? Int { return Date(timeIntervalSince1970: TimeInterval(seconds)) }
        if let number = raw as? NSNumber { return Date(timeIntervalSince1970: number.doubleValue) }
        return nil
    }

    private func intFromAny(_ raw: Any?) -> Int {
        if let intValue = raw as? Int { return intValue }
        if let num = raw as? NSNumber { return num.intValue }
        if let str = raw as? String, let intValue = Int(str) { return intValue }
        return 0
    }

    private func doubleFromAny(_ raw: Any?) -> Double {
        if let value = raw as? Double { return value }
        if let num = raw as? NSNumber { return num.doubleValue }
        if let str = raw as? String, let value = Double(str) { return value }
        return 0
    }
}
