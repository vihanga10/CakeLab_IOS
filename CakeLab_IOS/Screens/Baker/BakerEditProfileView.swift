import SwiftUI
import FirebaseFirestore
import FirebaseAuth

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
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.urbanistMedium(15))
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
        .task {
            await loadExistingData()
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
    
    // MARK: - Header Section
    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Cover Photo Placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cakeBrown.opacity(0.1))
                .frame(height: 120)
            
            Button(action: {}) {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                    Text("Edit Cover")
                        .font(.urbanistMedium(11))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.cakeBrown)
                .cornerRadius(6)
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
                Circle()
                    .fill(Color.cakeBrown.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 40))
                    .foregroundColor(.cakeBrown)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Baker Photo")
                    .font(.urbanistBold(14))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                
                Button(action: {}) {
                    Text("Change Photo")
                        .font(.urbanistMedium(13))
                        .foregroundColor(.cakeBrown)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.cakeBrown.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            
            Spacer()
        }
        .padding(14)
        .background(Color(red: 0.97, green: 0.96, blue: 0.94))
        .cornerRadius(12)
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
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
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
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.red.opacity(0.6), lineWidth: !isActive ? 0 : 1)
                        )
                }
            }
            .frame(width: 160)
        }
        .padding(14)
        .background(Color(red: 0.97, green: 0.96, blue: 0.94))
        .cornerRadius(12)
    }
    
    // MARK: - Form Section
    private var formSection: some View {
        VStack(spacing: 16) {
            formField(label: "Name", placeholder: "Enter bakery name", text: $bakeryName)
            formField(label: "Email Address", placeholder: "Enter email", text: $email)
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
                .padding(.vertical, 12)
                .background(Color.white)
                .border(Color(red: 0.88, green: 0.88, blue: 0.88), width: 1)
                .cornerRadius(8)
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
                .border(Color(red: 0.88, green: 0.88, blue: 0.88), width: 1)
                .cornerRadius(8)
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
            .padding(.vertical, 12)
            .background(
                selectedCategories.contains(categoryName) ?
                Color.cakeBrown :
                categoryColors[index % categoryColors.count]
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
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
            .padding(.vertical, 16)
            .background(Color.cakeBrown)
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }
    
    // MARK: - Load Existing Data
    private func loadExistingData() async {
        let db = Firestore.firestore()
        
        do {
            let doc = try await db.collection("artisans").document(user.id).getDocument()
            if let data = doc.data() {
                bakeryName = data["shopName"] as? String ?? user.name
                email = data["email"] as? String ?? user.email
                phoneNumber = data["phoneNumber"] as? String ?? ""
                address = data["address"] as? String ?? (user.address ?? "")
                city = data["city"] as? String ?? (user.city ?? "")
                bio = data["about"] as? String ?? ""
                let savedSpecialties = data["specialties"] as? [String] ?? []
                selectedCategories = savedSpecialties
                isActive = data["isOnline"] as? Bool ?? true
            }
        } catch {
            print("Error loading profile: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Save Profile
    private func saveProfile() async {
        isLoading = true
        defer { isLoading = false }
        
        let db = Firestore.firestore()
        
        let profileData: [String: Any] = [
            "shopName": bakeryName,
            "email": email,
            "phoneNumber": phoneNumber,
            "address": address,
            "city": city,
            "about": bio,
            "specialties": selectedCategories,
            "isOnline": isActive,
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
