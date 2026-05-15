import Foundation
import Combine
import FirebaseFirestore
import UIKit



@MainActor
final class ProfileViewModel: ObservableObject {

    @Published var user: AppUser
    @Published var isSaving = false
    @Published var errorMessage: String?

    // Edit form state
    @Published var fullName: String = ""
    @Published var email: String = ""
    @Published var phoneNumber: String = ""
    @Published var address: String = ""
    @Published var city: String = ""
    @Published var postalCode: String = ""
    @Published var dateOfBirth: Date?

    @Published var selectedPhoto: UIImage?
    @Published var uploadProgress: Double = 0

    private let db = Firestore.firestore()

    init(user: AppUser) {
        self.user = user
        self.fullName = user.name
        self.email = user.email
        self.phoneNumber = user.phoneNumber ?? ""
        self.address = user.address ?? ""
        self.city = user.city ?? ""
        self.postalCode = user.postalCode ?? ""
        self.dateOfBirth = user.dateOfBirth
    }

    // MARK: - Upload Profile Photo
    
    func uploadProfilePhoto() async {
        guard let photo = selectedPhoto else { return }
        guard let jpegData = photo.jpegData(compressionQuality: 0.3) else { return }

        let sizeInMB = Double(jpegData.count) / (1024 * 1024)
        guard sizeInMB < 0.5 else {
            errorMessage = "Image too large. Please choose a smaller image."
            return
        }

        isSaving = true
        errorMessage = nil

        let base64String = jpegData.base64EncodedString()

        UserDefaults.standard.set(base64String, forKey: "profileAvatar_\(user.id)")
        user.avatarURL = nil

        do {
            try await db.collection("users").document(user.id).setData([
                "profileImageBase64": base64String,
                "avatarBase64": base64String,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            errorMessage = "Profile photo saved on this device, but could not sync for other users."
            print("ERROR syncing profile photo to Firestore: \(error.localizedDescription)")
        }

        uploadProgress = 1.0
        isSaving = false
        uploadProgress = 0

        NotificationCenter.default.post(name: NSNotification.Name("profileAvatarUpdated"), object: nil)
    }

    // MARK: - Update Profile
    
    func updateProfile(
        name: String,
        phone: String,
        address: String,
        city: String,
        postalCode: String,
        dob: Date?
    ) async {
        isSaving = true
        errorMessage = nil

        do {
            let resolvedCity = SriLankaDistricts.canonical(city)
            let resolvedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

            user.name = name
            user.phoneNumber = phone.isEmpty ? nil : phone
            user.address = resolvedAddress.isEmpty ? nil : resolvedAddress
            user.city = resolvedCity
            user.postalCode = postalCode.isEmpty ? nil : postalCode
            user.dateOfBirth = dob

            if selectedPhoto != nil && user.avatarURL == nil {
                await uploadProfilePhoto()
            }

            try await db.collection("users").document(user.id).setData(from: user, merge: true)
            selectedPhoto = nil
            await NotificationManager.scheduleLocalNotification(
                title: "Profile Updated",
                body: "Profile updated successfully!",
                identifier: "customer-profile-updated-\(UUID().uuidString)"
            )
        } catch {
            errorMessage = "Failed to update profile: \(error.localizedDescription)"
            print("ERROR updating profile: \(error)")
        }

        isSaving = false
    }

    // MARK: - Fetch Profile
    
    func fetchProfile() async {
        do {
            let snapshot = try await db.collection("users").document(user.id).getDocument()
            do {
                let updatedUser = try snapshot.data(as: AppUser.self)
                self.user = updatedUser
                self.fullName = updatedUser.name
                self.email = updatedUser.email
                self.phoneNumber = updatedUser.phoneNumber ?? ""
                self.address = updatedUser.address ?? ""
                self.city = updatedUser.city ?? ""
                self.postalCode = updatedUser.postalCode ?? ""
                self.dateOfBirth = updatedUser.dateOfBirth
            } catch {
                print("DEBUG: Could not decode AppUser from snapshot")
            }
        } catch {
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
            print("ERROR fetching profile: \(error)")
        }
    }

    // MARK: - Load Avatar from UserDefaults
    
    func loadAvatarFromUserDefaults() -> UIImage? {
        guard let base64String = UserDefaults.standard.string(forKey: "profileAvatar_\(user.id)") else {
            return nil
        }
        guard let imageData = Data(base64Encoded: base64String) else { return nil }
        return UIImage(data: imageData)
    }
}
