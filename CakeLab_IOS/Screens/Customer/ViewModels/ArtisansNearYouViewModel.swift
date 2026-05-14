import Foundation
import Combine
import CoreLocation
import FirebaseFirestore

// MARK: - ArtisansNearYouViewModel
/// Loads artisan profiles from Firestore, merges data sources, and handles district filtering.
@MainActor
final class ArtisansNearYouViewModel: ObservableObject {
    @Published var artisans: [ArtisanProfile] = []
    @Published var scopedArtisans: [ArtisanProfile] = []
    @Published var isLoading = false
    @Published var selectedDistrict: String?
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private let geocoder = CLGeocoder()
    private var geocodeCache: [String: CLLocationCoordinate2D] = [:]
    private let customerDistrict: String?

    init(customerDistrict: String?) {
        self.customerDistrict = customerDistrict
        self.selectedDistrict = customerDistrict
    }

    func loadArtisansFromDatabase() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let snapshot = try await db.collection("artisans")
                .order(by: "rating", descending: true)
                .limit(to: 100)
                .getDocuments()

            let rawArtisans = snapshot.documents.compactMap(ArtisanProfile.init(document:))
            let userFallback = try await fetchBakersFromUsersCollection()
            let merged = mergeProfiles(primary: rawArtisans, fallback: userFallback)
            let hydrated = await hydrateMissingCoordinates(for: merged)

            artisans = hydrated
            if let customerDistrict {
                applyDistrictFilter(customerDistrict)
            } else {
                scopedArtisans = hydrated
            }

            if hydrated.isEmpty { errorMessage = "No artisan profiles available in database." }
        } catch {
            errorMessage = "Could not load bakers from database."
            print("ERROR ArtisansNearYouViewModel.loadArtisansFromDatabase: \(error.localizedDescription)")
        }
    }

    func filteredArtisans(searchText: String) -> [ArtisanProfile] {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return scopedArtisans }
        return scopedArtisans.filter { artisan in
            artisan.name.lowercased().contains(text)
            || artisan.location.lowercased().contains(text)
            || artisan.city.lowercased().contains(text)
            || artisan.specialties.contains(where: { $0.lowercased().contains(text) })
        }
    }

    func applyDistrictFilter(_ district: String) {
        let resolvedDistrict = SriLankaDistricts.canonical(district) ?? district
        selectedDistrict = resolvedDistrict
        errorMessage = nil
        let matches = artisans.filter { SriLankaDistricts.canonical($0.city) == resolvedDistrict }
        scopedArtisans = matches
        if matches.isEmpty { errorMessage = "No bakers found in \(resolvedDistrict)." }
    }

    func clearDistrictFilter() {
        selectedDistrict = nil
        errorMessage = nil
        scopedArtisans = artisans
    }

    // MARK: - Private Loaders

    private func fetchBakersFromUsersCollection() async throws -> [ArtisanProfile] {
        let snapshot = try await db.collection("users")
            .whereField("role", isEqualTo: "baker")
            .limit(to: 200)
            .getDocuments()

        var fallbackProfiles: [ArtisanProfile] = []
        fallbackProfiles.reserveCapacity(snapshot.documents.count)

        for document in snapshot.documents {
            guard let userData = document.data() as? [String: Any] else { continue }
            let artisanSnapshot = try await loadArtisanDocument(forUserID: document.documentID)
            let artisanData = artisanSnapshot?.data() ?? [:]
            let source = artisanData.isEmpty ? userData : artisanData
            let profileID = artisanSnapshot?.documentID ?? document.documentID

            let name = [
                source["name"] as? String, source["shopName"] as? String,
                userData["name"] as? String, userData["email"] as? String
            ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })

            guard let resolvedName = name else { continue }

            let city = SriLankaDistricts.canonical(source["city"] as? String)
                ?? SriLankaDistricts.detect(in: source["location"] as? String)
                ?? ""
            let address = (source["address"] as? String) ?? (userData["address"] as? String)
            let location = SriLankaDistricts.displayLocation(address: address, city: city)

            fallbackProfiles.append(ArtisanProfile(
                id: profileID, name: resolvedName,
                rating: asDouble(source["rating"]) ?? 0,
                reviewCount: asInt(source["reviewCount"]) ?? 0,
                specialties: (source["specialties"] as? [String] ?? [])
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty },
                city: city, location: location,
                isOnline: source["isOnline"] as? Bool ?? true,
                imageURL: (source["imageURL"] as? String) ?? (source["avatarURL"] as? String),
                profileImageBase64: source["profileImageBase64"] as? String ?? "",
                latitude: asDouble(source["latitude"]) ?? 0,
                longitude: asDouble(source["longitude"]) ?? 0
            ))
        }

        return fallbackProfiles
    }

    private func loadArtisanDocument(forUserID userID: String) async throws -> DocumentSnapshot? {
        let direct = try await db.collection("artisans").document(userID).getDocument()
        if direct.exists { return direct }
        let byUID = try await db.collection("artisans")
            .whereField("uid", isEqualTo: userID).limit(to: 1).getDocuments()
        return byUID.documents.first
    }

    private func mergeProfiles(primary: [ArtisanProfile], fallback: [ArtisanProfile]) -> [ArtisanProfile] {
        var map = Dictionary(uniqueKeysWithValues: primary.map { ($0.id, $0) })
        for profile in fallback where map[profile.id] == nil { map[profile.id] = profile }
        return map.values.sorted {
            if $0.rating == $1.rating {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.rating > $1.rating
        }
    }

    private func hydrateMissingCoordinates(for source: [ArtisanProfile]) async -> [ArtisanProfile] {
        var output: [ArtisanProfile] = []
        output.reserveCapacity(source.count)

        for artisan in source {
            if artisan.hasValidCoordinates || artisan.location.isEmpty {
                output.append(artisan); continue
            }
            if let cached = geocodeCache[artisan.location] {
                output.append(ArtisanProfile(
                    id: artisan.id, name: artisan.name, rating: artisan.rating,
                    reviewCount: artisan.reviewCount, specialties: artisan.specialties,
                    city: artisan.city, location: artisan.location, isOnline: artisan.isOnline,
                    imageURL: artisan.imageURL, profileImageBase64: artisan.profileImageBase64,
                    latitude: cached.latitude, longitude: cached.longitude
                ))
                continue
            }
            do {
                let query = SriLankaDistricts.geocodingQuery(address: artisan.location, city: artisan.city)
                let placemarks = try await geocoder.geocodeAddressString(query)
                if let coordinate = placemarks.first?.location?.coordinate {
                    geocodeCache[artisan.location] = coordinate
                    output.append(ArtisanProfile(
                        id: artisan.id, name: artisan.name, rating: artisan.rating,
                        reviewCount: artisan.reviewCount, specialties: artisan.specialties,
                        city: artisan.city, location: artisan.location, isOnline: artisan.isOnline,
                        imageURL: artisan.imageURL, profileImageBase64: artisan.profileImageBase64,
                        latitude: coordinate.latitude, longitude: coordinate.longitude
                    ))
                    continue
                }
            } catch {
                print("WARN geocode artisan failed: \(artisan.id) - \(error.localizedDescription)")
            }
            output.append(artisan)
        }

        return output
    }

    // MARK: - Type Helpers

    private func asDouble(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }

    private func asInt(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? Double { return Int(value) }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }
}
