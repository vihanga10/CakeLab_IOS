import SwiftUI

// MARK: - Customer Home View
@MainActor
struct CustomerHomeView: View {
    let user: AppUser
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // MARK: - Header Section
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Good Morning")
                                    .font(.urbanistRegular(14))
                                    .foregroundColor(.cakeGrey)
                                
                                Text(user.name.isEmpty ? "Vihanga Madushamini" : user.name)
                                    .font(.urbanistSemiBold(16))
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            }
                            
                            Spacer()
                            
                            // Notification bell
                            Button {} label: {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.cakeBrown)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                        
                        // MARK: - Search Bar
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16))
                                .foregroundColor(.cakeGrey)
                            
                            TextField("Search cakes or artisans", text: $searchText)
                                .font(.urbanistRegular(14))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                .tint(.cakeBrown)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                        .cornerRadius(25)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                        
                        // MARK: - Dream Cake Request Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Bring Your Cake Vision to Life")
                                .font(.urbanistBold(16))
                                .foregroundColor(.cakeBrown)
                            
                            Text("Share your photo, description, budget & exactly how you want it made. Our talented Cake Crafters will suggest the best designs to turn your vision into reality.")
                                .font(.urbanistRegular(13))
                                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                                .lineSpacing(2)
                            
                            Button {
                                print("Post Dream Cake Request")
                            } label: {
                                HStack {
                                    Text("Post My Dream Cake Request")
                                        .font(.urbanistSemiBold(13))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.cakeBrown)
                                .cornerRadius(22)
                            }
                        }
                        .padding(16)
                        .background(Color(red: 0.94, green: 0.90, blue: 0.85))
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                        
                        // MARK: - What are you craving?
                        VStack(alignment: .leading, spacing: 16) {
                            Text("What are you craving today?")
                                .font(.urbanistBold(16))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                .padding(.horizontal, 20)
                            
                            HStack(spacing: 12) {
                                ForEach([
                                    ("Cupcakes", "🧁"),
                                    ("Wedding Cakes", "💒"),
                                    ("3D Cakes", "🎨")
                                ], id: \.0) { name, emoji in
                                    VStack(spacing: 8) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(red: 0.95, green: 0.95, blue: 0.95))
                                            
                                            Text(emoji)
                                                .font(.system(size: 32))
                                        }
                                        .frame(height: 80)
                                        
                                        Text(name)
                                            .font(.urbanistSemiBold(12))
                                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                            .multilineTextAlignment(.center)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 28)
                        
                        // MARK: - Active Orders
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Active Orders")
                                    .font(.urbanistBold(16))
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                
                                Spacer()
                                
                                Button {} label: {
                                    Text("See all")
                                        .font(.urbanistSemiBold(12))
                                        .foregroundColor(.cakeBrown)
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach([
                                        ("Order No 1001", "🎂"),
                                        ("Order No 1010", "🍰"),
                                        ("Order No 85033", "🧁")
                                    ], id: \.0) { orderInfo, emoji in
                                        VStack(spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .stroke(Color.cakeBrown.opacity(0.2), lineWidth: 2)
                                                
                                                Text(emoji)
                                                    .font(.system(size: 40))
                                            }
                                            .frame(height: 100)
                                            
                                            Text(orderInfo)
                                                .font(.urbanistSemiBold(12))
                                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                        }
                                        .frame(width: 110)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.bottom, 28)
                        
                        // MARK: - Artisans Near You
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Artisans Near You")
                                    .font(.urbanistBold(16))
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                
                                Spacer()
                                
                                Button {} label: {
                                    Text("See all")
                                        .font(.urbanistSemiBold(12))
                                        .foregroundColor(.cakeBrown)
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ForEach([
                                    (name: "Butter Boutique", rating: "5.0", reviews: "(41 reviews)", specialty: ["Cupcakes", "Vegan", "3D Cakes"], location: "70 Norwood Place Colombo 07, Sri Lanka"),
                                    (name: "Patisserie", rating: "4.7", reviews: "(33 reviews)", specialty: ["Birthday", "Vegan", "Wedding Cakes"], location: "37/k & De Mel Mawatha Colombo 03"),
                                    (name: "Frost & Crumb", rating: "4.8", reviews: "(39 reviews)", specialty: ["Cupcakes", "Lava Cakes"], location: "2.8 km away - Colombo 07")
                                ], id: \.name) { artisan in
                                    ArtisanCard(
                                        name: artisan.name,
                                        rating: artisan.rating,
                                        reviews: artisan.reviews,
                                        specialty: artisan.specialty,
                                        location: artisan.location
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 28)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Placeholder image
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.95, green: 0.95, blue: 0.95))
                    
                    Image(systemName: "photo.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.cakeGrey)
                }
                .frame(width: 70, height: 70)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(name)
                        .font(.urbanistBold(14))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.2))
                        
                        Text("\(rating)")
                            .font(.urbanistSemiBold(12))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        
                        Text(reviews)
                            .font(.urbanistRegular(11))
                            .foregroundColor(.cakeGrey)
                    }
                    
                    Spacer()
                }
                
                Spacer()
                
                // Online indicator
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
            }
            
            // Specialty tags
            HStack(spacing: 6) {
                ForEach(specialty, id: \.self) { spec in
                    Text(spec)
                        .font(.urbanistRegular(10))
                        .foregroundColor(.cakeBrown)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.cakeBrown.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            
            // Location
            HStack(spacing: 6) {
                Image(systemName: "mappin.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.cakeGrey)
                
                Text(location)
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeGrey)
            }
        }
        .padding(12)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
        .cornerRadius(12)
    }
}

#Preview {
    CustomerHomeView(user: AppUser.mock)
}
