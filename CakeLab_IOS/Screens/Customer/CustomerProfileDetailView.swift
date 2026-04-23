import SwiftUI
import PhotosUI
import FirebaseAuth

// MARK: - Customer Profile Detail View
@MainActor
struct CustomerProfileDetailView: View {
    let user: AppUser
    @StateObject private var viewModel: ProfileViewModel

    @State private var navigateToSignIn = false
    @State private var showPaymentHistory = false
    @State private var selectedDetailView: String? = nil
    @State private var selectedLanguage: String = UserDefaults.standard.string(forKey: "appLanguage") ?? "English"
    @State private var profileVisibility: String = UserDefaults.standard.string(forKey: "profileVisibility") ?? "Public"
    @State private var showOrderHistory: Bool = UserDefaults.standard.bool(forKey: "showOrderHistory") ?? true
    @State private var marketingEmails: Bool = UserDefaults.standard.bool(forKey: "marketingEmails") ?? true
    @State private var dataSharing: Bool = UserDefaults.standard.bool(forKey: "dataSharing") ?? false
    @State private var biometricAuth: Bool = UserDefaults.standard.bool(forKey: "biometricAuth") ?? false
    @State private var expandedFAQs: Set<Int> = []
    @State private var searchText: String = ""
    @State private var selectedTermsTab: Int = 0
    @State private var showDeleteAlert = false
    @State private var localAvatar: UIImage? = nil

    init(user: AppUser) {
        self.user = user
        _viewModel = StateObject(wrappedValue: ProfileViewModel(user: user))
    }

    private var displayName: String {
        viewModel.user.name.isEmpty ? "Sunadi Perera" : viewModel.user.name
    }

    private var locationText: String {
        let address = viewModel.user.address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let city = viewModel.user.city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let parts = [address, city].filter { !$0.isEmpty }

        if !parts.isEmpty {
            return parts.joined(separator: ", ")
        }

        return "Colombo, Sri Lanka"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header with back button for detail views
                    if selectedDetailView != nil {
                        HStack {
                            Button(action: { selectedDetailView = nil }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.cakeBrown)
                            }
                            Spacer()
                            VStack(spacing: 2) {
                                Text(detailViewTitle)
                                    .font(.urbanistBold(18))
                                    .foregroundColor(.cakeBrown)
                            }
                            Spacer()
                            Color.clear.frame(width: 24)
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 56)
                        .background(Color.white)
                    } else {
                        Text("My Profile")
                            .font(.urbanistBold(18))
                            .foregroundColor(Color(hex: "5D3714"))
                            .padding(.top, 18)
                            .padding(.bottom, 10)
                    }

                    // Content
                    if let detailedView = selectedDetailView {
                        ScrollView(showsIndicators: false) {
                            switch detailedView {
                            case "language":
                                LanguageDetailContent(selectedLanguage: $selectedLanguage)
                            case "privacy":
                                PrivacyDetailContent(profileVisibility: $profileVisibility, showOrderHistory: $showOrderHistory, marketingEmails: $marketingEmails, dataSharing: $dataSharing, biometricAuth: $biometricAuth, showDeleteAlert: $showDeleteAlert)
                            case "help":
                                HelpDetailContent(searchText: $searchText, expandedFAQs: $expandedFAQs)
                            case "terms":
                                TermsDetailContent(selectedTab: $selectedTermsTab)
                            default:
                                EmptyView()
                            }
                        }
                        
                        VStack(spacing: 12) {
                            Button(action: {
                                saveDetailSettings()
                                selectedDetailView = nil
                            }) {
                                Text("Save & Done")
                                    .font(.urbanistSemiBold(16))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(Color(hex: "5D3714"))
                                    .cornerRadius(27)
                                    .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 20)
                        .padding(.top, 12)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 26) {
                                VStack(spacing: 10) {
                                    profileAvatar(size: 138)
                                        .padding(.top, 8)

                                    Text(displayName)
                                        .font(.urbanistBold(22))
                                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                                    HStack(spacing: 7) {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color.gray)

                                        Text(locationText)
                                            .font(.urbanistRegular(14))
                                            .foregroundColor(Color(hex: "7B7B7B"))
                                    }
                                    .padding(.top, -2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 8)

                                ProfileSection(title: "Account") {
                                    NavigationLink(destination: EditProfileView(viewModel: viewModel)) {
                                        MenuItemRow(
                                            icon: "person.fill",
                                            title: "Edit Profile",
                                            iconColor: Color(hex: "111111"),
                                            iconBackground: Color(hex: "EFEAE2")
                                        )
                                    }
                                    MenuItem(
                                        icon: "clock.arrow.circlepath",
                                        title: "Payment History",
                                        iconColor: Color(hex: "2F3C8F"),
                                        iconBackground: Color(hex: "E6F8F9"),
                                        action: { showPaymentHistory = true }
                                    )
                                    MenuItem(
                                        icon: "eye.slash.fill",
                                        title: "Change Password",
                                        iconColor: Color(hex: "92711B"),
                                        iconBackground: Color(hex: "FFF8DB"),
                                        action: {}
                                    )
                                    NavigationLink(destination: PublishRequestView(user: user)) {
                                        MenuItemRow(
                                            icon: "briefcase.fill",
                                            title: "Publish Request",
                                            iconColor: Color(hex: "8A3A63"),
                                            iconBackground: Color(hex: "F8E8F5")
                                        )
                                    }
                                    NavigationLink(destination: DraftIdeasView(user: user)) {
                                        MenuItemRow(
                                            icon: "lightbulb.fill",
                                            title: "Draft Ideas",
                                            iconColor: Color(hex: "6B56A5"),
                                            iconBackground: Color(hex: "EEE8FF"),
                                            showDivider: false
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)

                                ProfileSection(title: "Preferences") {
                                    Button(action: { selectedDetailView = "language" }) {
                                        MenuItemRow(
                                            icon: "globe",
                                            title: "Language",
                                            iconColor: Color(hex: "4C8B35"),
                                            iconBackground: Color(hex: "E9F9E1")
                                        )
                                    }
                                    Button(action: { selectedDetailView = "privacy" }) {
                                        MenuItemRow(
                                            icon: "shield.fill",
                                            title: "Privacy & Security",
                                            iconColor: Color(hex: "F44336"),
                                            iconBackground: Color(hex: "FFE9E7"),
                                            showDivider: false
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)

                                ProfileSection(title: "Support") {
                                    Button(action: { selectedDetailView = "help" }) {
                                        MenuItemRow(
                                            icon: "questionmark.circle.fill",
                                            title: "Help & Support",
                                            iconColor: Color(hex: "4F4F4F"),
                                            iconBackground: Color(hex: "ECECEC")
                                        )
                                    }
                                    Button(action: { selectedDetailView = "terms" }) {
                                        MenuItemRow(
                                            icon: "lock.shield.fill",
                                            title: "Terms & Privacy Policy",
                                            iconColor: Color(hex: "4F4F4F"),
                                            iconBackground: Color(hex: "ECECEC"),
                                            showDivider: false
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)

                                Button(action: {
                                    do {
                                        try Auth.auth().signOut()
                                        WidgetDataSyncManager.shared.clearWidgetData()
                                        navigateToSignIn = true
                                    } catch {
                                        print("Logout failed: \(error.localizedDescription)")
                                    }
                                }) {
                                    Text("Log Out")
                                        .font(.urbanistSemiBold(16))
                                        .foregroundColor(Color(hex: "F0483E"))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 54)
                                        .background(Color(hex: "FFE1E4"))
                                        .cornerRadius(27)
                                        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 8)

                                Spacer().frame(height: 20)
                            }
                            .padding(.top, 12)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToSignIn) {
                SignInView()
            }
            .navigationDestination(isPresented: $showPaymentHistory) {
                PaymentHistoryView(user: user)
            }
            .alert("Delete Account", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    // Handle account deletion
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.")
            }
            .task {
                await viewModel.fetchProfile()
                // Load avatar from local storage
                localAvatar = viewModel.loadAvatarFromUserDefaults()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("profileAvatarUpdated"))) { _ in
                localAvatar = viewModel.loadAvatarFromUserDefaults()
            }
        }
    }
    
    private var detailViewTitle: String {
        switch selectedDetailView {
        case "language": return "Language"
        case "privacy": return "Privacy & Security"
        case "help": return "Help & Support"
        case "terms": return "Terms & Privacy"
        default: return ""
        }
    }
    
    private func saveDetailSettings() {
        UserDefaults.standard.set(selectedLanguage, forKey: "appLanguage")
        UserDefaults.standard.set(profileVisibility, forKey: "profileVisibility")
        UserDefaults.standard.set(showOrderHistory, forKey: "showOrderHistory")
        UserDefaults.standard.set(marketingEmails, forKey: "marketingEmails")
        UserDefaults.standard.set(dataSharing, forKey: "dataSharing")
        UserDefaults.standard.set(biometricAuth, forKey: "biometricAuth")
    }

    @ViewBuilder
    private func profileAvatar(size: CGFloat) -> some View {
        if let selectedPhoto = viewModel.selectedPhoto {
            Image(uiImage: selectedPhoto)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 5)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 16, y: 8)
        } else if let localAvatar = localAvatar {
            Image(uiImage: localAvatar)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 5)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 16, y: 8)
        } else {
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .padding(size * 0.24)
                .frame(width: size, height: size)
                .foregroundColor(Color(hex: "7C5A38"))
                .background(Color(hex: "D8D0C8"))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 5)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 16, y: 8)
        }
    }
}

// MARK: - Profile Section Container
struct ProfileSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.urbanistMedium(16))
                .foregroundColor(Color(hex: "676767"))
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                content()
            }
            .background(Color.white.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.03), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 12, y: 6)
        }
    }
}

// MARK: - Menu Item Row (for NavigationLink usage)
struct MenuItemRow: View {
    let icon: String
    let title: String
    let iconColor: Color
    let iconBackground: Color
    var showDivider: Bool = true

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconBackground)
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            Text(title)
                .font(.urbanistRegular(15))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.black)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            if showDivider {
                Divider()
                    .padding(.leading, 58)
            }
        }
    }
}

// MARK: - Menu Item Component
struct MenuItem: View {
    let icon: String
    let title: String
    let iconColor: Color
    let iconBackground: Color
    var showDivider: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconBackground)
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                Text(title)
                    .font(.urbanistRegular(15))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.black)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .overlay(alignment: .bottom) {
                if showDivider {
                    Divider()
                        .padding(.leading, 58)
                }
            }
        }
    }
}

// MARK: - Language Detail Content
struct LanguageDetailContent: View {
    @Binding var selectedLanguage: String
    private let languages = [("English", "🇬🇧"), ("සිංහල", "🇱🇰"), ("தமிழ்", "🇮🇳")]
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                ForEach(Array(languages.enumerated()), id: \.offset) { index, language in
                    Button(action: { selectedLanguage = language.0 }) {
                        HStack(spacing: 16) {
                            Text(language.1)
                                .font(.system(size: 24))
                            
                            Text(language.0)
                                .font(.urbanistMedium(16))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            
                            Spacer()
                            
                            if selectedLanguage == language.0 {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "C17C3D"))
                                        .frame(width: 24, height: 24)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            } else {
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                    .frame(width: 24, height: 24)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                    
                    if index < languages.count - 1 {
                        Divider()
                            .padding(.leading, 50)
                    }
                }
            }
            .background(Color.white.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.03), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "4C8B35"))
                    Text("Language Preference")
                        .font(.urbanistSemiBold(14))
                        .foregroundColor(Color(hex: "4C8B35"))
                }
                Text("Your selected language will be applied across the CakeLab app.")
                    .font(.urbanistRegular(13))
                    .foregroundColor(Color(hex: "676767"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(hex: "E9F9E1").opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            Spacer()
        }
    }
}

// MARK: - Privacy Detail Content
struct PrivacyDetailContent: View {
    @Binding var profileVisibility: String
    @Binding var showOrderHistory: Bool
    @Binding var marketingEmails: Bool
    @Binding var dataSharing: Bool
    @Binding var biometricAuth: Bool
    @Binding var showDeleteAlert: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Profile & Visibility")
                    .font(.urbanistMedium(14))
                    .foregroundColor(Color(hex: "676767"))
                    .padding(.horizontal, 20)
                
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Profile Visibility")
                                .font(.urbanistMedium(14))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            Text("Control who can see your profile")
                                .font(.urbanistRegular(12))
                                .foregroundColor(Color(hex: "7B7B7B"))
                        }
                        Spacer()
                        Picker("", selection: $profileVisibility) {
                            Text("Public").tag("Public")
                            Text("Private").tag("Private")
                            Text("Friends Only").tag("Friends Only")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    
                    Divider().padding(.leading, 16)
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Order History")
                                .font(.urbanistMedium(14))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            Text("Allow bakers to see your past orders")
                                .font(.urbanistRegular(12))
                                .foregroundColor(Color(hex: "7B7B7B"))
                        }
                        Spacer()
                        Toggle("", isOn: $showOrderHistory)
                            .tint(Color(hex: "C17C3D"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .background(Color.white.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.03), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
                .padding(.horizontal, 20)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Communication")
                    .font(.urbanistMedium(14))
                    .foregroundColor(Color(hex: "676767"))
                    .padding(.horizontal, 20)
                
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Marketing Emails")
                                .font(.urbanistMedium(14))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            Text("Receive offers and updates")
                                .font(.urbanistRegular(12))
                                .foregroundColor(Color(hex: "7B7B7B"))
                        }
                        Spacer()
                        Toggle("", isOn: $marketingEmails)
                            .tint(Color(hex: "C17C3D"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    
                    Divider().padding(.leading, 16)
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Data Sharing")
                                .font(.urbanistMedium(14))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            Text("Help improve CakeLab with analytics")
                                .font(.urbanistRegular(12))
                                .foregroundColor(Color(hex: "7B7B7B"))
                        }
                        Spacer()
                        Toggle("", isOn: $dataSharing)
                            .tint(Color(hex: "C17C3D"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .background(Color.white.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.03), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
                .padding(.horizontal, 20)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Security")
                    .font(.urbanistMedium(14))
                    .foregroundColor(Color(hex: "676767"))
                    .padding(.horizontal, 20)
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Biometric Authentication")
                            .font(.urbanistMedium(14))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        Text("Use Face ID or Touch ID to login")
                            .font(.urbanistRegular(12))
                            .foregroundColor(Color(hex: "7B7B7B"))
                    }
                    Spacer()
                    Toggle("", isOn: $biometricAuth)
                        .tint(Color(hex: "C17C3D"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.03), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
                .padding(.horizontal, 20)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Data Management")
                    .font(.urbanistMedium(14))
                    .foregroundColor(Color(hex: "676767"))
                    .padding(.horizontal, 20)
                
                VStack(spacing: 0) {
                    Button(action: {}) {
                        HStack(spacing: 12) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(width: 34, height: 34)
                                .background(Color.red.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            Text("Delete Account")
                                .font(.urbanistRegular(15))
                                .foregroundColor(.red)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                }
                .background(Color.white.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.03), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
                .padding(.horizontal, 20)
            }
            
            Spacer().frame(height: 24)
        }
        .padding(.top, 20)
    }
}

// MARK: - Help Detail Content
struct HelpDetailContent: View {
    @Binding var searchText: String
    @Binding var expandedFAQs: Set<Int>
    
    private let faqs = [
        ("How do I place a cake order?", "To place an order, go to the Home tab, select 'Create Request', and provide details about your cake."),
        ("How do I track my order?", "You can track your order status in the 'Orders' tab with real-time updates."),
        ("What payment methods are accepted?", "CakeLab accepts credit/debit cards, digital wallets, and bank transfers."),
        ("Can I modify my order after placing it?", "You can modify your order within 24 hours of placing it."),
        ("What is your refund policy?", "We offer full refunds if you cancel within 24 hours."),
        ("How do bakers receive orders?", "Bakers receive notifications and can place bids on orders matching their specialties.")
    ]
    
    private var filteredFAQs: [(Int, (String, String))] {
        if searchText.isEmpty {
            return faqs.enumerated().map { ($0.offset, $0.element) }
        }
        return faqs.enumerated().filter { $0.element.0.localizedCaseInsensitiveContains(searchText) || $0.element.1.localizedCaseInsensitiveContains(searchText) }.map { ($0.offset, $0.element) }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "7B7B7B"))
                    
                    TextField("Search FAQs...", text: $searchText)
                        .font(.urbanistRegular(14))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "7B7B7B"))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(hex: "F5F5F5"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Frequently Asked Questions")
                    .font(.urbanistMedium(14))
                    .foregroundColor(Color(hex: "676767"))
                    .padding(.horizontal, 20)
                
                if filteredFAQs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(Color(hex: "C17C3D").opacity(0.5))
                        Text("No FAQs found")
                            .font(.urbanistMedium(16))
                            .foregroundColor(Color(hex: "676767"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .padding(.horizontal, 20)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredFAQs.enumerated()), id: \.element.0) { index, faq in
                            FAQItemView(
                                question: faq.1.0,
                                answer: faq.1.1,
                                isExpanded: expandedFAQs.contains(faq.0),
                                onToggle: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if expandedFAQs.contains(faq.0) {
                                            expandedFAQs.remove(faq.0)
                                        } else {
                                            expandedFAQs.insert(faq.0)
                                        }
                                    }
                                }
                            )
                            
                            if index < filteredFAQs.count - 1 {
                                Divider().padding(.horizontal, 16)
                            }
                        }
                    }
                    .background(Color.white.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.03), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
                    .padding(.horizontal, 20)
                }
            }
            
            Spacer().frame(height: 24)
        }
        .padding(.top, 20)
    }
}

// MARK: - Terms Detail Content
struct TermsDetailContent: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TabButton(title: "Terms of Service", isSelected: selectedTab == 0) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = 0
                    }
                }
                TabButton(title: "Privacy Policy", isSelected: selectedTab == 1) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = 1
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(hex: "F5F5F5"))
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if selectedTab == 0 {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeaderView(title: "1. Acceptance of Terms")
                            BodyTextView(text: "By accessing and using CakeLab, you accept and agree to be bound by the terms and provision of this agreement.")
                            
                            SectionHeaderView(title: "2. Disclaimer")
                            BodyTextView(text: "The materials on CakeLab are provided on an 'as is' basis. CakeLab makes no warranties, expressed or implied.")
                            
                            SectionHeaderView(title: "3. Modifications")
                            BodyTextView(text: "CakeLab may revise these terms of service for the website at any time without notice. By using this website, you are agreeing to be bound by the then current version of these terms of service.")
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeaderView(title: "1. Information Collection and Use")
                            BodyTextView(text: "CakeLab collects information you provide directly, such as when you create an account or place an order. This includes name, email address, phone number, delivery address, and payment information.")
                            
                            SectionHeaderView(title: "2. How We Use Your Information")
                            BodyTextView(text: "We use the information we collect to process and deliver your orders, send you service-related announcements, respond to your inquiries, and comply with legal obligations.")
                            
                            SectionHeaderView(title: "3. Data Security")
                            BodyTextView(text: "We employ appropriate technical and organizational measures to protect your personal information. However, no security system is impenetrable.")
                        }
                    }
                    
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
    }
}

// MARK: - FAQ Item View
struct FAQItemView: View {
    let question: String
    let answer: String
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Text(question)
                        .font(.urbanistSemiBold(14))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "7B7B7B"))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider().padding(.horizontal, 16)
                    
                    Text(answer)
                        .font(.urbanistRegular(13))
                        .foregroundColor(Color(hex: "676767"))
                        .lineLimit(nil)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
        }
    }
}

// MARK: - Tab Button Component
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.urbanistMedium(14))
                    .foregroundColor(isSelected ? Color(hex: "5D3714") : Color(hex: "7B7B7B"))
                
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "C17C3D"))
                        .frame(height: 3)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Section Header Component
struct SectionHeaderView: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.urbanistSemiBold(15))
            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            .padding(.top, 8)
    }
}

// MARK: - Body Text Component
struct BodyTextView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.urbanistRegular(13))
            .foregroundColor(Color(hex: "676767"))
            .lineLimit(nil)
            .lineSpacing(1.5)
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showImagePicker = false
    @State private var selectedPhotoPickerItem: PhotosPickerItem?
    @State private var localAvatar: UIImage? = nil

    @State private var localFullName = ""
    @State private var localPhoneNumber = ""
    @State private var localAddress = ""
    @State private var localCity = ""
    @State private var localPostalCode = ""
    @State private var localDateOfBirth: Date? = nil

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 26) {
                        Button(action: { showImagePicker = true }) {
                            profileEditorAvatar
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 22)

                        VStack(spacing: 18) {
                            formField(label: "Full Name", placeholder: "Enter your full name", text: $localFullName)
                            readOnlyField(label: "Email Address", value: viewModel.user.email)
                            formField(label: "Phone Number", placeholder: "+94 74 234 5436", text: $localPhoneNumber)
                            formField(label: "Address", placeholder: "e.g No 8, Flower Road", text: $localAddress)
                            formField(label: "City", placeholder: "e.g colombo", text: $localCity)
                            formField(label: "Postal Code", placeholder: "e.g 403848", text: $localPostalCode)
                        }
                        .padding(.horizontal, 20)

                        if let error = viewModel.errorMessage {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.urbanistRegular(12))
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }

                        Button(action: {
                            Task {
                                await viewModel.updateProfile(
                                    name: localFullName,
                                    phone: localPhoneNumber,
                                    address: localAddress,
                                    city: localCity,
                                    postalCode: localPostalCode,
                                    dob: localDateOfBirth
                                )
                                dismiss()
                            }
                        }) {
                            Group {
                                if viewModel.isSaving {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .tint(.white)
                                        Text("Updating...")
                                            .font(.urbanistSemiBold(15))
                                    }
                                } else {
                                    Text("Update")
                                        .font(.urbanistSemiBold(17))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Color(hex: "5D3714"))
                            .clipShape(Capsule())
                        }
                        .disabled(viewModel.isSaving)
                        .padding(.horizontal, 14)
                        .padding(.top, 8)

                        Spacer().frame(height: 20)
                    }
                    .padding(.bottom, 28)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .photosPicker(
            isPresented: $showImagePicker,
            selection: $selectedPhotoPickerItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhotoPickerItem) { item in
            Task {
                if let data = try await item?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    viewModel.selectedPhoto = uiImage
                    // Update localAvatar for immediate visual feedback
                    localAvatar = uiImage
                }
            }
        }
        .onAppear {
            localFullName = viewModel.user.name
            localPhoneNumber = viewModel.user.phoneNumber ?? ""
            localAddress = viewModel.user.address ?? ""
            localCity = viewModel.user.city ?? ""
            localPostalCode = viewModel.user.postalCode ?? ""
            localDateOfBirth = viewModel.user.dateOfBirth
            // Load avatar from local storage
            localAvatar = viewModel.loadAvatarFromUserDefaults()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("profileAvatarUpdated"))) { _ in
            localAvatar = viewModel.loadAvatarFromUserDefaults()
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
                Text("Edit Profile")
                    .font(.urbanistBold(18))
                    .foregroundColor(Color(hex: "5D3714"))
            }
            Spacer()
            Color.clear.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.white)
    }

    private var profileEditorAvatar: some View {
        ZStack(alignment: .bottomTrailing) {
            profileImage(size: 148)

            ZStack {
                Circle()
                    .fill(Color(hex: "D9D9D9"))
                    .frame(width: 34, height: 34)
                Image(systemName: "camera.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "5B5B5B"))
            }
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 3)
            )
            .offset(x: -2, y: -2)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 16, y: 8)
    }

    @ViewBuilder
    private func profileImage(size: CGFloat) -> some View {
        if let selectedPhoto = viewModel.selectedPhoto {
            Image(uiImage: selectedPhoto)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else if let localAvatar = localAvatar {
            Image(uiImage: localAvatar)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .padding(size * 0.24)
                .frame(width: size, height: size)
                .foregroundColor(Color(hex: "7C5A38"))
                .background(Color(hex: "D8D0C8"))
                .clipShape(Circle())
        }
    }

    @ViewBuilder
    private func formField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.urbanistMedium(15))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            TextField(placeholder, text: text)
                .font(.urbanistRegular(14))
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.black.opacity(0.35), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func readOnlyField(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.urbanistMedium(15))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            Text(value)
                .font(.urbanistRegular(14))
                .foregroundColor(Color(hex: "7D7D7D"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.black.opacity(0.35), lineWidth: 1)
                )
        }
    }
}

#Preview {
    NavigationStack {
        CustomerProfileDetailView(user: AppUser.mock)
    }
}
