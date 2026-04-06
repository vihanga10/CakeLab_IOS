import SwiftUI
import Charts

// MARK: - Baker Profile View (Tab 3 — Portfolio)
@MainActor
struct BakerProfileView: View {
    let user: AppUser
    @State private var showEditSheet = false
    @State private var selectedPortfolioImage: String? = nil
    @State private var showPortfolioViewer = false

    // Mock baker data
    private let rating: Double = 4.8
    private let totalReviews = 47
    private let totalOrders = 62
    private let memberSince = "January 2025"

    private let categoryTags = ["Wedding Cakes", "Birthday Cakes", "Fondant Art", "Custom Orders", "Cupcakes"]
    private let portfolioImages = ["photo.fill", "birthday.cake.fill", "heart.fill", "sparkles", "star.fill", "gift.fill"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.97, green: 0.96, blue: 0.94).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // MARK: Profile Header
                        profileHeaderSection
                            .padding(.bottom, 20)

                        // MARK: Stats Row
                        statsRow
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        // MARK: About / Bio
                        bioSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        // MARK: Category Tags
                        categoryTagsSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        // MARK: Portfolio Gallery
                        portfolioSection
                            .padding(.bottom, 20)

                        // MARK: Performance Charts
                        performanceSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        // MARK: Earnings Summary
                        earningsSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        // MARK: Settings
                        settingsSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("My Portfolio")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 13))
                            Text("Edit")
                                .font(.urbanistSemiBold(14))
                        }
                        .foregroundColor(.cakeBrown)
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                BakerEditProfileSheet(user: user)
            }
        }
    }

    // MARK: - Profile Header
    private var profileHeaderSection: some View {
        ZStack(alignment: .bottom) {
            // Cover gradient
            LinearGradient(
                colors: [Color.cakeBrown.opacity(0.8), Color.cakeBrown.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 160)

            // Subtle pattern overlay
            VStack(spacing: 0) {
                HStack(spacing: 30) {
                    ForEach(0..<4) { _ in
                        Image(systemName: "birthday.cake")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.08))
                    }
                }
            }
            .frame(height: 160)
            .clipped()

            // Avatar floats over edge
            VStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 92, height: 92)
                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                        .overlay(
                            Circle()
                                .fill(Color.cakeBrown.opacity(0.18))
                                .frame(width: 84, height: 84)
                        )
                        .overlay(
                            Text(String(user.name.prefix(1)).uppercased())
                                .font(.urbanistBold(32))
                                .foregroundColor(.cakeBrown)
                        )

                    // Online indicator
                    Circle()
                        .fill(Color.green)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                        .offset(x: 2, y: 2)
                }
                .offset(y: 46)
            }
        }
        .padding(.bottom, 56)
        .overlay(
            VStack(spacing: 4) {
                Text(user.name)
                    .font(.urbanistBold(20))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                HStack(spacing: 4) {
                    ForEach(0..<5) { i in
                        Image(systemName: Double(i) < rating ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.2))
                    }
                    Text(String(format: "%.1f", rating))
                        .font(.urbanistBold(13))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    Text("(\(totalReviews) reviews)")
                        .font(.urbanistRegular(12))
                        .foregroundColor(.cakeGrey)
                }
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 11))
                    Text("Colombo, Sri Lanka")
                        .font(.urbanistRegular(13))
                }
                .foregroundColor(.cakeGrey)
            }
            .padding(.top, 80),
            alignment: .bottom
        )
    }

    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 0) {
            profileStatItem(value: "\(totalOrders)", label: "Total Orders")
            Divider().frame(height: 40)
            profileStatItem(value: "\(totalReviews)", label: "Reviews")
            Divider().frame(height: 40)
            profileStatItem(value: "4.8", label: "Avg Rating")
            Divider().frame(height: 40)
            profileStatItem(value: "98%", label: "On-Time")
        }
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func profileStatItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.urbanistBold(18))
                .foregroundColor(Color.cakeBrown)
            Text(label)
                .font(.urbanistRegular(11))
                .foregroundColor(.cakeGrey)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bio Section
    private var bioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("About Me", systemImage: "person.text.rectangle")
                .font(.urbanistBold(16))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

            Text("Passionate cake artist with 5+ years of experience crafting memorable cakes for weddings, birthdays, and corporate events. Specializing in fondant art, sugar flowers, and multi-tier showpieces.")
                .font(.urbanistRegular(14))
                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                .lineSpacing(4)

            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                Text("Member since \(memberSince)")
                    .font(.urbanistRegular(12))
            }
            .foregroundColor(.cakeGrey)
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: - Category Tags
    private var categoryTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("My Specialities", systemImage: "tag.fill")
                    .font(.urbanistBold(16))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                Spacer()
                Text("(Matching requests)")
                    .font(.urbanistRegular(11))
                    .foregroundColor(.cakeGrey)
            }
            FlowLayout(tags: categoryTags)
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: - Portfolio Gallery
    private var portfolioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Portfolio", systemImage: "photo.on.rectangle.angled")
                    .font(.urbanistBold(16))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                Spacer()
                Text("6 photos")
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeGrey)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Add photo button
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.cakeBrown.opacity(0.08))
                            .frame(width: 120, height: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                    .foregroundColor(Color.cakeBrown.opacity(0.4))
                            )
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.cakeBrown)
                            Text("Add Photo")
                                .font(.urbanistMedium(12))
                                .foregroundColor(.cakeBrown)
                        }
                    }

                    ForEach(portfolioImages, id: \.self) { img in
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.cakeBrown.opacity(0.1 + Double(portfolioImages.firstIndex(of: img)!) * 0.03))
                                .frame(width: 120, height: 120)
                            Image(systemName: img)
                                .font(.system(size: 36))
                                .foregroundColor(.cakeBrown.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Performance Charts
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Performance", systemImage: "chart.bar.fill")
                .font(.urbanistBold(16))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

            // Monthly orders chart
            VStack(alignment: .leading, spacing: 8) {
                Text("Monthly Orders")
                    .font(.urbanistSemiBold(13))
                    .foregroundColor(.cakeGrey)

                Chart(monthlyOrderData) { item in
                    BarMark(
                        x: .value("Month", item.month),
                        y: .value("Orders", item.count)
                    )
                    .foregroundStyle(Color.cakeBrown.gradient)
                    .cornerRadius(6)
                }
                .frame(height: 140)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(.urbanistRegular(10))
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                            .font(.urbanistRegular(10))
                    }
                }
            }

            // Rating breakdown
            VStack(alignment: .leading, spacing: 8) {
                Text("Rating Breakdown")
                    .font(.urbanistSemiBold(13))
                    .foregroundColor(.cakeGrey)

                ForEach(ratingBreakdown.reversed(), id: \.stars) { item in
                    HStack(spacing: 10) {
                        HStack(spacing: 2) {
                            Text("\(item.stars)")
                                .font(.urbanistMedium(12))
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.2))
                        }
                        .frame(width: 30)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.cakeBrown.opacity(0.1))
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.cakeBrown)
                                    .frame(width: geo.size.width * item.fraction, height: 8)
                            }
                        }
                        .frame(height: 8)
                        Text("\(item.count)")
                            .font(.urbanistRegular(12))
                            .foregroundColor(.cakeGrey)
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: - Earnings Summary
    private var earningsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Earnings Summary", systemImage: "banknote.fill")
                .font(.urbanistBold(16))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

            HStack(spacing: 12) {
                earningCard(title: "This Month", value: "LKR 48,500", icon: "calendar", color: Color.cakeBrown)
                earningCard(title: "Last Month", value: "LKR 38,200", icon: "clock.arrow.circlepath", color: Color(red: 0.3, green: 0.45, blue: 0.8))
            }
            HStack(spacing: 12) {
                earningCard(title: "This Year", value: "LKR 3,24,000", icon: "chart.line.uptrend.xyaxis", color: Color(red: 0.2, green: 0.6, blue: 0.4))
                earningCard(title: "Avg Per Order", value: "LKR 8,700", icon: "equal.circle.fill", color: Color(red: 0.7, green: 0.45, blue: 0.1))
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func earningCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.urbanistRegular(10))
                    .foregroundColor(.cakeGrey)
                Text(value)
                    .font(.urbanistBold(13))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(red: 0.97, green: 0.96, blue: 0.94))
        .cornerRadius(14)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Settings
    private var settingsSection: some View {
        VStack(spacing: 0) {
            settingsRow(icon: "bell.fill", label: "Notifications", color: Color(red: 0.3, green: 0.45, blue: 0.8))
            Divider().padding(.leading, 52)
            settingsRow(icon: "lock.fill", label: "Privacy & Security", color: Color.cakeBrown)
            Divider().padding(.leading, 52)
            settingsRow(icon: "creditcard.fill", label: "Payment Details", color: Color(red: 0.2, green: 0.6, blue: 0.4))
            Divider().padding(.leading, 52)
            settingsRow(icon: "questionmark.circle.fill", label: "Help & Support", color: Color(red: 0.7, green: 0.45, blue: 0.1))
            Divider().padding(.leading, 52)
            Button {
                // TODO: Sign out
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.red.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "rectangle.portrait.and.arrow.backward")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                    }
                    Text("Sign Out")
                        .font(.urbanistSemiBold(15))
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(14)
            }
        }
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func settingsRow(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }
            Text(label)
                .font(.urbanistMedium(15))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.cakeGrey)
        }
        .padding(14)
    }
}

// MARK: - Flow Layout for tags
struct FlowLayout: View {
    let tags: [String]

    var body: some View {
        var width: CGFloat = 0
        var rows: [[String]] = [[]]

        // Simple tag layout
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.urbanistMedium(12))
                        .foregroundColor(.cakeBrown)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.cakeBrown.opacity(0.1))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.cakeBrown.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .flipsForRightToLeftLayoutDirection(false)
        }
    }
}

// MARK: - Baker Edit Profile Sheet
struct BakerEditProfileSheet: View {
    let user: AppUser
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var bio = "Passionate cake artist with 5+ years of experience crafting memorable cakes..."
    @State private var location = "Colombo, Sri Lanka"
    @State private var phone = "+94 77 123 4567"
    @State private var selectedTags: Set<String> = ["Wedding Cakes", "Birthday Cakes", "Fondant Art"]

    private let allCategories = ["Wedding Cakes", "Birthday Cakes", "Fondant Art", "Custom Orders",
                                  "Cupcakes", "Corporate Cakes", "Dessert Platters", "Cheesecakes",
                                  "Gluten-Free", "Vegan Cakes", "Kids Cakes", "Fruit Cakes"]

    init(user: AppUser) {
        self.user = user
        self._name = State(initialValue: user.name)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Avatar
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(Color.cakeBrown.opacity(0.18))
                            .frame(width: 90, height: 90)
                            .overlay(
                                Text(String(user.name.prefix(1)).uppercased())
                                    .font(.urbanistBold(32))
                                    .foregroundColor(.cakeBrown)
                            )
                        ZStack {
                            Circle().fill(Color.cakeBrown).frame(width: 28, height: 28)
                            Image(systemName: "camera.fill").font(.system(size: 13)).foregroundColor(.white)
                        }
                    }
                    .padding(.top, 8)

                    VStack(spacing: 14) {
                        editField(label: "Full Name", placeholder: "Your baker name", text: $name)
                        editField(label: "Phone", placeholder: "+94 XX XXX XXXX", text: $phone)
                        editField(label: "Location", placeholder: "City, Country", text: $location)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bio")
                                .font(.urbanistSemiBold(13))
                                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                            TextEditor(text: $bio)
                                .font(.urbanistRegular(14))
                                .frame(height: 100)
                                .padding(10)
                                .background(Color(red: 0.97, green: 0.96, blue: 0.94))
                                .cornerRadius(12)
                                .scrollContentBackground(.hidden)
                        }

                        // Category selection
                        VStack(alignment: .leading, spacing: 10) {
                            Text("My Specialities (select all that apply)")
                                .font(.urbanistSemiBold(13))
                                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(allCategories, id: \.self) { cat in
                                    Button {
                                        if selectedTags.contains(cat) {
                                            selectedTags.remove(cat)
                                        } else {
                                            selectedTags.insert(cat)
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: selectedTags.contains(cat) ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedTags.contains(cat) ? .cakeBrown : .cakeGrey)
                                            Text(cat)
                                                .font(.urbanistMedium(12))
                                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                            Spacer()
                                        }
                                        .padding(10)
                                        .background(selectedTags.contains(cat) ? Color.cakeBrown.opacity(0.08) : Color(red: 0.95, green: 0.95, blue: 0.95))
                                        .cornerRadius(10)
                                    }
                                }
                            }
                        }

                        Button {
                            dismiss()
                        } label: {
                            Text("Save Changes")
                                .font(.urbanistBold(16))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.cakeBrown)
                                .cornerRadius(16)
                        }
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.cakeGrey)
                }
            }
        }
    }

    private func editField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.urbanistSemiBold(13))
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
            TextField(placeholder, text: text)
                .font(.urbanistRegular(14))
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Color(red: 0.97, green: 0.96, blue: 0.94))
                .cornerRadius(12)
        }
    }
}

// MARK: - Chart Data Models
struct MonthlyOrder: Identifiable {
    let id = UUID()
    let month: String
    let count: Int
}

struct RatingItem {
    let stars: Int
    let count: Int
    let fraction: CGFloat
}

let monthlyOrderData: [MonthlyOrder] = [
    MonthlyOrder(month: "Nov", count: 4),
    MonthlyOrder(month: "Dec", count: 9),
    MonthlyOrder(month: "Jan", count: 7),
    MonthlyOrder(month: "Feb", count: 11),
    MonthlyOrder(month: "Mar", count: 14),
    MonthlyOrder(month: "Apr", count: 6),
]

let ratingBreakdown: [RatingItem] = [
    RatingItem(stars: 5, count: 38, fraction: 0.81),
    RatingItem(stars: 4, count: 6,  fraction: 0.13),
    RatingItem(stars: 3, count: 2,  fraction: 0.04),
    RatingItem(stars: 2, count: 1,  fraction: 0.02),
    RatingItem(stars: 1, count: 0,  fraction: 0.00),
]

#Preview {
    BakerProfileView(user: AppUser.mockBaker)
}
