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
    let referenceImageBase64: String?
    let bakerID: String?
    let bakerName: String?
    let bakerRating: String?
    let bakerReviewCount: Int?
    let bakerAddress: String?
    let bakerCity: String?
    let bakerProfileImageBase64: String?
    let bakerImageURL: String?
    let customerName: String?
    let customerAddress: String?
    let customerCity: String?
    let customerID: String?
    let customerProfileImageBase64: String?
    let customerImageURL: String?
}

private struct WidgetBakerProfile {
    let name: String
    let ratingText: String
    let reviewCount: Int
    let address: String
    let city: String
    let profileImageBase64: String
    let imageURL: String
}

private struct WidgetCustomerProfile {
    let name: String
    let address: String
    let city: String
    let profileImageBase64: String
    let imageURL: String
}

struct WidgetMatchingRequestSummary: Codable, Hashable {
    let id: String
    let title: String
    let category: String
    let location: String
    let referenceImageBase64: String?
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

        let orders = snapshot.documents
            .compactMap(makeOrderSummary)
            .sorted { $0.deliveryDate < $1.deliveryDate }

        return await enrichCustomerOrdersWithBakerProfiles(orders)
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

        let orders = map.values.sorted { $0.deliveryDate < $1.deliveryDate }
        return await enrichBakerOrdersWithCustomerProfiles(orders)
    }

    private func enrichCustomerOrdersWithBakerProfiles(_ orders: [WidgetOrderSummary]) async -> [WidgetOrderSummary] {
        var cache: [String: WidgetBakerProfile] = [:]
        var enriched: [WidgetOrderSummary] = []
        enriched.reserveCapacity(orders.count)

        for order in orders {
            guard let bakerID = order.bakerID?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !bakerID.isEmpty else {
                enriched.append(order)
                continue
            }

            let profile: WidgetBakerProfile
            if let cached = cache[bakerID] {
                profile = cached
            } else {
                profile = await fetchBakerProfile(bakerID: bakerID)
                cache[bakerID] = profile
            }

            enriched.append(
                WidgetOrderSummary(
                    id: order.id,
                    cakeName: order.cakeName,
                    status: order.status,
                    currentStep: order.currentStep,
                    deliveryDate: order.deliveryDate,
                    counterpartName: profile.name.isEmpty ? order.counterpartName : profile.name,
                    referenceImageBase64: order.referenceImageBase64,
                    bakerID: bakerID,
                    bakerName: profile.name.isEmpty ? order.bakerName : profile.name,
                    bakerRating: profile.ratingText.isEmpty ? order.bakerRating : profile.ratingText,
                    bakerReviewCount: profile.reviewCount,
                    bakerAddress: profile.address.isEmpty ? order.bakerAddress : profile.address,
                    bakerCity: profile.city.isEmpty ? order.bakerCity : profile.city,
                    bakerProfileImageBase64: profile.profileImageBase64,
                    bakerImageURL: profile.imageURL,
                    customerName: order.customerName,
                    customerAddress: order.customerAddress,
                    customerCity: order.customerCity,
                    customerID: order.customerID,
                    customerProfileImageBase64: order.customerProfileImageBase64,
                    customerImageURL: order.customerImageURL
                )
            )
        }

        return enriched
    }

    private func fetchBakerProfile(bakerID: String) async -> WidgetBakerProfile {
        async let artisanProfile = fetchProfileData(collection: "artisans", documentID: bakerID)
        async let userProfile = fetchProfileData(collection: "users", documentID: bakerID)
        async let liveReviewStats = fetchBakerReviewStats(bakerID: bakerID)

        let (artisanData, userData, reviewStats) = await (artisanProfile, userProfile, liveReviewStats)
        let primaryData = artisanData ?? [:]
        let fallbackData = userData ?? [:]

        let rating = reviewStats?.rating ?? doubleFromAny(primaryData["rating"])
        let reviewCount = reviewStats?.count ?? intFromAny(primaryData["reviewCount"])
        let ratingText = rating > 0
            ? String(format: "%.1f", rating)
            : firstString(primaryData["artisanRating"], fallbackData["artisanRating"])

        return WidgetBakerProfile(
            name: firstString(primaryData["shopName"], primaryData["name"], fallbackData["name"]),
            ratingText: ratingText,
            reviewCount: reviewCount,
            address: firstString(primaryData["address"], primaryData["location"], fallbackData["address"]),
            city: firstString(primaryData["city"], fallbackData["city"]),
            profileImageBase64: firstString(primaryData["profileImageBase64"], fallbackData["profileImageBase64"]),
            imageURL: firstString(primaryData["imageURL"], primaryData["avatarURL"], fallbackData["imageURL"], fallbackData["avatarURL"])
        )
    }

    private func fetchProfileData(collection: String, documentID: String) async -> [String: Any]? {
        do {
            let document = try await db.collection(collection).document(documentID).getDocument()
            return document.data()
        } catch {
            return nil
        }
    }

    private func fetchBakerReviewStats(bakerID: String) async -> (rating: Double, count: Int)? {
        let trimmedID = bakerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return nil }

        var ratingsByID: [String: Int] = [:]
        for key in ["bakerID", "bakerId", "artisanId"] {
            do {
                let snapshot = try await db.collection("reviews")
                    .whereField(key, isEqualTo: trimmedID)
                    .getDocuments()

                for document in snapshot.documents {
                    let rating = intFromAny(document.data()["rating"])
                    if rating > 0 { ratingsByID[document.documentID] = rating }
                }
            } catch {
                print("Widget review stats failed for baker \(trimmedID) by \(key): \(error.localizedDescription)")
            }
        }

        let ratings = Array(ratingsByID.values)
        guard !ratings.isEmpty else { return nil }

        let average = Double(ratings.reduce(0, +)) / Double(ratings.count)
        return (average, ratings.count)
    }

    private func enrichBakerOrdersWithCustomerProfiles(_ orders: [WidgetOrderSummary]) async -> [WidgetOrderSummary] {
        var cache: [String: WidgetCustomerProfile] = [:]
        var enriched: [WidgetOrderSummary] = []
        enriched.reserveCapacity(orders.count)

        for order in orders {
            guard let customerID = order.customerID?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !customerID.isEmpty else {
                enriched.append(order)
                continue
            }

            let profile: WidgetCustomerProfile
            if let cached = cache[customerID] {
                profile = cached
            } else {
                profile = await fetchCustomerProfile(customerID: customerID, fallback: order)
                cache[customerID] = profile
            }

            enriched.append(
                WidgetOrderSummary(
                    id: order.id,
                    cakeName: order.cakeName,
                    status: order.status,
                    currentStep: order.currentStep,
                    deliveryDate: order.deliveryDate,
                    counterpartName: profile.name.isEmpty ? order.counterpartName : profile.name,
                    referenceImageBase64: order.referenceImageBase64,
                    bakerID: order.bakerID,
                    bakerName: order.bakerName,
                    bakerRating: order.bakerRating,
                    bakerReviewCount: order.bakerReviewCount,
                    bakerAddress: order.bakerAddress,
                    bakerCity: order.bakerCity,
                    bakerProfileImageBase64: order.bakerProfileImageBase64,
                    bakerImageURL: order.bakerImageURL,
                    customerName: profile.name.isEmpty ? order.customerName : profile.name,
                    customerAddress: profile.address.isEmpty ? order.customerAddress : profile.address,
                    customerCity: profile.city.isEmpty ? order.customerCity : profile.city,
                    customerID: customerID,
                    customerProfileImageBase64: profile.profileImageBase64.isEmpty ? order.customerProfileImageBase64 : profile.profileImageBase64,
                    customerImageURL: profile.imageURL.isEmpty ? order.customerImageURL : profile.imageURL
                )
            )
        }

        return enriched
    }

    private func fetchCustomerProfile(customerID: String, fallback order: WidgetOrderSummary) async -> WidgetCustomerProfile {
        do {
            let snapshot = try await db.collection("users").document(customerID).getDocument()
            let data = snapshot.data() ?? [:]
            return WidgetCustomerProfile(
                name: firstString(order.customerName, data["name"], data["fullName"], data["email"], customerID),
                address: firstString(order.customerAddress, data["address"]),
                city: firstString(order.customerCity, data["city"]),
                profileImageBase64: firstString(
                    order.customerProfileImageBase64,
                    data["profileImageBase64"],
                    data["avatarBase64"],
                    data["customerProfileImageBase64"],
                    data["customerImageBase64"],
                    data["customerImage"],
                    data["photoBase64"]
                ),
                imageURL: firstString(order.customerImageURL, data["imageURL"], data["avatarURL"], data["photoURL"], data["customerImageURL"], data["customerAvatarURL"])
            )
        } catch {
            return WidgetCustomerProfile(
                name: order.customerName ?? "",
                address: order.customerAddress ?? "",
                city: order.customerCity ?? "",
                profileImageBase64: order.customerProfileImageBase64 ?? "",
                imageURL: order.customerImageURL ?? ""
            )
        }
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
                location: displayLocation(
                    address: firstString(data["customerAddress"], data["deliveryAddress"], data["address"]),
                    city: firstString(data["customerCity"], data["deliveryCity"], data["city"])
                ),
                referenceImageBase64: (data["referenceImages"] as? [String])?.first,
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
        let bakerID = firstString(data["artisanId"], data["bakerID"], data["bakerId"])
        let customerID = firstString(data["customerId"], data["customerID"])
        let counterpart = (data["artisanName"] as? String)
            ?? (data["customerName"] as? String)
            ?? (data["customerEmail"] as? String)
            ?? "CakeLab"
        let referenceImageBase64 = (data["referenceImages"] as? [String])?.first

        return WidgetOrderSummary(
            id: document.documentID,
            cakeName: cakeName,
            status: status,
            currentStep: max(1, min(5, currentStep == 0 ? 1 : currentStep)),
            deliveryDate: deliveryDate,
            counterpartName: counterpart,
            referenceImageBase64: referenceImageBase64,
            bakerID: bakerID,
            bakerName: firstString(data["artisanName"], data["bakerName"]),
            bakerRating: firstString(data["artisanRating"], data["bakerRating"]),
            bakerReviewCount: intFromAny(data["bakerReviewCount"]),
            bakerAddress: firstString(data["artisanAddress"], data["bakerAddress"]),
            bakerCity: firstString(data["bakerCity"]),
            bakerProfileImageBase64: firstString(data["bakerProfileImageBase64"]),
            bakerImageURL: firstString(data["bakerImageURL"]),
            customerName: firstString(data["customerName"], data["customerEmail"]),
            customerAddress: firstString(data["customerAddress"], data["deliveryAddress"], data["address"]),
            customerCity: firstString(data["customerCity"], data["deliveryCity"], data["city"]),
            customerID: customerID,
            customerProfileImageBase64: firstString(data["customerProfileImageBase64"], data["customerImageBase64"], data["customerImage"]),
            customerImageURL: firstString(data["customerImageURL"], data["customerAvatarURL"])
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

    private func firstString(_ values: Any?...) -> String {
        values.compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    private func displayLocation(address: String?, city: String?) -> String {
        let trimmedAddress = address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedCity = city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if trimmedAddress.isEmpty { return trimmedCity.isEmpty ? "Location not provided" : trimmedCity }
        if trimmedCity.isEmpty || trimmedAddress.localizedCaseInsensitiveContains(trimmedCity) { return trimmedAddress }
        return "\(trimmedAddress), \(trimmedCity)"
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
