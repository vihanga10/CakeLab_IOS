import SwiftUI
import PhotosUI

// MARK: - Customer Profile Detail View
@MainActor
struct CustomerProfileDetailView: View {
    let user: AppUser
    @StateObject private var viewModel: ProfileViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var showEditSheet = false
    @State private var showImagePicker = false
    @State private var selectedPhotoPickerItem: PhotosPickerItem?

    init(user: AppUser) {
        self.user = user
        _viewModel = StateObject(wrappedValue: ProfileViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.cakeBrown)
                    }
                    Spacer()
                    Text("My Profile")
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

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // MARK: - Profile Section
                        VStack(spacing: 16) {
                            ZStack(alignment: .bottomTrailing) {
                                if let urlString = viewModel.user.avatarURL, let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            Circle()
                                                .fill(Color(red: 0.90, green: 0.86, blue: 0.82))
                                                .frame(width: 100, height: 100)
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipShape(Circle())
                                        case .failure:
                                            Circle()
                                                .fill(Color(red: 0.90, green: 0.86, blue: 0.82))
                                                .frame(width: 100, height: 100)
                                                .overlay(
                                                    Image(systemName: "person.fill")
                                                        .font(.system(size: 45))
                                                        .foregroundColor(.cakeBrown)
                                                )
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                } else {
                                    Circle()
                                        .fill(Color(red: 0.90, green: 0.86, blue: 0.82))
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 45))
                                                .foregroundColor(.cakeBrown)
                                        )
                                }

                                // Camera button
                                Button(action: { showEditSheet = true }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.cakeBrown)
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)

                            Text(viewModel.user.name.isEmpty ? viewModel.user.email : viewModel.user.name)
                                .font(.urbanistBold(18))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                            if let city = viewModel.user.city, !city.isEmpty {
                                Text("\(city), Sri Lanka")
                                    .font(.urbanistRegular(13))
                                    .foregroundColor(.cakeGrey)
                            } else {
                                Text(viewModel.user.email)
                                    .font(.urbanistRegular(13))
                                    .foregroundColor(.cakeGrey)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)

                        // MARK: - Menu Items
                        // ── Account ──────────────────────────────────────
                        ProfileSection(title: "Account") {
                            MenuItem(
                                icon: "person.fill",
                                title: "Edit Profile",
                                action: { showEditSheet = true }
                            )
                            MenuItem(
                                icon: "clock.arrow.circlepath",
                                title: "Payment History",
                                action: {}
                            )
                            MenuItem(
                                icon: "lock.fill",
                                title: "Change Password",
                                action: {}
                            )
                            NavigationLink(destination: PublishRequestView()) {
                                MenuItemRow(icon: "paperplane.fill", title: "Publish Request")
                            }
                            NavigationLink(destination: DraftIdeasView()) {
                                MenuItemRow(icon: "pencil.and.scribble", title: "Draft Ideas")
                            }
                        }
                        .padding(.horizontal, 16)

                        // ── Preferences ───────────────────────────────────
                        ProfileSection(title: "Preferences") {
                            MenuItem(icon: "globe", title: "Language", action: {})
                            MenuItem(icon: "hand.raised.fill", title: "Privacy & Security", action: {})
                        }
                        .padding(.horizontal, 16)

                        // ── Support ───────────────────────────────────────
                        ProfileSection(title: "Support") {
                            MenuItem(icon: "questionmark.circle.fill", title: "Help & Support", action: {})
                            MenuItem(icon: "doc.text.fill", title: "Terms & Privacy Policy", action: {})
                        }
                        .padding(.horizontal, 16)

                        // ── Log Out ───────────────────────────────────────
                        Button(action: {}) {
                            Text("Log Out")
                                .font(.urbanistSemiBold(15))
                                .foregroundColor(Color(red: 0.85, green: 0.30, blue: 0.28))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(red: 1.0, green: 0.92, blue: 0.92))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)

                        Spacer().frame(height: 20)
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .sheet(isPresented: $showEditSheet) {
            EditProfileSheet(viewModel: viewModel, isPresented: $showEditSheet)
        }
        .task {
            await viewModel.fetchProfile()
        }
        } // end NavigationStack
    }
}

// MARK: - Profile Section Container
struct ProfileSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.urbanistSemiBold(13))
                .foregroundColor(.cakeGrey)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            VStack(spacing: 0) {
                content()
            }
            .background(Color.white)
            .cornerRadius(12)
        }
    }
}

// MARK: - Menu Item Row (for NavigationLink usage)
struct MenuItemRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.cakeBrown)
            }
            Text(title)
                .font(.urbanistRegular(15))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.cakeGrey)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Menu Item Component
struct MenuItem: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(.cakeBrown)
                }
                
                Text(title)
                    .font(.urbanistRegular(15))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.cakeGrey)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Edit Profile Sheet
struct EditProfileSheet: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Binding var isPresented: Bool
    
    @State private var showImagePicker = false
    @State private var selectedPhotoPickerItem: PhotosPickerItem?
    
    // Local form state - NOT bound to viewModel to prevent auto-save
    @State private var localFullName = ""
    @State private var localPhoneNumber = ""
    @State private var localAddress = ""
    @State private var localCity = ""
    @State private var localPostalCode = ""
    @State private var localDateOfBirth: Date? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.97, green: 0.97, blue: 0.97).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Profile Picture Preview
                        if let selectedPhoto = viewModel.selectedPhoto {
                            VStack(spacing: 8) {
                                Image(uiImage: selectedPhoto)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                Text("New profile photo selected")
                                    .font(.urbanistRegular(12))
                                    .foregroundColor(.cakeGrey)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }

                        // Upload Photo Button
                        Button(action: { showImagePicker = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text("Choose Profile Photo")
                                    .font(.urbanistSemiBold(14))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.92, green: 0.88, blue: 0.83))
                            .foregroundColor(.cakeBrown)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                        // Form Fields - using local state to prevent auto-save
                        VStack(spacing: 16) {
                            formField(label: "Full Name", placeholder: "Enter your full name", text: $localFullName)
                            formField(label: "Phone Number", placeholder: "e.g. +94 77 123 4567", text: $localPhoneNumber)
                            formField(label: "Address", placeholder: "e.g. 123 Main Street", text: $localAddress)
                            formField(label: "City", placeholder: "e.g. Colombo", text: $localCity)
                            formField(label: "Postal Code", placeholder: "e.g. 07", text: $localPostalCode)

                            // Date of Birth
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date of Birth")
                                    .font(.urbanistSemiBold(13))
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                DatePicker(
                                    "Select Date",
                                    selection: Binding(
                                        get: { localDateOfBirth ?? Date() },
                                        set: { localDateOfBirth = $0 }
                                    ),
                                    displayedComponents: .date
                                )
                                .font(.urbanistRegular(14))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color(red: 0.94, green: 0.94, blue: 0.94))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)

                        // Error Message
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
                            .cornerRadius(8)
                            .padding(.horizontal, 20)
                        }

                        // Update Button - NOW calls updateProfile with form data
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
                                isPresented = false
                            }
                        }) {
                            if viewModel.isSaving {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Updating...")
                                        .font(.urbanistSemiBold(15))
                                }
                            } else {
                                Text("Update Profile")
                                    .font(.urbanistSemiBold(15))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.cakeBrown)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(viewModel.isSaving)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        Spacer().frame(height: 20)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isPresented = false }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                        }
                        .foregroundColor(.cakeBrown)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Edit Profile")
                        .font(.urbanistBold(18))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                }
            }
        }
        .photosPicker(
            isPresented: $showImagePicker,
            selection: $selectedPhotoPickerItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhotoPickerItem) { item in
            Task {
                if let data = try await item?.loadTransferable(type: Data.self) {
                    if let uiImage = UIImage(data: data) {
                        viewModel.selectedPhoto = uiImage
                    }
                }
            }
        }
        .onAppear {
            // Initialize local form state from current user data
            localFullName = viewModel.user.name
            localPhoneNumber = viewModel.user.phoneNumber ?? ""
            localAddress = viewModel.user.address ?? ""
            localCity = viewModel.user.city ?? ""
            localPostalCode = viewModel.user.postalCode ?? ""
            localDateOfBirth = viewModel.user.dateOfBirth
        }
    }

    @ViewBuilder
    private func formField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.urbanistSemiBold(13))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            TextField(placeholder, text: text)
                .font(.urbanistRegular(14))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(red: 0.94, green: 0.94, blue: 0.94))
                .cornerRadius(10)
        }
    }
}

#Preview {
    NavigationStack {
        CustomerProfileDetailView(user: AppUser.mock)
    }
}
