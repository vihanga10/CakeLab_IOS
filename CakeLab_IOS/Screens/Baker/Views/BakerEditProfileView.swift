import SwiftUI
import PhotosUI
import UIKit

// MARK: - Baker Edit Profile View
@MainActor
struct BakerEditProfileView: View {
    let user: AppUser

    @StateObject private var viewModel: BakerEditProfileViewModel

    @State private var selectedCoverPickerItem: PhotosPickerItem?
    @State private var selectedProfilePickerItem: PhotosPickerItem?
    @State private var showDistrictPicker = false

    @Environment(\.dismiss) private var dismiss
    private let inactiveStatusColor = Color(hex: "D22B2B")

    init(user: AppUser) {
        self.user = user
        _viewModel = StateObject(wrappedValue: BakerEditProfileViewModel(user: user))
    }

    var body: some View {
        ZStack {
            Color.cakeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        
                        headerSection
                            .padding(.bottom, 24)

                        
                        profilePhotoSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)

                        
                        activeToggleSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        
                        formSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        
                        categoriesSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        
                        updateButton
                            .padding(.horizontal, 20)
                            .padding(.bottom, 104)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .asBakerSubScreen()
        .task {
            await viewModel.loadExistingData()
        }
        .onChange(of: selectedCoverPickerItem) { item in
            Task {
                await viewModel.updateCoverImage(from: item)
            }
        }
        .onChange(of: selectedProfilePickerItem) { item in
            Task {
                await viewModel.updateProfileImage(from: item)
            }
        }
        .alert("Error", isPresented: .constant(!viewModel.errorMessage.isEmpty)) {
            Button("OK") { viewModel.errorMessage = "" }
        } message: {
            Text(viewModel.errorMessage)
        }
        .sheet(isPresented: $showDistrictPicker) {
            BakerDistrictPickerSheet(
                districts: SriLankaDistricts.all,
                selectedDistrict: viewModel.city.isEmpty ? nil : viewModel.city,
                onSelect: { district in
                    viewModel.city = district
                    showDistrictPicker = false
                }
            )
            .presentationDetents([.medium, .large])
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
        .background(Color.cakeSurface)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let selectedCoverImage = viewModel.selectedCoverImage {
                    Image(uiImage: selectedCoverImage)
                        .resizable()
                        .scaledToFill()
                } else if let savedCover = viewModel.decodeBase64Image(viewModel.coverImageBase64) {
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
                if let selectedProfileImage = viewModel.selectedProfileImage {
                    Image(uiImage: selectedProfileImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else if let savedProfile = viewModel.decodeBase64Image(viewModel.profileImageBase64) {
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
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                        Text("Change Photo")
                            .font(.urbanistMedium(11))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.cakeBrown)
                    .clipShape(Capsule())
                }
            }

            Spacer()
        }
        .padding(14)
        .background(Color.cakeInsetSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Active/Inactive Toggle
    private var activeToggleSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Status")
                    .font(.urbanistBold(14))
                    .foregroundColor(.cakePrimaryText)
                Text("Mark yourself as active or inactive")
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeGrey)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { viewModel.isActive = true }) {
                    Text("Active")
                        .font(.urbanistMedium(13))
                        .foregroundColor(viewModel.isActive ? .white : .cakeBrown)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(viewModel.isActive ? Color(red: 0.2, green: 0.6, blue: 0.4) : Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 0.2, green: 0.6, blue: 0.4), lineWidth: viewModel.isActive ? 0 : 1)
                        )
                }

                Button(action: { viewModel.isActive = false }) {
                    Text("Inactive")
                        .font(.urbanistMedium(13))
                        .foregroundColor(!viewModel.isActive ? .white : inactiveStatusColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(!viewModel.isActive ? inactiveStatusColor : Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(inactiveStatusColor, lineWidth: !viewModel.isActive ? 0 : 1)
                        )
                }
            }
            .frame(width: 160)
        }
        .padding(14)
        .background(Color.cakeInsetSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Form Section
    private var formSection: some View {
        VStack(spacing: 16) {
            formField(label: "Name", placeholder: "Enter bakery name", text: $viewModel.bakeryName)
            readOnlyField(label: "Email Address", value: viewModel.email)
            formField(label: "Phone Number", placeholder: "+94 74 234 5436", text: $viewModel.phoneNumber)
            formField(label: "Address", placeholder: "e.g No 8, Flower Road", text: $viewModel.address)
            districtField(label: "City", selectedDistrict: $viewModel.city)

            bioField
        }
    }

    private func formField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.urbanistBold(14))
                .foregroundColor(.cakePrimaryText)

            TextField(placeholder, text: text)
                .font(.urbanistRegular(14))
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Color.cakeSurface)
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
                .foregroundColor(.cakePrimaryText)

            Text(value)
                .font(.urbanistRegular(14))
                .foregroundColor(Color(hex: "7D7D7D"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Color.cakeSurface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.black.opacity(0.35), lineWidth: 1)
                )
        }
    }

    private func districtField(label: String, selectedDistrict: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.urbanistBold(14))
                .foregroundColor(.cakePrimaryText)

            Button {
                showDistrictPicker = true
            } label: {
                HStack(spacing: 10) {
                    Text(selectedDistrict.wrappedValue.isEmpty ? "Select district" : selectedDistrict.wrappedValue)
                        .font(.urbanistRegular(14))
                        .foregroundColor(selectedDistrict.wrappedValue.isEmpty ? Color(hex: "7D7D7D") : Color(red: 0.1, green: 0.1, blue: 0.1))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.cakeBrown)
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Color.cakeSurface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.black.opacity(0.35), lineWidth: 1)
                )
            }
        }
    }
    
    private var bioField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bio")
                .font(.urbanistBold(14))
                .foregroundColor(.cakePrimaryText)
            
            TextEditor(text: $viewModel.bio)
                .font(.urbanistRegular(14))
                .frame(height: 100)
                .padding(8)
                .background(Color.cakeSurface)
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
                .foregroundColor(.cakePrimaryText)
            
            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(BakerEditProfileOptions.allCategories.enumerated()), id: \.offset) { index, category in
                    categoryButton(categoryName: category, index: index)
                }
            }
        }
    }
    
    private func categoryButton(categoryName: String, index: Int) -> some View {
        Button(action: { viewModel.toggleCategory(categoryName) }) {
            VStack(spacing: 6) {
                Text(categoryName)
                    .font(.urbanistMedium(11))
                    .foregroundColor(viewModel.selectedCategories.contains(categoryName) ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                viewModel.selectedCategories.contains(categoryName) ?
                Color.cakeBrown :
                BakerEditProfileOptions.categoryColors[index % BakerEditProfileOptions.categoryColors.count]
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        viewModel.selectedCategories.contains(categoryName) ? Color.cakeBrown : Color.clear,
                        lineWidth: 2
                    )
            )
        }
    }
    
    // MARK: - Update Button
    private var updateButton: some View {
        Button(action: {
            Task {
                await viewModel.saveProfile()
            }
        }) {
            HStack {
                if viewModel.isLoading {
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
        .disabled(viewModel.isLoading)
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
