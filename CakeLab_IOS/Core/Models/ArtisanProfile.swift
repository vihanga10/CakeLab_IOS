import Foundation
import FirebaseFirestore

// MARK: - ArtisanProfile  (Firestore-backed)
//
// Firestore collection: "artisans"
// Document fields:
//   name        : String    — baker's shop / display name
//   rating      : Double    — average rating 0.0–5.0
//   reviewCount : Int       — total review count
//   specialties : [String]  — e.g. ["Cupcakes", "Vegan", "3D Cakes"]
//   location    : String    — human-readable address
//   isOnline    : Bool      — whether the artisan is currently active/available
//   imageURL    : String?   — optional Firebase Storage URL for profile image
//   createdAt   : Timestamp — when the artisan profile was created

struct ArtisanProfile: Identifiable, Sendable {
    let id: String
    let name: String
    let rating: Double
    let reviewCount: Int
    let specialties: [String]
    let location: String
    let isOnline: Bool
    let imageURL: String?
    let latitude: Double
    let longitude: Double

    var ratingText: String    { String(format: "%.1f", rating) }
    var reviewsText: String   { "(\(reviewCount) reviews)" }
    var hasValidCoordinates: Bool { latitude != 0 || longitude != 0 }

    // MARK: - Init for manual creation (used in preview/mock)
    init(
        id: String,
        name: String,
        rating: Double,
        reviewCount: Int,
        specialties: [String],
        location: String,
        isOnline: Bool,
        imageURL: String?,
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.name = name
        self.rating = rating
        self.reviewCount = reviewCount
        self.specialties = specialties
        self.location = location
        self.isOnline = isOnline
        self.imageURL = imageURL
        self.latitude = latitude
        self.longitude = longitude
    }

    // MARK: - Init from Firestore DocumentSnapshot
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        let rawName = [
            data["name"] as? String,
            data["shopName"] as? String,
            data["displayName"] as? String
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first(where: { !$0.isEmpty })

        guard let name = rawName else { return nil }

        let location = [
            data["location"] as? String,
            data["address"] as? String,
            data["city"] as? String
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first(where: { !$0.isEmpty }) ?? ""

        let rating = Self.asDouble(data["rating"]) ?? 0
        let reviewCount = Self.asInt(data["reviewCount"]) ?? 0
        let latitude = Self.resolveLatitude(data)
        let longitude = Self.resolveLongitude(data)

        self.id          = document.documentID
        self.name        = name
        self.rating      = rating
        self.reviewCount = reviewCount
        self.specialties = data["specialties"] as? [String] ?? []
        self.location    = location
        self.isOnline    = data["isOnline"]    as? Bool     ?? false
        self.imageURL    = data["imageURL"]    as? String
        self.latitude    = latitude
        self.longitude   = longitude
    }

    private static func asDouble(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }

    private static func asInt(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? Double { return Int(value) }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private static func resolveLatitude(_ data: [String: Any]) -> Double {
        if let value = asDouble(data["latitude"]) { return value }
        if let geoPoint = data["coordinates"] as? GeoPoint { return geoPoint.latitude }
        if let geoPoint = data["locationPoint"] as? GeoPoint { return geoPoint.latitude }
        return 0
    }

    private static func resolveLongitude(_ data: [String: Any]) -> Double {
        if let value = asDouble(data["longitude"]) { return value }
        if let geoPoint = data["coordinates"] as? GeoPoint { return geoPoint.longitude }
        if let geoPoint = data["locationPoint"] as? GeoPoint { return geoPoint.longitude }
        return 0
    }
}
