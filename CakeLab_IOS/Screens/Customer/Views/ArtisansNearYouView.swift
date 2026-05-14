import SwiftUI
import MapKit
import CoreLocation
import UIKit

// MARK: - Artisans Near You View
@MainActor
struct ArtisansNearYouView: View {
    let user: AppUser
    @Environment(\.dismiss) var dismiss

    @StateObject private var viewModel: ArtisansNearYouViewModel
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

    init(user: AppUser) {
        self.user = user
        _viewModel = StateObject(
            wrappedValue: ArtisansNearYouViewModel(
                customerDistrict: SriLankaDistricts.canonical(user.city)
            )
        )
    }

    private var filteredArtisans: [ArtisanProfile] {
        viewModel.filteredArtisans(searchText: searchText)
    }

    private var mapArtisans: [ArtisanProfile] {
        filteredArtisans.filter(\.hasValidCoordinates)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.cakeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                VStack(spacing: 0) {
                    Map(position: $position) {
                        ForEach(mapArtisans, id: \.id) { artisan in
                            Annotation("", coordinate: CLLocationCoordinate2D(latitude: artisan.latitude, longitude: artisan.longitude)) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        selectedArtisan = selectedArtisan?.id == artisan.id ? nil : artisan
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        // Bubble above the pin — visible only for the selected artisan
                                        if selectedArtisan?.id == artisan.id {
                                            mapPinPopup(for: artisan)
                                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                                        }

                                        // Pin icon
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
                    }
                    .mapStyle(.standard)
                    .frame(height: 280)
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
                                    .foregroundColor(.cakePrimaryText)
                                    .tint(.cakeBrown)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.94, green: 0.94, blue: 0.94))
                            .clipShape(Capsule())
                            .padding(.horizontal, 20)

                            HStack(spacing: 12) {
                                Button {
                                    showDistrictPicker = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "list.bullet.circle.fill")
                                            .font(.system(size: 14))
                                        Text(viewModel.selectedDistrict ?? "Select district")
                                            .font(.urbanistRegular(13))
                                    }
                                    .foregroundColor(Color(hex: "5D3714"))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color(hex: "E9E5E1"))
                                    .cornerRadius(8)
                                }

                                Spacer()

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
                            }
                            .padding(.horizontal, 20)

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
                            .foregroundColor(.cakePrimaryText)
                            .padding(.top, 24)
                            .padding(.bottom, 16)

                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                artisanImageView(artisan: artisan, size: 60, cornerRadius: 10)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(artisan.name)
                                        .font(.urbanistBold(14))
                                        .foregroundColor(.cakePrimaryText)

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
                            .background(Color.cakeSurface)
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
                    .background(Color.cakeSurface)
                    .cornerRadius(16)
                    .padding(.horizontal, 24)
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .task {
            await viewModel.loadArtisansFromDatabase()
            moveToBestVisibleRegion()
        }
        .onChange(of: filteredArtisans.map(\.id)) { _, _ in
            moveToBestVisibleRegion(onlyIfAutomatic: true)
        }
        .sheet(isPresented: $showDistrictPicker) {
            DistrictPickerSheet(
                districts: SriLankaDistricts.all,
                selectedDistrict: viewModel.selectedDistrict,
                onSelect: { district in
                    viewModel.applyDistrictFilter(district)
                    moveToBestVisibleRegion()
                    showDistrictPicker = false
                }
            )
            .presentationDetents([.medium, .large])
        }
        .asCustomerSubScreen()
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

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cakeBrown)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("Artisans Near You")
                    .font(.urbanistBold(18))
                    .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
            }
            Spacer()
            Color.white.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.cakeSurface)
    }

    @ViewBuilder
    private func artisanImageView(artisan: ArtisanProfile, size: CGFloat, cornerRadius: CGFloat) -> some View {
        if let image = decodeBase64Image(artisan.profileImageBase64) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipped()
                .cornerRadius(cornerRadius)
        } else if let rawURL = artisan.imageURL,
                  !rawURL.isEmpty,
                  let imageURL = URL(string: rawURL) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    imageFallback(size: size)
                }
            }
            .frame(width: size, height: size)
            .clipped()
            .cornerRadius(cornerRadius)
        } else {
            imageFallback(size: size)
                .cornerRadius(cornerRadius)
        }
    }

    @ViewBuilder
    private func imageFallback(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                .frame(width: size, height: size)
            Image(systemName: "storefront.fill")
                .font(.system(size: max(20, size * 0.38)))
                .foregroundColor(.cakeBrown.opacity(0.5))
        }
    }

    private func decodeBase64Image(_ rawBase64: String) -> UIImage? {
        let trimmed = rawBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let payload: String
        if let commaIndex = trimmed.firstIndex(of: ",") {
            payload = String(trimmed[trimmed.index(after: commaIndex)...])
        } else {
            payload = trimmed
        }

        guard let data = Data(base64Encoded: payload) else { return nil }
        return UIImage(data: data)
    }

    @ViewBuilder
    private func mapPinPopup(for artisan: ArtisanProfile) -> some View {
        VStack(spacing: 0) {
            // Bubble card
            VStack(alignment: .leading, spacing: 5) {
                Text(artisan.name)
                    .font(.urbanistSemiBold(12))
                    .foregroundColor(.cakePrimaryText)
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.1))
                    Text("\(artisan.ratingText)  \(artisan.reviewsText)")
                        .font(.urbanistRegular(10))
                        .foregroundColor(.cakeGrey)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.cakeSurface)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 3)

            // Downward-pointing tail
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 9))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
                .offset(y: -1)
        }
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
    private let chipPalette: [Color] = [
        Color(red: 0.88, green: 0.88, blue: 0.97),
        Color(red: 0.95, green: 0.85, blue: 0.76),
        Color(red: 0.86, green: 0.94, blue: 0.90),
        Color(red: 0.98, green: 0.90, blue: 0.82)
    ]

    private var displaySpecialties: [String] {
        let trimmed = artisan.specialties
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return trimmed.isEmpty ? ["No category"] : trimmed
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    // Left: image
                    artisanImage(size: 80)

                    // Right: name, rating, specialty chips
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Text(artisan.name)
                                .font(.urbanistBold(15))
                                .foregroundColor(Color(hex: "5D3714"))
                                .lineLimit(1)
                            Spacer()
                            Circle()
                                .fill(artisan.isOnline ? Color(red: 0.15, green: 0.72, blue: 0.25) : Color.gray.opacity(0.45))
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke((artisan.isOnline ? Color(red: 0.15, green: 0.72, blue: 0.25) : Color.gray.opacity(0.45)).opacity(0.25), lineWidth: 5)
                                )
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(red: 1.0, green: 0.88, blue: 0.0))
                            Text("\(artisan.ratingText) \(artisan.reviewsText)")
                                .font(.urbanistRegular(13))
                                .foregroundColor(Color(hex: "5B5B5B"))
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(displaySpecialties.prefix(3).enumerated()), id: \.element) { index, tag in
                                    Text(tag)
                                        .font(.urbanistMedium(12))
                                        .foregroundColor(Color(hex: "5D3714"))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(chipPalette[index % chipPalette.count])
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                // Full-width location row — no truncation, shows complete address
                if !artisan.location.isEmpty {
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: "mappin")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "7C7C7C"))
                            .padding(.top, 1)
                        Text(artisan.location)
                            .font(.urbanistRegular(12))
                            .foregroundColor(Color(hex: "434343"))
                    }
                    .padding(.top, 10)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.cakeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.cakeStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func artisanImage(size: CGFloat) -> some View {
        if let image = decodeBase64Image(artisan.profileImageBase64) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipped()
                .cornerRadius(14)
        } else if let rawURL = artisan.imageURL,
                  !rawURL.isEmpty,
                  let imageURL = URL(string: rawURL) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    artisanImageFallback(size: size)
                }
            }
            .frame(width: size, height: size)
            .clipped()
            .cornerRadius(14)
        } else {
            artisanImageFallback(size: size)
        }
    }

    @ViewBuilder
    private func artisanImageFallback(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                .frame(width: size, height: size)
            Image(systemName: "storefront.fill")
                .font(.system(size: max(24, size * 0.32)))
                .foregroundColor(.cakeBrown.opacity(0.5))
        }
        .frame(width: size, height: size)
    }

    private func decodeBase64Image(_ rawBase64: String) -> UIImage? {
        let trimmed = rawBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let payload: String
        if let commaIndex = trimmed.firstIndex(of: ",") {
            payload = String(trimmed[trimmed.index(after: commaIndex)...])
        } else {
            payload = trimmed
        }

        guard let data = Data(base64Encoded: payload) else { return nil }
        return UIImage(data: data)
    }
}

#Preview {
    NavigationStack {
        ArtisansNearYouView(user: .mock)
    }
}
