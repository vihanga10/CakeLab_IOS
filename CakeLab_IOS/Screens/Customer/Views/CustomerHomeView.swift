import SwiftUI

// MARK: - Customer Home View
@MainActor
struct CustomerHomeView: View {
    @State var user: AppUser
    @Binding var selectedTab: Int
    @State private var searchText = ""
    @StateObject private var viewModel = CustomerHomeViewModel()
    @StateObject private var artisansVM = ArtisansNearYouViewModel(customerDistrict: nil)
    @State private var profileAvatar: UIImage? = nil
    @State private var homeSelectedArtisan: ArtisanProfile? = nil
    @State private var homeProfileArtisan: ArtisanProfile? = nil
    @EnvironmentObject var notificationManager: NotificationManager

    private let categories: [(name: String, image: String)] = [
        (name: "Wedding Cakes",      image: "wedding_cat"),
        (name: "Birthday Cakes",     image: "birthday_cat"),
        (name: "Anniversary Cakes",  image: "anniversary_cat"),
        (name: "Baby Shower Cakes",  image: "babyshower_cat"),
        (name: "Cupcakes",           image: "cupcake_cat"),
        (name: "Buttercream Cakes",  image: "buttercream_cat"),
        (name: "Corporate Cakes",    image: "corporate_cat"),
        (name: "Engagement Cakes",   image: "engagement_cat"),
        (name: "Graduation Cakes",   image: "graduation_cat"),
        (name: "Baptism Cakes",      image: "baptism_cat"),
        (name: "Retirement Cakes",   image: "retirement_cat"),
        (name: "Farewell Cakes",     image: "farewell_cat"),
        (name: "Vegan Cakes",        image: "vegan_cat"),
        (name: "Sculpted Cakes",     image: "sculpted_cat"),
        (name: "Normal Cakes",       image: "normal_cat"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // MARK: - Header Section
                        HStack(alignment: .center, spacing: 12) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { selectedTab = 3 }
                            } label: {
                                if let profileAvatar = profileAvatar {
                                    Image(uiImage: profileAvatar)
                                        .resizable().scaledToFill()
                                        .frame(width: 48, height: 48).clipShape(Circle())
                                } else {
                                    ZStack {
                                        Circle().fill(Color(red: 0.90, green: 0.86, blue: 0.82)).frame(width: 48, height: 48)
                                        Image(systemName: "person.fill").font(.system(size: 22)).foregroundColor(.cakeBrown)
                                    }
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Good Morning").font(.urbanistRegular(13)).foregroundColor(.cakeGrey)
                                Text(user.name.isEmpty ? user.email : user.name)
                                    .font(.urbanistSemiBold(15)).foregroundColor(.cakePrimaryText).lineLimit(1)
                            }
                            Spacer()
                            NotificationBellButton(notificationService: notificationManager.notificationService, userType: "customer", userID: user.id)
                        }
                        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 16)

                        // MARK: - Search Bar
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").font(.system(size: 15)).foregroundColor(.cakeGrey)
                            TextField("Search cakes or artisans...", text: $searchText)
                                .font(.urbanistRegular(14)).foregroundColor(.cakePrimaryText).tint(.cakeBrown)
                            if isSearching {
                                Button { searchText = "" } label: {
                                    Image(systemName: "xmark.circle.fill").font(.system(size: 15)).foregroundColor(.cakeGrey.opacity(0.75))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(Color(red: 0.94, green: 0.94, blue: 0.94)).clipShape(Capsule())
                        .padding(.horizontal, 20).padding(.bottom, 20)

                        if isSearching {
                            homeSearchResults.padding(.bottom, 32)
                        } else {
                            // MARK: - Dream Cake Request Card
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Bring Your Cake Vision to Life")
                                    .font(.urbanistBold(17)).foregroundColor(Color(red: 0, green: 0, blue: 0))
                                    .frame(maxWidth: .infinity, alignment: .center).multilineTextAlignment(.center)
                                Spacer().frame(height: 14)
                                Text("Share your photo, description, budget & exactly how you want it made. Our talented Cake Crafters will suggest the best designs to turn your vision into reality.")
                                    .font(.urbanistRegular(12)).foregroundColor(Color(red: 95/255, green: 95/255, blue: 95/255))
                                    .lineSpacing(3).frame(maxWidth: .infinity).multilineTextAlignment(.center)
                                Spacer().frame(height: 18)
                                NavigationLink(destination: CreateCakeRequestView(user: user)) {
                                    HStack(spacing: 8) {
                                        ZStack {
                                            Circle().fill(Color.white.opacity(0.25)).frame(width: 22, height: 22)
                                            Image(systemName: "plus").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                                        }
                                        Text("Post My Dream Cake Request").font(.urbanistSemiBold(13)).foregroundColor(.white)
                                    }
                                    .frame(maxWidth: .infinity).frame(height: 44)
                                    .background(Color.cakeBrown).clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 22)
                            .background(Color(red: 235/255, green: 228/255, blue: 222/255)).cornerRadius(16)
                            .padding(.horizontal, 20).padding(.bottom, 28)

                            // MARK: - What Are You Craving?
                            VStack(alignment: .leading, spacing: 16) {
                                Text("What are you craving today?")
                                    .font(.urbanistBold(15)).foregroundColor(.cakePrimaryText).padding(.horizontal, 20)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(categories, id: \.name) { cat in
                                            Button {} label: {
                                                VStack(spacing: 8) {
                                                    ZStack {
                                                        RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.93, green: 0.91, blue: 0.89))
                                                        if UIImage(named: cat.image) != nil {
                                                            Image(cat.image).resizable().scaledToFill()
                                                                .frame(width: 88, height: 88).clipShape(RoundedRectangle(cornerRadius: 12))
                                                        } else {
                                                            Image(systemName: "birthday.cake.fill").font(.system(size: 28)).foregroundColor(.cakeBrown.opacity(0.45))
                                                        }
                                                    }
                                                    .frame(width: 88, height: 88).clipped()
                                                    Text(cat.name).font(.urbanistSemiBold(11)).foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                                                        .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.9)
                                                        .frame(width: 88, height: 32, alignment: .top)
                                                }
                                                .frame(width: 88, height: 128, alignment: .top)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 20).padding(.vertical, 4)
                                }
                            }
                            .padding(.bottom, 28)

                            // MARK: - Active Orders
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("Active Orders").font(.urbanistBold(15)).foregroundColor(.cakePrimaryText)
                                    Spacer()
                                    Button { selectedTab = 2 } label: {
                                        Text("See all").font(.urbanistSemiBold(13)).foregroundColor(.cakeBrown)
                                    }
                                }
                                .padding(.horizontal, 20)

                                if viewModel.isLoadingOrders {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(0..<3, id: \.self) { _ in
                                                VStack(spacing: 10) {
                                                    Circle().fill(Color(red: 0.91, green: 0.91, blue: 0.91)).frame(width: 90, height: 90)
                                                    RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.91, green: 0.91, blue: 0.91)).frame(width: 68, height: 22)
                                                }
                                                .frame(width: 100)
                                            }
                                        }
                                        .padding(.horizontal, 20).padding(.vertical, 4)
                                    }
                                } else if viewModel.activeOrders.isEmpty {
                                    VStack(spacing: 8) {
                                        Image(systemName: "cart.badge.plus").font(.system(size: 34)).foregroundColor(.cakeBrown.opacity(0.35))
                                        Text("No active orders yet").font(.urbanistSemiBold(13)).foregroundColor(.cakeGrey)
                                        Text("Post a cake request below to get started!").font(.urbanistRegular(12)).foregroundColor(.cakeGrey.opacity(0.7))
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, 20)
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(viewModel.activeOrders) { order in
                                                NavigationLink(destination: CustomerOrderStatusView(
                                                    orderID: order.id,
                                                    fallbackOrder: CustomerOrder(from: order)
                                                )) {
                                                    VStack(spacing: 10) {
                                                        ZStack {
                                                            Circle().stroke(Color(red: 0.15, green: 0.65, blue: 0.22), lineWidth: 2.5).frame(width: 90, height: 90)
                                                            Circle().fill(Color(red: 0.93, green: 0.91, blue: 0.88)).frame(width: 82, height: 82)
                                                            if !order.referenceImages.isEmpty,
                                                               let imageData = Data(base64Encoded: order.referenceImages[0]),
                                                               let uiImage = UIImage(data: imageData) {
                                                                Image(uiImage: uiImage).resizable().scaledToFill()
                                                                    .frame(width: 74, height: 74).clipShape(Circle())
                                                            } else {
                                                                Image(systemName: "birthday.cake.fill").font(.system(size: 30)).foregroundColor(.cakeBrown.opacity(0.45))
                                                            }
                                                        }
                                                        Text("Order No:\n\(String(order.id.prefix(6)).uppercased())")
                                                            .font(.urbanistRegular(11)).foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2)).multilineTextAlignment(.center)
                                                    }
                                                    .frame(width: 100)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.horizontal, 20).padding(.vertical, 4)
                                    }
                                }
                            }
                            .padding(.bottom, 28)

                            // MARK: - Artisans Near You
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("Artisans Near You").font(.urbanistBold(15)).foregroundColor(.cakePrimaryText)
                                    Spacer()
                                    NavigationLink(destination: ArtisansNearYouView(user: user)) {
                                        Text("See all").font(.urbanistSemiBold(13)).foregroundColor(.cakeBrown)
                                    }
                                }
                                .padding(.horizontal, 20)

                                if artisansVM.isLoading {
                                    VStack(spacing: 12) {
                                        ForEach(0..<3, id: \.self) { _ in
                                            RoundedRectangle(cornerRadius: 24).fill(Color(red: 0.93, green: 0.93, blue: 0.93)).frame(height: 110)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                } else if nearbyArtisans.isEmpty {
                                    Text("No artisans available right now.")
                                        .font(.urbanistRegular(13)).foregroundColor(.cakeGrey)
                                        .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 20)
                                } else {
                                    VStack(spacing: 12) {
                                        ForEach(nearbyArtisans) { artisan in
                                            ArtisanNearCard(
                                                artisan: artisan,
                                                onTap: { homeSelectedArtisan = artisan },
                                                onProfileImageTap: { homeProfileArtisan = artisan }
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

                if let artisan = homeSelectedArtisan {
                    homeArtisanOverlay(for: artisan)
                }
            }
            .navigationBarHidden(true)
            .onAppear { loadProfileAvatar() }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("profileAvatarUpdated"))) { _ in
                loadProfileAvatar()
            }
            .task {
                // Load home data: current user, active orders, and nearby bakers.
                user = await viewModel.refreshUser(current: user)
                let currentUID = user.id
                async let orders: ()   = viewModel.fetchActiveOrders(for: currentUID)
                async let artisans: () = artisansVM.loadArtisansFromDatabase()
                await orders
                await artisans
            }
            .sheet(item: $homeProfileArtisan) { artisan in
                // Public baker profile opened from home artisan card photo.
                CustomerPublicBakerProfileView(
                    bakerID: artisan.id,
                    fallbackName: artisan.name,
                    fallbackProfileImageBase64: artisan.profileImageBase64,
                    fallbackImageURL: artisan.imageURL ?? "",
                    fallbackAddress: artisan.location,
                    fallbackCity: artisan.city
                )
            }
        }
    }

    // MARK: - Search Helpers

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isSearching: Bool { !normalizedSearchText.isEmpty }

    private var filteredSearchCategories: [(name: String, image: String)] {
        guard isSearching else { return [] }
        return categories.filter { $0.name.lowercased().contains(normalizedSearchText) }
    }

    private var filteredSearchOrders: [CakeOrder] {
        guard isSearching else { return [] }
        return viewModel.activeOrders.filter {
            $0.cakeName.lowercased().contains(normalizedSearchText)
            || $0.id.lowercased().contains(normalizedSearchText)
            || $0.artisanName.lowercased().contains(normalizedSearchText)
            || $0.statusLabel.lowercased().contains(normalizedSearchText)
            || $0.category.lowercased().contains(normalizedSearchText)
        }
    }

    private var filteredSearchArtisans: [ArtisanProfile] {
        guard isSearching else { return [] }
        return artisansVM.artisans.filter {
            $0.name.lowercased().contains(normalizedSearchText)
            || $0.location.lowercased().contains(normalizedSearchText)
            || $0.city.lowercased().contains(normalizedSearchText)
            || $0.specialties.contains { $0.lowercased().contains(normalizedSearchText) }
        }
    }

    private var searchResultCount: Int {
        filteredSearchCategories.count + filteredSearchOrders.count + filteredSearchArtisans.count
    }

    private var homeSearchResults: some View {
        // Search results grouped by categories, active orders, and artisans.
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Search Results").font(.urbanistBold(15)).foregroundColor(.cakePrimaryText)
                Spacer()
                Text("\(searchResultCount)").font(.urbanistSemiBold(12)).foregroundColor(.cakeBrown)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color(red: 0.96, green: 0.94, blue: 0.91)).clipShape(Capsule())
            }
            .padding(.horizontal, 20)

            if viewModel.isLoadingOrders || artisansVM.isLoading {
                ProgressView("Searching...").font(.urbanistRegular(13)).tint(.cakeBrown)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
            }

            if searchResultCount == 0 && !viewModel.isLoadingOrders && !artisansVM.isLoading {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 30)).foregroundColor(.cakeBrown.opacity(0.35))
                    Text("No matching cakes or artisans").font(.urbanistSemiBold(13)).foregroundColor(.cakeGrey)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 28)
            } else {
                if !filteredSearchCategories.isEmpty {
                    homeSearchSection(title: "Cake Categories") {
                        ForEach(filteredSearchCategories, id: \.name) { category in
                            NavigationLink(destination: CreateCakeRequestView(user: user)) {
                                homeCategorySearchRow(category: category)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !filteredSearchOrders.isEmpty {
                    homeSearchSection(title: "Active Orders") {
                        ForEach(filteredSearchOrders) { order in
                            NavigationLink(destination: CustomerOrderStatusView(
                                orderID: order.id,
                                fallbackOrder: CustomerOrder(from: order)
                            )) {
                                homeOrderSearchRow(order: order)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !filteredSearchArtisans.isEmpty {
                    homeSearchSection(title: "Artisans") {
                        ForEach(filteredSearchArtisans) { artisan in
                            Button { homeSelectedArtisan = artisan } label: {
                                homeArtisanSearchRow(artisan: artisan)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func homeSearchSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.urbanistSemiBold(13)).foregroundColor(.cakeGrey).padding(.horizontal, 20)
            VStack(spacing: 10) { content() }.padding(.horizontal, 20)
        }
    }

    private func homeCategorySearchRow(category: (name: String, image: String)) -> some View {
        HStack(spacing: 12) {
            homeCategoryImage(category: category, size: 50)
            VStack(alignment: .leading, spacing: 3) {
                Text(category.name).font(.urbanistSemiBold(14)).foregroundColor(.cakePrimaryText).lineLimit(1)
                Text("Cake category").font(.urbanistRegular(11)).foregroundColor(.cakeGrey)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(.cakeGrey.opacity(0.75))
        }
        .padding(12).background(Color.cakeSurface).cornerRadius(14)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func homeOrderSearchRow(order: CakeOrder) -> some View {
        HStack(spacing: 12) {
            homeOrderImage(order: order, size: 50)
            VStack(alignment: .leading, spacing: 4) {
                Text(order.cakeName).font(.urbanistSemiBold(14)).foregroundColor(.cakePrimaryText).lineLimit(1)
                HStack(spacing: 6) {
                    Text(order.statusLabel).font(.urbanistSemiBold(10)).foregroundColor(order.statusColor)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(order.statusColor.opacity(0.12)).cornerRadius(8)
                    Text(order.formattedDeliveryDate).font(.urbanistRegular(11)).foregroundColor(.cakeGrey)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(.cakeGrey.opacity(0.75))
        }
        .padding(12).background(Color.cakeSurface).cornerRadius(14)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func homeArtisanSearchRow(artisan: ArtisanProfile) -> some View {
        HStack(spacing: 12) {
            homeArtisanImage(artisan: artisan, size: 50, cornerRadius: 10)
            VStack(alignment: .leading, spacing: 4) {
                Text(artisan.name).font(.urbanistSemiBold(14)).foregroundColor(.cakePrimaryText).lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.1))
                    Text("\(artisan.ratingText) \(artisan.reviewsText)").font(.urbanistRegular(11)).foregroundColor(.cakeGrey).lineLimit(1)
                }
                Text(artisan.specialties.prefix(2).joined(separator: " / ")).font(.urbanistRegular(11)).foregroundColor(.cakeGrey).lineLimit(1)
            }
            Spacer()
            Circle().fill(artisan.isOnline ? Color(red: 0.15, green: 0.72, blue: 0.25) : Color.gray.opacity(0.45)).frame(width: 10, height: 10)
        }
        .padding(12).background(Color.cakeSurface).cornerRadius(14)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Image Helpers

    @ViewBuilder
    private func homeCategoryImage(category: (name: String, image: String), size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.93, green: 0.91, blue: 0.89)).frame(width: size, height: size)
            if UIImage(named: category.image) != nil {
                Image(category.image).resizable().scaledToFill().frame(width: size, height: size).clipped()
            } else {
                Image(systemName: "birthday.cake.fill").font(.system(size: max(18, size * 0.42))).foregroundColor(.cakeBrown.opacity(0.45))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func homeOrderImage(order: CakeOrder, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.93, green: 0.91, blue: 0.89)).frame(width: size, height: size)
            if let firstImage = order.referenceImages.first,
               let imageData = Data(base64Encoded: firstImage),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage).resizable().scaledToFill().frame(width: size, height: size).clipped()
            } else if let rawURL = order.imageURL, !rawURL.isEmpty, let url = URL(string: rawURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill().frame(width: size, height: size).clipped()
                    default: Image(systemName: "birthday.cake.fill").font(.system(size: max(18, size * 0.42))).foregroundColor(.cakeBrown.opacity(0.45))
                    }
                }
            } else {
                Image(systemName: "birthday.cake.fill").font(.system(size: max(18, size * 0.42))).foregroundColor(.cakeBrown.opacity(0.45))
            }
        }
        .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Profile Avatar (UserDefaults — no Firestore needed)
    private func loadProfileAvatar() {
        guard let base64String = UserDefaults.standard.string(forKey: "profileAvatar_\(user.id)"),
              let imageData = Data(base64Encoded: base64String) else {
            profileAvatar = nil
            return
        }
        profileAvatar = UIImage(data: imageData)
    }

    // MARK: - Artisan Confirmation Overlay
    @ViewBuilder
    private func homeArtisanOverlay(for artisan: ArtisanProfile) -> some View {
        // Confirmation modal before creating a direct request to an artisan.
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().onTapGesture { homeSelectedArtisan = nil }

            VStack(spacing: 0) {
                Text("Send Cake Request?").font(.urbanistBold(18)).foregroundColor(.cakePrimaryText)
                    .padding(.top, 24).padding(.bottom, 16)

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        homeArtisanImage(artisan: artisan, size: 60, cornerRadius: 10)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(artisan.name).font(.urbanistBold(14)).foregroundColor(.cakePrimaryText)
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill").font(.system(size: 11)).foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.1))
                                Text("\(String(format: "%.1f", artisan.rating)) (\(artisan.reviewCount) reviews)").font(.urbanistRegular(11)).foregroundColor(.cakeGrey)
                            }
                            HStack(spacing: 5) {
                                Image(systemName: "mappin.circle.fill").font(.system(size: 10)).foregroundColor(.cakeGrey)
                                Text(artisan.location).font(.urbanistRegular(10)).foregroundColor(.cakeGrey).lineLimit(1)
                            }
                        }
                        Spacer()
                        Circle().fill(artisan.isOnline ? Color(red: 0.15, green: 0.72, blue: 0.25) : Color.gray.opacity(0.45)).frame(width: 10, height: 10)
                    }
                    .padding(12).background(Color.cakeSurface).cornerRadius(12)
                }
                .padding(.horizontal, 20).padding(.bottom, 20)

                Divider()

                HStack(spacing: 12) {
                    Button { homeSelectedArtisan = nil } label: {
                        Text("Cancel").font(.urbanistSemiBold(14)).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color(red: 0.94, green: 0.94, blue: 0.94)).foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3)).cornerRadius(10)
                    }
                    NavigationLink(destination: CreateCakeRequestView(user: user, selectedArtisan: artisan)) {
                        Text("Send Request").font(.urbanistSemiBold(14)).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.cakeBrown).foregroundColor(.white).cornerRadius(10)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
            }
            .background(Color.cakeSurface).cornerRadius(16).padding(.horizontal, 24)
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
        }
    }

    @ViewBuilder
    private func homeArtisanImage(artisan: ArtisanProfile, size: CGFloat, cornerRadius: CGFloat) -> some View {
        if let image = homeDecodeBase64Image(artisan.profileImageBase64) {
            Image(uiImage: image).resizable().scaledToFill()
                .frame(width: size, height: size).clipped().cornerRadius(cornerRadius)
        } else if let rawURL = artisan.imageURL, !rawURL.isEmpty, let url = URL(string: rawURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: homeImageFallback(size: size)
                }
            }
            .frame(width: size, height: size).clipped().cornerRadius(cornerRadius)
        } else {
            homeImageFallback(size: size).cornerRadius(cornerRadius)
        }
    }

    @ViewBuilder
    private func homeImageFallback(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.92, green: 0.90, blue: 0.87)).frame(width: size, height: size)
            Image(systemName: "storefront.fill").font(.system(size: max(20, size * 0.38))).foregroundColor(.cakeBrown.opacity(0.5))
        }
    }

    private func homeDecodeBase64Image(_ raw: String) -> UIImage? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let payload = trimmed.firstIndex(of: ",").map { String(trimmed[trimmed.index(after: $0)...]) } ?? trimmed
        guard let data = Data(base64Encoded: payload) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Nearby Artisans (district-filtered, max 3)
    private var nearbyArtisans: [ArtisanProfile] {
        let district = SriLankaDistricts.canonical(user.city ?? "")
        if let district {
            let filtered = artisansVM.artisans.filter { SriLankaDistricts.canonical($0.city) == district }
            if !filtered.isEmpty { return Array(filtered.prefix(3)) }
        }
        return Array(artisansVM.artisans.prefix(3))
    }
}

#Preview {
    CustomerHomeView(user: AppUser.mock, selectedTab: .constant(0))
}
