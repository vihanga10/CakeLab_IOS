import SwiftUI
import FirebaseFirestore

// MARK: - Customer Home View
@MainActor
struct CustomerHomeView: View {
    @State var user: AppUser
    @Binding var selectedTab: Int
    @State private var searchText = ""
    @StateObject private var viewModel = CustomerHomeViewModel()
    
    private let db = Firestore.firestore()

    // Categories are the same for every customer — no database needed
    private let categories: [(name: String, image: String)] = [
        (name: "Wedding Cakes",     image: "wedding_cat"),
        (name: "Birthday Cakes",    image: "birthday_cat"),
        (name: "Anniversary Cakes", image: "anniversary_cat"),
        (name: "Baby Shower Cakes",       image: "babyshower_cat"),
        (name: "Cupcakes",          image: "cupcake_cat"),
        (name: "Buttercream Cakes",       image: "buttercream_cat"),
        (name: "Corporate Cakes",   image: "corporate_cat"),
        (name: "Engagement Cakes",        image: "engagement_cat"),
        (name: "Graduation Cakes",        image: "graduation_cat"),
        (name: "Baptism Cakes",           image: "baptism_cat"),
        (name: "Retirement Cakes",        image: "retirement_cat"),
        (name: "Farewell Cakes",          image: "farewell_cat"),
        (name: "Vegan Cakes",       image: "vegan_cat"),
        (name: "Sculpted Cakes",    image: "sculpted_cat"),
        
        
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // MARK: - Header Section
                        HStack(alignment: .center, spacing: 12) {
                            // Profile avatar (clickable)
                            NavigationLink(destination: CustomerProfileDetailView(user: user)) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.90, green: 0.86, blue: 0.82))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.cakeBrown)
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Good Morning")
                                    .font(.urbanistRegular(13))
                                    .foregroundColor(.cakeGrey)
                                // Show name if available, otherwise show email
                                Text(user.name.isEmpty ? user.email : user.name)
                                    .font(.urbanistSemiBold(15))
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button {} label: {
                                Image(systemName: "bell")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                        
                        // MARK: - Search Bar
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 15))
                                .foregroundColor(.cakeGrey)
                            TextField("Search cakes or artisans...", text: $searchText)
                                .font(.urbanistRegular(14))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                .tint(.cakeBrown)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.94, green: 0.94, blue: 0.94))
                        .clipShape(Capsule())
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        
                        // MARK: - Dream Cake Request Card
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Bring Your Cake Vision to Life")
                                .font(.urbanistBold(17))
                                .foregroundColor(Color(red: 0, green: 0, blue: 0))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)
                            
                            Spacer().frame(height: 14)
                            
                            Text("Share your photo, description, budget & exactly how you want it made. Our talented Cake Crafters will suggest the best designs to turn your vision into reality.")
                                .font(.urbanistRegular(12))
                                .foregroundColor(Color(red: 95/255, green: 95/255, blue: 95/255))
                                .lineSpacing(3)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                            
                            Spacer().frame(height: 18)
                            
                            NavigationLink(destination: CreateCakeRequestView()) {
                                 HStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.25))
                                            .frame(width: 22, height: 22)
                                        Image(systemName: "plus")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    Text("Post My Dream Cake Request")
                                        .font(.urbanistSemiBold(13))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.cakeBrown)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 22)
                        .background(Color(red: 235/255, green: 228/255, blue: 222/255))
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)

                        // MARK: - What Are You Craving?
                        VStack(alignment: .leading, spacing: 16) {
                            Text("What are you craving today?")
                                .font(.urbanistBold(15))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(categories, id: \.name) { cat in
                                        Button {} label: {
                                            VStack(spacing: 8) {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color(red: 0.93, green: 0.91, blue: 0.89))
                                                    if UIImage(named: cat.image) != nil {
                                                        Image(cat.image)
                                                            .resizable()
                                                            .scaledToFill()
                                                            .frame(width: 88, height: 88)
                                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                                    } else {
                                                        Image(systemName: "birthday.cake.fill")
                                                            .font(.system(size: 28))
                                                            .foregroundColor(.cakeBrown.opacity(0.45))
                                                    }
                                                }
                                                .frame(width: 88, height: 88)
                                                .clipped()
                                                
                                                Text(cat.name)
                                                    .font(.urbanistSemiBold(11))
                                                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                                                    .multilineTextAlignment(.center)
                                                    .lineLimit(2)
                                                    .minimumScaleFactor(0.9)
                                                    .frame(width: 88, height: 32, alignment: .top)
                                            }
                                            .frame(width: 88, height: 128, alignment: .top)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.bottom, 28)
                        
                        // MARK: - Active Orders  (user-specific — fetched per logged-in user)
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Active Orders")
                                    .font(.urbanistBold(15))
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                Spacer()
                                Button { selectedTab = 2 } label: {
                                    Text("See all")
                                        .font(.urbanistSemiBold(13))
                                        .foregroundColor(.cakeBrown)
                                }
                            }
                            .padding(.horizontal, 20)

                            if viewModel.isLoadingOrders {
                                // Loading skeleton
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(0..<3, id: \.self) { _ in
                                            VStack(spacing: 10) {
                                                Circle()
                                                    .fill(Color(red: 0.91, green: 0.91, blue: 0.91))
                                                    .frame(width: 90, height: 90)
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color(red: 0.91, green: 0.91, blue: 0.91))
                                                    .frame(width: 68, height: 22)
                                            }
                                            .frame(width: 100)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 4)
                                }
                            } else if viewModel.activeOrders.isEmpty {
                                // Empty state — first-time users or no active orders
                                VStack(spacing: 8) {
                                    Image(systemName: "cart.badge.plus")
                                        .font(.system(size: 34))
                                        .foregroundColor(.cakeBrown.opacity(0.35))
                                    Text("No active orders yet")
                                        .font(.urbanistSemiBold(13))
                                        .foregroundColor(.cakeGrey)
                                    Text("Post a cake request below to get started!")
                                        .font(.urbanistRegular(12))
                                        .foregroundColor(.cakeGrey.opacity(0.7))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                            } else {
                                // Real orders from Firestore — different for each user
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(viewModel.activeOrders) { order in
                                            VStack(spacing: 10) {
                                                ZStack {
                                                    Circle()
                                                        .stroke(Color(red: 0.15, green: 0.65, blue: 0.22), lineWidth: 2.5)
                                                        .frame(width: 90, height: 90)
                                                    Circle()
                                                        .fill(Color(red: 0.93, green: 0.91, blue: 0.88))
                                                        .frame(width: 82, height: 82)
                                                    Image(systemName: "birthday.cake.fill")
                                                        .font(.system(size: 30))
                                                        .foregroundColor(.cakeBrown.opacity(0.45))
                                                }
                                                Text("Order No:\n\(order.id.prefix(6))")
                                                    .font(.urbanistRegular(11))
                                                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                                                    .multilineTextAlignment(.center)
                                            }
                                            .frame(width: 100)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .padding(.bottom, 28)
                        
                        // MARK: - Artisans Near You  (common — same list for all customers)
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Artisans Near You")
                                    .font(.urbanistBold(15))
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                Spacer()
                                NavigationLink(destination: ArtisansNearYouView()) {
                                    Text("See all")
                                        .font(.urbanistSemiBold(13))
                                        .foregroundColor(.cakeBrown)
                                }
                            }
                            .padding(.horizontal, 20)

                            if viewModel.isLoadingArtisans {
                                // Loading skeleton
                                VStack(spacing: 12) {
                                    ForEach(0..<3, id: \.self) { _ in
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color(red: 0.93, green: 0.93, blue: 0.93))
                                            .frame(height: 100)
                                    }
                                }
                                .padding(.horizontal, 20)
                            } else if viewModel.artisans.isEmpty {
                                Text("No artisans available right now.")
                                    .font(.urbanistRegular(13))
                                    .foregroundColor(.cakeGrey)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 20)
                            } else {
                                // Real artisans from Firestore — same for every customer
                                VStack(spacing: 12) {
                                    ForEach(viewModel.artisans) { artisan in
                                        ArtisanCard(
                                            name: artisan.name,
                                            rating: artisan.ratingText,
                                            reviews: artisan.reviewsText,
                                            specialty: artisan.specialties,
                                            location: artisan.location,
                                            isOnline: artisan.isOnline
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                // Refresh user data from Firestore
                await refreshUserFromFirestore()
                
                // Run both fetches concurrently when the screen loads
                async let orders: ()   = viewModel.fetchActiveOrders(for: user.id)
                async let artisans: () = viewModel.fetchArtisans()
                await orders
                await artisans
            }
        }
    }
    
    // MARK: - Refresh User
    /// Fetches the latest user data from Firestore to reflect profile edits
    private func refreshUserFromFirestore() async {
        do {
            let snapshot = try await db.collection("users").document(user.id).getDocument()
            do {
                let updatedUser = try snapshot.data(as: AppUser.self)
                self.user = updatedUser
                print("DEBUG: User data refreshed from Firestore")
            } catch {
                print("DEBUG: Could not decode AppUser from snapshot")
            }
        } catch {
            print("ERROR fetching user from Firestore: \(error)")
        }
    }
}

// MARK: - Artisan Card Component
struct ArtisanCard: View {
    let name: String
    let rating: String
    let reviews: String
    let specialty: [String]
    let location: String
    var isOnline: Bool = true        // online indicator dot
    var imageURL: String? = nil      // optional remote image (future)

    var body: some View {
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
                    Text(name)
                        .font(.urbanistBold(14))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.1))
                        Text(rating)
                            .font(.urbanistSemiBold(12))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        Text(reviews)
                            .font(.urbanistRegular(11))
                            .foregroundColor(.cakeGrey)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(specialty, id: \.self) { tag in
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
                    .fill(isOnline ? Color(red: 0.15, green: 0.72, blue: 0.25) : Color.gray.opacity(0.4))
                    .frame(width: 11, height: 11)
            }
            HStack(spacing: 5) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.cakeGrey)
                Text(location)
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

#Preview {
    CustomerHomeView(user: AppUser.mock, selectedTab: .constant(0))
}
