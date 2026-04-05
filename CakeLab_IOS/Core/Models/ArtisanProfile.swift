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
        guard
            let data     = document.data(),
            let name     = data["name"]     as? String,
            let rating   = data["rating"]   as? Double,
            let location = data["location"] as? String,
            let latitude   = data["latitude"]   as? Double,
            let longitude  = data["longitude"]  as? Double
        else { return nil }

        self.id          = document.documentID
        self.name        = name
        self.rating      = rating
        self.reviewCount = data["reviewCount"] as? Int      ?? 0
        self.specialties = data["specialties"] as? [String] ?? []
        self.location    = location
        self.isOnline    = data["isOnline"]    as? Bool     ?? false
        self.imageURL    = data["imageURL"]    as? String
        self.latitude    = latitude
        self.longitude   = longitude
    }
}
