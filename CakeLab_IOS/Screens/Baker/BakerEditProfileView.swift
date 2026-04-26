import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseAuth
import UIKit

// MARK: - Baker Edit Profile View
@MainActor
struct BakerEditProfileView: View {
    let user: AppUser

    @State private var isActive = true
    @State private var bakeryName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var address = ""
    @State private var city = ""
    @State private var bio = ""
    @State private var selectedCategories: [String] = []

    @State private var selectedCoverPickerItem: PhotosPickerItem?
    @State private var selectedProfilePickerItem: PhotosPickerItem?
    @State private var selectedCoverImage: UIImage?
    @State private var selectedProfileImage: UIImage?
    @State private var coverImageBase64 = ""
    @State private var profileImageBase64 = ""

    @State private var isLoading = false
    @State private var showSuccessMessage = false
    @State private var errorMessage = ""

    @Environment(\.dismiss) private var dismiss

    let allCategories: [String] = [
        "Wedding Cakes",
        "Birthday Cakes",
        "Anniversary Cakes",
        "Baby Shower Cakes",
        "Cupcakes",
        "Buttercream Cakes",
        "Corporate Cakes",
        "Engagement Cakes",
        "Graduation Cakes",
        "Baptism Cakes",
        "Retirement Cakes",
        "Farewell Cakes",
        "Vegan Cakes",
        "Sculpted Cakes"
    ]
    
    let categoryColors = [
        Color(red: 1.0, green: 0.9, blue: 0.9),    // Pink
        Color(red: 1.0, green: 0.95, blue: 0.8),   // Peach
        Color(red: 1.0, green: 1.0, blue: 0.85),   // Light Yellow
        Color(red: 0.9, green: 1.0, blue: 0.9),    // Light Green
        Color(red: 0.85, green: 0.95, blue: 1.0),  // Light Blue
        Color(red: 0.9, green: 0.85, blue: 1.0),   // Light Purple
        Color(red: 1.0, green: 0.9, blue: 1.0),    // Light Magenta
        Color(red: 0.9, green: 0.95, blue: 0.8),   // Mint
        Color(red: 1.0, green: 0.92, blue: 0.8),   // Salmon
        Color(red: 0.95, green: 0.9, blue: 1.0),   // Lavender
        Color(red: 1.0, green: 0.88, blue: 0.88),  // Rose
        Color(red: 0.88, green: 0.95, blue: 1.0),  // Sky Blue
        Color(red: 1.0, green: 0.95, blue: 0.9),   // Apricot
        Color(red: 0.9, green: 1.0, blue: 0.95)    // Mint Green
    ]

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // MARK: Header
                        headerSection
                            .padding(.bottom, 24)

                        // MARK: Profile Photo
                        profilePhotoSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)

                        // MARK: Active/Inactive Toggle
                        activeToggleSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        // MARK: Form Fields
                        formSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        // MARK: Categories
                        categoriesSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        // MARK: Update Button
                        updateButton
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .task {
            await loadExistingData()
        }
        .onChange(of: selectedCoverPickerItem) { item in
            Task {
                guard let data = try await item?.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                selectedCoverImage = image
                coverImageBase64 = encodeImageToBase64(image)
            }
        }
        .onChange(of: selectedProfilePickerItem) { item in
            Task {
                guard let data = try await item?.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                selectedProfileImage = image
                profileImageBase64 = encodeImageToBase64(image)
            }
        }
        .alert("Success", isPresented: $showSuccessMessage) {
            Button("OK") { dismiss() }
        } message: {
            Text("Profile updated successfully!")
        }
        .alert("Error", isPresented: .constant(!errorMessage.isEmpty)) {
            Button("OK") { errorMessage = "" }
        } message: {
            Text(errorMessage)
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
            Text("Edit Profile")
                .font(.urbanistBold(18))
                .foregroundColor(Color(hex: "5D3714"))
            Spacer()
            Color.clear.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.white)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let selectedCoverImage {
                    Image(uiImage: selectedCoverImage)
                        .resizable()
                        .scaledToFill()
                } else if let savedCover = decodeBase64Image(coverImageBase64) {
                    Image(uiImage: savedCover)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.cakeBrown.opacity(0.1))
                }
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            PhotosPicker(selection: $selectedCoverPickerItem, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                    Text("Edit Cover")
                        .font(.urbanistMedium(11))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.cakeBrown)
                .clipShape(Capsule())
            }
            .padding(12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Profile Photo Section
    private var profilePhotoSection: some View {
        HStack(spacing: 16) {
            ZStack {
                if let selectedProfileImage {
                    Image(uiImage: selectedProfileImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else if let savedProfile = decodeBase64Image(profileImageBase64) {
                    Image(uiImage: savedProfile)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.cakeBrown.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 40))
                                .foregroundColor(.cakeBrown)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                

                PhotosPicker(selection: $selectedProfilePickerItem, matching: .images, photoLibrary: .shared()) {
                    Text("Change Photo")
                        .font(.urbanistMedium(13))
                        .foregroundColor(.cakeBrown)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 5)
                        .background(Color.cakeBrown.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            Spacer()
        }
        .padding(14)
        .background(Color(red: 0.97, green: 0.96, blue: 0.94))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Active/Inactive Toggle
    private var activeToggleSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Status")
                    .font(.urbanistBold(14))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                Text("Mark yourself as active or inactive")
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeGrey)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { isActive = true }) {
                    Text("Active")
                        .font(.urbanistMedium(13))
                        .foregroundColor(isActive ? .white : .cakeBrown)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isActive ? Color(red: 0.2, green: 0.6, blue: 0.4) : Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 0.2, green: 0.6, blue: 0.4), lineWidth: isActive ? 0 : 1)
                        )
                }

                Button(action: { isActive = false }) {
                    Text("Inactive")
                        .font(.urbanistMedium(13))
                        .foregroundColor(!isActive ? .white : .cakeBrown)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(!isActive ? Color.red.opacity(0.6) : Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.red.opacity(0.6), lineWidth: !isActive ? 0 : 1)
                        )
                }
            }
            .frame(width: 160)
        }
        .padding(14)
        .background(Color(red: 0.97, green: 0.96, blue: 0.94))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Form Section
    private var formSection: some View {
        VStack(spacing: 16) {
            formField(label: "Name", placeholder: "Enter bakery name", text: $bakeryName)
            readOnlyField(label: "Email Address", value: email)
            formField(label: "Phone Number", placeholder: "+94 74 234 5436", text: $phoneNumber)
            formField(label: "Address", placeholder: "e.g No 8, Flower Road", text: $address)
            formField(label: "City", placeholder: "e.g colombo", text: $city)

            bioField
        }
    }

    private func formField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.urbanistBold(14))
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

    private func readOnlyField(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.urbanistBold(14))
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
    
    private var bioField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bio")
                .font(.urbanistBold(14))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            
            TextEditor(text: $bio)
                .font(.urbanistRegular(14))
                .frame(height: 100)
                .padding(8)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.35), lineWidth: 1)
                )
                .cornerRadius(10)
        }
    }
    
    // MARK: - Categories Section
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Categories")
                .font(.urbanistBold(14))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            
            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(allCategories.enumerated()), id: \.offset) { index, category in
                    categoryButton(categoryName: category, index: index)
                }
            }
        }
    }
    
    private func categoryButton(categoryName: String, index: Int) -> some View {
        Button(action: {
            if selectedCategories.contains(categoryName) {
                selectedCategories.removeAll { $0 == categoryName }
            } else {
                selectedCategories.append(categoryName)
            }
        }) {
            VStack(spacing: 6) {
                Text(categoryName)
                    .font(.urbanistMedium(11))
                    .foregroundColor(selectedCategories.contains(categoryName) ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                selectedCategories.contains(categoryName) ?
                Color.cakeBrown :
                categoryColors[index % categoryColors.count]
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        selectedCategories.contains(categoryName) ? Color.cakeBrown : Color.clear,
                        lineWidth: 2
                    )
            )
        }
    }
    
    // MARK: - Update Button
    private var updateButton: some View {
        Button(action: {
            Task {
                await saveProfile()
            }
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Update")
                        .font(.urbanistBold(15))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Color.cakeBrown)
            .clipShape(Capsule())
        }
        .disabled(isLoading)
    }
    
    // MARK: - Load Existing Data
    private func loadExistingData() async {
        let db = Firestore.firestore()
        bakeryName = user.name
        email = user.email
        phoneNumber = user.phoneNumber ?? ""
        address = user.address ?? ""
        city = user.city ?? ""

        do {
            let artisanSnapshot = try await loadArtisanDocument(db: db, userID: user.id)
            if let data = artisanSnapshot.data() {
                bakeryName = data["shopName"] as? String ?? user.name
                email = user.email
                phoneNumber = data["phoneNumber"] as? String ?? ""
                address = data["address"] as? String ?? (user.address ?? "")
                city = data["city"] as? String ?? (user.city ?? "")
                bio = data["about"] as? String ?? ""
                let savedSpecialties = data["specialties"] as? [String] ?? []
                selectedCategories = savedSpecialties
                isActive = data["isOnline"] as? Bool ?? true
                coverImageBase64 = data["coverImageBase64"] as? String ?? ""
                profileImageBase64 = data["profileImageBase64"] as? String ?? ""
            }
        } catch {
            print("Error loading profile: \(error.localizedDescription)")
        }
    }

    private func loadArtisanDocument(db: Firestore, userID: String) async throws -> DocumentSnapshot {
        let direct = try await db.collection("artisans").document(userID).getDocument()
        if direct.exists { return direct }

        let query = try await db.collection("artisans")
            .whereField("uid", isEqualTo: userID)
            .limit(to: 1)
            .getDocuments()

        if let first = query.documents.first {
            return first
        }

        return direct
    }

    private func encodeImageToBase64(_ image: UIImage) -> String {
        let jpegData = image.jpegData(compressionQuality: 0.35)
        return jpegData?.base64EncodedString() ?? ""
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
    
    // MARK: - Save Profile
    private func saveProfile() async {
        isLoading = true
        defer { isLoading = false }

        let db = Firestore.firestore()

        let profileData: [String: Any] = [
            "shopName": bakeryName,
            "name": bakeryName,
            "email": user.email,
            "phoneNumber": phoneNumber,
            "address": address,
            "city": city,
            "about": bio,
            "specialties": selectedCategories,
            "isOnline": isActive,
            "coverImageBase64": coverImageBase64,
            "profileImageBase64": profileImageBase64,
            "updatedAt": Timestamp(date: Date())
        ]

        do {
            try await db.collection("artisans").document(user.id).setData(profileData, merge: true)
            print("✅ Profile updated successfully!")
            showSuccessMessage = true
        } catch {
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
            print("❌ Error saving profile: \(error.localizedDescription)")
        }
    }
}

#Preview {
    NavigationStack {
        BakerEditProfileView(user: AppUser(
            id: "123",
            email: "baker@test.com",
            name: "Sweet Creations",
            role: .baker,
            avatarURL: nil,
            createdAt: Date(),
            address: "123 Main St",
            city: "Colombo"
        ))
    }
}
