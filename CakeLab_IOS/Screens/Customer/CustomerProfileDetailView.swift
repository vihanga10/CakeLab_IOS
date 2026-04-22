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
                    Text("My Profile")
                        .font(.urbanistBold(18))
                        .foregroundColor(Color(hex: "5D3714"))
                        .padding(.top, 18)
                        .padding(.bottom, 10)

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
                                MenuItem(
                                    icon: "globe",
                                    title: "Language",
                                    iconColor: Color(hex: "4C8B35"),
                                    iconBackground: Color(hex: "E9F9E1"),
                                    action: {}
                                )
                                MenuItem(
                                    icon: "shield.fill",
                                    title: "Privacy & Security",
                                    iconColor: Color(hex: "F44336"),
                                    iconBackground: Color(hex: "FFE9E7"),
                                    showDivider: false,
                                    action: {}
                                )
                            }
                            .padding(.horizontal, 16)

                            ProfileSection(title: "Support") {
                                MenuItem(
                                    icon: "questionmark.circle.fill",
                                    title: "Help & Support",
                                    iconColor: Color(hex: "4F4F4F"),
                                    iconBackground: Color(hex: "ECECEC"),
                                    action: {}
                                )
                                MenuItem(
                                    icon: "lock.shield.fill",
                                    title: "Terms & Privacy Policy",
                                    iconColor: Color(hex: "4F4F4F"),
                                    iconBackground: Color(hex: "ECECEC"),
                                    showDivider: false,
                                    action: {}
                                )
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
            .navigationBarBackButtonHidden(true)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToSignIn) {
                SignInView()
            }
            .navigationDestination(isPresented: $showPaymentHistory) {
                PaymentHistoryView(user: user)
            }
            .task {
                await viewModel.fetchProfile()
            }
        }
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
        } else if let urlString = viewModel.user.avatarURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty, .failure:
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .padding(size * 0.24)
                        .foregroundColor(Color(hex: "7C5A38"))
                        .background(Color(hex: "D8D0C8"))
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: size, height: size)
            .background(Color(hex: "D8D0C8"))
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

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showImagePicker = false
    @State private var selectedPhotoPickerItem: PhotosPickerItem?

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
                            .background(Color(hex: "7A4A18"))
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
        } else if let urlString = viewModel.user.avatarURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty, .failure:
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .padding(size * 0.24)
                        .foregroundColor(Color(hex: "7C5A38"))
                        .background(Color(hex: "D8D0C8"))
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: size, height: size)
            .background(Color(hex: "D8D0C8"))
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
