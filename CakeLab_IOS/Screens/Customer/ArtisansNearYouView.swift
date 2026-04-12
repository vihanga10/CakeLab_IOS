import SwiftUI
import MapKit

// MARK: - Artisans Near You View
@MainActor
struct ArtisansNearYouView: View {
    let user: AppUser
    @Environment(\.dismiss) var dismiss
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedArtisan: ArtisanProfile?
    @State private var showConfirmation = false
    @State private var searchText = ""
    
    // Mock artisans data — in production, fetch from Firestore
    private let artisans: [ArtisanProfile] = [
        ArtisanProfile(
            id: "artisan-001",
            name: "Butter Boutique",
            rating: 5.0,
            reviewCount: 41,
            specialties: ["Cupcakes", "Vegan", "3D Cakes"],
            location: "70 Rosmead Place, Colombo 07, Sri Lanka",
            isOnline: true,
            imageURL: nil,
            latitude: 6.9271,
            longitude: 80.7789
        ),
        ArtisanProfile(
            id: "artisan-002",
            name: "Patisserie",
            rating: 4.7,
            reviewCount: 33,
            specialties: ["Birthday", "Vegan", "Wedding Cakes"],
            location: "379 R.A. De Mel Mawatha, Colombo 03",
            isOnline: true,
            imageURL: nil,
            latitude: 6.9182,
            longitude: 80.7654
        ),
        ArtisanProfile(
            id: "artisan-003",
            name: "Frost & Crumb",
            rating: 4.8,
            reviewCount: 79,
            specialties: ["Cupcakes", "Lava Cakes"],
            location: "493 Dematagoda Road, Colombo 09",
            isOnline: true,
            imageURL: nil,
            latitude: 6.9089,
            longitude: 80.7456
        )
    ]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // MARK: - Header
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
                    // MARK: - Map
                    Map(position: $position) {
                        ForEach(artisans, id: \.id) { artisan in
                            Annotation("", coordinate: CLLocationCoordinate2D(latitude: artisan.latitude, longitude: artisan.longitude)) {
                                ZStack {
                                    Circle()
                                        .fill(Color.cakeBrown)
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .onTapGesture {
                                    selectedArtisan = artisan
                                }
                            }
                        }
                    }
                    .mapStyle(.standard)
                    .frame(height: 280)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            // MARK: - Search Bar
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

                            // MARK: - Location Button
                            Button(action: {}) {
                                HStack(spacing: 8) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 14))
                                    Text("Use my current location")
                                        .font(.urbanistRegular(13))
                                }
                                .foregroundColor(Color(red: 0.7, green: 0.5, blue: 0.2))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color(red: 0.97, green: 0.95, blue: 0.92))
                                .cornerRadius(8)
                            }
                            .padding(.horizontal, 20)

                            // MARK: - Artisans List
                            VStack(spacing: 12) {
                                ForEach(artisans, id: \.id) { artisan in
                                    ArtisanNearCard(
                                        artisan: artisan,
                                        onTap: {
                                            selectedArtisan = artisan
                                            showConfirmation = true
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

            // MARK: - Confirmation Popup
            if showConfirmation && selectedArtisan != nil {
                ZStack {
                    // Background blur
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showConfirmation = false
                        }

                    // Popup Card
                    VStack(spacing: 0) {
                        // Title
                        Text("Send Cake Request?")
                            .font(.urbanistBold(18))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            .padding(.top, 24)
                            .padding(.bottom, 16)

                        // Artisan Card Details
                        if let artisan = selectedArtisan {
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
                        }

                        // Divider
                        Divider()
                            .padding(.horizontal, 0)

                        // Action Buttons
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

                            NavigationLink(destination: CreateCakeRequestView(user: user)) {
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
