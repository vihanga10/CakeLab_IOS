import SwiftUI
import MapKit
import CoreLocation
import Combine
import FirebaseFirestore

// MARK: - Artisans Near You View
@MainActor
struct ArtisansNearYouView: View {
    let user: AppUser
    @Environment(\.dismiss) var dismiss

    @StateObject private var viewModel = ArtisansNearYouViewModel()
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 7.8731, longitude: 80.7718),
            span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
        )
    )
    @State private var selectedArtisan: ArtisanProfile?
    @State private var showConfirmation = false
    @State private var searchText = ""
    @State private var showDistrictPicker = false

    private var filteredArtisans: [ArtisanProfile] {
        viewModel.filteredArtisans(searchText: searchText)
    }

    private var mapArtisans: [ArtisanProfile] {
        filteredArtisans.filter(\.hasValidCoordinates)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.cakeBrown)
                    }
                    Spacer()
                    Text("Artisans Near You")
                        .font(.urbanistBold(18))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18))
                            .foregroundColor(.cakeBrown)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 2)

                VStack(spacing: 0) {
                    Map(position: $position) {
                        ForEach(mapArtisans, id: \.id) { artisan in
                            Annotation("", coordinate: CLLocationCoordinate2D(latitude: artisan.latitude, longitude: artisan.longitude)) {
                                Button {
                                    selectedArtisan = artisan
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color.cakeBrown)
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "fork.knife")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                    }
                    .mapStyle(.standard)
                    .frame(height: 280)
                    .overlay(alignment: .topLeading) {
                        if let artisan = selectedArtisan {
                            mapPinPopup(for: artisan)
                                .padding(.top, 12)
                                .padding(.leading, 12)
                        }
                    }
                    .overlay(alignment: .bottomLeading) {
                        if let district = viewModel.selectedDistrict {
                            Label("District: \(district)", systemImage: "mappin.and.ellipse")
                                .font(.urbanistRegular(11))
                                .foregroundColor(.cakeBrown)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.92))
                                .clipShape(Capsule())
                                .padding(10)
                        }
                    }

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 15))
                                    .foregroundColor(.cakeGrey)
                                TextField("Search bakers or specialties...", text: $searchText)
                                    .font(.urbanistRegular(14))
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                    .tint(.cakeBrown)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.94, green: 0.94, blue: 0.94))
                            .clipShape(Capsule())
                            .padding(.horizontal, 20)

                            Button {
                                showDistrictPicker = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "list.bullet.circle.fill")
                                        .font(.system(size: 14))
                                    Text(viewModel.selectedDistrict == nil ? "Select district" : "Change district")
                                        .font(.urbanistRegular(13))
                                }
                                .foregroundColor(Color(red: 0.7, green: 0.5, blue: 0.2))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color(red: 0.97, green: 0.95, blue: 0.92))
                                .cornerRadius(8)
                            }
                            .padding(.horizontal, 20)

                            if viewModel.selectedDistrict != nil {
                                Button {
                                    viewModel.clearDistrictFilter()
                                    moveToBestVisibleRegion()
                                } label: {
                                    Text("Show all districts")
                                        .font(.urbanistRegular(12))
                                        .foregroundColor(.cakeGrey)
                                }
                            }

                            if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .font(.urbanistRegular(12))
                                    .foregroundColor(.red.opacity(0.75))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                            }

                            if viewModel.isLoading {
                                ProgressView("Loading bakers from database...")
                                    .font(.urbanistRegular(12))
                                    .padding(.top, 12)
                            }

                            if !viewModel.isLoading && filteredArtisans.isEmpty {
                                Text("No bakers found for this district.")
                                    .font(.urbanistRegular(13))
                                    .foregroundColor(.cakeGrey)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 16)
                            }

                            VStack(spacing: 12) {
                                ForEach(filteredArtisans, id: \.id) { artisan in
                                    ArtisanNearCard(
                                        artisan: artisan,
                                        onTap: {
                                            selectedArtisan = artisan
                                            showConfirmation = true
                                            centerMap(on: artisan)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .padding(.vertical, 16)
                    }
                }
            }

            if showConfirmation, let artisan = selectedArtisan {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showConfirmation = false
                        }

                    VStack(spacing: 0) {
                        Text("Send Cake Request?")
                            .font(.urbanistBold(18))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            .padding(.top, 24)
                            .padding(.bottom, 16)

                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                                        .frame(width: 60, height: 60)
                                    Image(systemName: "storefront.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.cakeBrown.opacity(0.5))
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(artisan.name)
                                        .font(.urbanistBold(14))
                                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                                    HStack(spacing: 4) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.1))
                                        Text("\(String(format: "%.1f", artisan.rating)) (\(artisan.reviewCount) reviews)")
                                            .font(.urbanistRegular(11))
                                            .foregroundColor(.cakeGrey)
                                    }

                                    HStack(spacing: 5) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(.cakeGrey)
                                        Text(artisan.location)
                                            .font(.urbanistRegular(10))
                                            .foregroundColor(.cakeGrey)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Circle()
                                    .fill(Color(red: 0.15, green: 0.72, blue: 0.25))
                                    .frame(width: 10, height: 10)
                            }
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                        Divider()

                        HStack(spacing: 12) {
                            Button(action: {
                                showConfirmation = false
                            }) {
                                Text("Cancel")
                                    .font(.urbanistSemiBold(14))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(red: 0.94, green: 0.94, blue: 0.94))
                                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                                    .cornerRadius(10)
                            }

                            NavigationLink(destination: CreateCakeRequestView(user: user, selectedArtisan: artisan)) {
                                Text("Send Request")
                                    .font(.urbanistSemiBold(14))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.cakeBrown)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .background(Color.white)
                    .cornerRadius(16)
                    .padding(.horizontal, 24)
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await viewModel.loadArtisansFromDatabase()
            moveToBestVisibleRegion()
        }
        .onChange(of: filteredArtisans.map(\.id)) { _, _ in
            moveToBestVisibleRegion(onlyIfAutomatic: true)
        }
        .sheet(isPresented: $showDistrictPicker) {
            DistrictPickerSheet(
                districts: viewModel.sriLankanDistricts,
                selectedDistrict: viewModel.selectedDistrict,
                onSelect: { district in
                    viewModel.applyDistrictFilter(district)
                    moveToBestVisibleRegion()
                    showDistrictPicker = false
                }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private func centerMap(on artisan: ArtisanProfile) {
        guard artisan.hasValidCoordinates else { return }
        withAnimation {
            position = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: artisan.latitude, longitude: artisan.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
                )
            )
        }
    }

    private func moveToBestVisibleRegion(onlyIfAutomatic: Bool = false) {
        guard let first = mapArtisans.first else { return }
        if onlyIfAutomatic,
           case .automatic = position {
            centerMap(on: first)
            return
        }
        if !onlyIfAutomatic {
            centerMap(on: first)
        }
    }

    @ViewBuilder
    private func mapPinPopup(for artisan: ArtisanProfile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(artisan.name)
                .font(.urbanistSemiBold(12))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.1))
                Text("\(artisan.ratingText)  \(artisan.reviewsText)")
                    .font(.urbanistRegular(10))
                    .foregroundColor(.cakeGrey)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
    }
}

@MainActor
private final class ArtisansNearYouViewModel: ObservableObject {
    @Published var artisans: [ArtisanProfile] = []
    @Published var scopedArtisans: [ArtisanProfile] = []
    @Published var isLoading = false
    @Published var selectedDistrict: String?
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private let geocoder = CLGeocoder()
    private var geocodeCache: [String: CLLocationCoordinate2D] = [:]

    let sriLankanDistricts: [String] = [
        "Ampara", "Anuradhapura", "Badulla", "Batticaloa", "Colombo", "Galle", "Gampaha", "Hambantota", "Jaffna", "Kalutara", "Kandy", "Kegalle", "Kilinochchi", "Kurunegala", "Mannar", "Matale", "Matara", "Monaragala", "Mullaitivu", "Nuwara Eliya", "Polonnaruwa", "Puttalam", "Ratnapura", "Trincomalee", "Vavuniya"
    ]

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
            scopedArtisans = hydrated

            if hydrated.isEmpty {
                errorMessage = "No artisan profiles available in database."
            }
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
            || artisan.specialties.contains(where: { $0.lowercased().contains(text) })
        }
    }

    func applyDistrictFilter(_ district: String) {
        selectedDistrict = district
        errorMessage = nil

        let normalizedDistrict = normalize(district)
        let districtCompact = normalizedDistrict.replacingOccurrences(of: " ", with: "")
        let matches = artisans.filter { artisan in
            let locationText = normalize(artisan.location)
            if locationText.contains(normalizedDistrict) {
                return true
            }
            if locationText.contains("\(normalizedDistrict) district") {
                return true
            }
            let compactLocationText = locationText.replacingOccurrences(of: " ", with: "")
            if compactLocationText.contains(districtCompact) {
                return true
            }
            return false
        }

        scopedArtisans = matches
        if matches.isEmpty {
            errorMessage = "No bakers found in \(district)."
        }
    }

    func clearDistrictFilter() {
        selectedDistrict = nil
        errorMessage = nil
        scopedArtisans = artisans
    }

    private func normalize(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func fetchBakersFromUsersCollection() async throws -> [ArtisanProfile] {
        let snapshot = try await db.collection("users")
            .whereField("role", isEqualTo: "baker")
            .limit(to: 200)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            guard let data = document.data() as? [String: Any] else { return nil }

            let name = [
                data["name"] as? String,
                data["shopName"] as? String,
                data["email"] as? String
            ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })

            guard let resolvedName = name else { return nil }

            let address = [
                data["address"] as? String,
                data["city"] as? String,
                data["location"] as? String
            ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""

            let latitude = asDouble(data["latitude"]) ?? 0
            let longitude = asDouble(data["longitude"]) ?? 0
            let rating = asDouble(data["rating"]) ?? 0
            let reviewCount = asInt(data["reviewCount"]) ?? 0

            return ArtisanProfile(
                id: document.documentID,
                name: resolvedName,
                rating: rating,
                reviewCount: reviewCount,
                specialties: data["specialties"] as? [String] ?? [],
                location: address,
                isOnline: data["isOnline"] as? Bool ?? true,
                imageURL: data["imageURL"] as? String,
                latitude: latitude,
                longitude: longitude
            )
        }
    }

    private func mergeProfiles(primary: [ArtisanProfile], fallback: [ArtisanProfile]) -> [ArtisanProfile] {
        var map = Dictionary(uniqueKeysWithValues: primary.map { ($0.id, $0) })
        for profile in fallback where map[profile.id] == nil {
            map[profile.id] = profile
        }

        return map.values.sorted {
            if $0.rating == $1.rating {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.rating > $1.rating
        }
    }

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

    private func hydrateMissingCoordinates(for source: [ArtisanProfile]) async -> [ArtisanProfile] {
        var output: [ArtisanProfile] = []
        output.reserveCapacity(source.count)

        for artisan in source {
            if artisan.hasValidCoordinates || artisan.location.isEmpty {
                output.append(artisan)
                continue
            }

            if let cached = geocodeCache[artisan.location] {
                output.append(
                    ArtisanProfile(
                        id: artisan.id,
                        name: artisan.name,
                        rating: artisan.rating,
                        reviewCount: artisan.reviewCount,
                        specialties: artisan.specialties,
                        location: artisan.location,
                        isOnline: artisan.isOnline,
                        imageURL: artisan.imageURL,
                        latitude: cached.latitude,
                        longitude: cached.longitude
                    )
                )
                continue
            }

            do {
                let placemarks = try await geocoder.geocodeAddressString(artisan.location)
                if let coordinate = placemarks.first?.location?.coordinate {
                    geocodeCache[artisan.location] = coordinate
                    output.append(
                        ArtisanProfile(
                            id: artisan.id,
                            name: artisan.name,
                            rating: artisan.rating,
                            reviewCount: artisan.reviewCount,
                            specialties: artisan.specialties,
                            location: artisan.location,
                            isOnline: artisan.isOnline,
                            imageURL: artisan.imageURL,
                            latitude: coordinate.latitude,
                            longitude: coordinate.longitude
                        )
                    )
                    continue
                }
            } catch {
                print("WARN geocode artisan failed: \(artisan.id) - \(error.localizedDescription)")
            }

            output.append(artisan)
        }

        return output
    }
}

private struct DistrictPickerSheet: View {
    let districts: [String]
    let selectedDistrict: String?
    let onSelect: (String) -> Void

    var body: some View {
        NavigationStack {
            List(districts, id: \.self) { district in
                Button {
                    onSelect(district)
                } label: {
                    HStack {
                        Text(district)
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedDistrict == district {
                            Image(systemName: "checkmark")
                                .foregroundColor(.cakeBrown)
                        }
                    }
                }
            }
            .navigationTitle("Select District")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Artisan Near Card Component
struct ArtisanNearCard: View {
    let artisan: ArtisanProfile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                            .frame(width: 72, height: 72)
                        Image(systemName: "storefront.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.cakeBrown.opacity(0.5))
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(artisan.name)
                            .font(.urbanistBold(14))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.1))
                            Text(artisan.ratingText)
                                .font(.urbanistSemiBold(12))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            Text(artisan.reviewsText)
                                .font(.urbanistRegular(11))
                                .foregroundColor(.cakeGrey)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(artisan.specialties, id: \.self) { tag in
                                    Text(tag)
                                        .font(.urbanistRegular(10))
                                        .foregroundColor(.cakeBrown)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.cakeBrown.opacity(0.12))
                                        .cornerRadius(10)
                                }
                            }
                        }
                    }
                    Spacer()
                    Circle()
                        .fill(artisan.isOnline ? Color(red: 0.15, green: 0.72, blue: 0.25) : Color.gray.opacity(0.4))
                        .frame(width: 11, height: 11)
                }
                HStack(spacing: 5) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.cakeGrey)
                    Text(artisan.location)
                        .font(.urbanistRegular(11))
                        .foregroundColor(.cakeGrey)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
    }
}

#Preview {
    NavigationStack {
        ArtisansNearYouView(user: .mock)
    }
}
