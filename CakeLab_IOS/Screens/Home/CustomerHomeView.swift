import SwiftUI

// MARK: - Customer Home View
@MainActor
struct CustomerHomeView: View {
    let user: AppUser
    @Binding var selectedTab: Int
    @State private var searchText = ""

    private let activeOrders: [(id: String, label: String)] = [
        (id: "B001",  label: "Order No:\nB001"),
        (id: "B011",  label: "Order No:\nB011"),
        (id: "BS033", label: "Order No:\nBS033")
    ]
    private let categories: [(name: String, image: String)] = [
        (name: "Cupcakes",      image: "cupcake_cat"),
        (name: "Wedding Cakes", image: "wedding_cat"),
        (name: "3D Cakes",      image: "3d_cat")
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
                            // Profile avatar
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.90, green: 0.86, blue: 0.82))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "person.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.cakeBrown)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Good Morning")
                                    .font(.urbanistRegular(13))
                                    .foregroundColor(.cakeGrey)
                                Text(user.name.isEmpty ? "Vihanga Madushamini" : user.name)
                                    .font(.urbanistSemiBold(15))
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
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
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Bring Your Cake Vision to Life")
                                .font(.urbanistBold(16))
                                .foregroundColor(Color(red: 0.15, green: 0.1, blue: 0.05))
                            Text("Share your photo, description, budget & exactly how you want it made. Our talented Cake Crafters will suggest the best designs to turn your vision into reality.")
                                .font(.urbanistRegular(12))
                                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.15))
                                .lineSpacing(3)
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
                        .padding(16)
                        .background(Color(red: 0.92, green: 0.88, blue: 0.83))
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)

                        // MARK: - What Are You Craving?
                        VStack(alignment: .leading, spacing: 14) {
                            Text("What are you craving today?")
                                .font(.urbanistBold(15))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                .padding(.horizontal, 20)

                            HStack(spacing: 10) {
                                ForEach(categories, id: \.name) { cat in
                                    Button {} label: {
                                        VStack(spacing: 8) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 14)
                                                    .fill(Color(red: 0.93, green: 0.91, blue: 0.89))
                                                    .frame(height: 88)
                                                if UIImage(named: cat.image) != nil {
                                                    Image(cat.image)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(height: 88)
                                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                                } else {
                                                    Image(systemName: "birthday.cake.fill")
                                                        .font(.system(size: 28))
                                                        .foregroundColor(.cakeBrown.opacity(0.45))
                                                }
                                            }
                                            Text(cat.name)
                                                .font(.urbanistSemiBold(11))
                                                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                                                .multilineTextAlignment(.center)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 28)
                        
                        // MARK: - Active Orders
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

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(activeOrders, id: \.id) { order in
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
                                            Text(order.label)
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
                        .padding(.bottom, 28)
                        
                        // MARK: - Artisans Near You
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Artisans Near You")
                                    .font(.urbanistBold(15))
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                Spacer()
                                Button {} label: {
                                    Text("See all")
                                        .font(.urbanistSemiBold(13))
                                        .foregroundColor(.cakeBrown)
                                }
                            }
                            .padding(.horizontal, 20)

                            VStack(spacing: 12) {
                                ArtisanCard(name: "Butter Boutique", rating: "5.0", reviews: "(41 reviews)",
                                            specialty: ["Cupcakes", "Vegan", "3D Cakes"],
                                            location: "70 Rosmead Place, Colombo 07, Sri Lanka")
                                ArtisanCard(name: "Patissere", rating: "4.7", reviews: "(33 reviews)",
                                            specialty: ["Birthday", "Vegan", "Wedding Cakes"],
                                            location: "379 R. A. De Mel Mawatha, Colombo 03")
                                ArtisanCard(name: "Frost & Crumb", rating: "4.8", reviews: "(19 reviews)",
                                            specialty: ["Cupcakes", "Lava Cakes"],
                                            location: "2.8 km away – Colombo 07")
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarHidden(true)
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
                    .fill(Color(red: 0.15, green: 0.72, blue: 0.25))
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
