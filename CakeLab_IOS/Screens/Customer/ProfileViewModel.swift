import Foundation
import Combine
import FirebaseFirestore
import UIKit

// MARK: - ProfileViewModel
//
// Manages profile photo storage as Base64 in Firestore and
// profile updates to Firestore.

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
        // Initialize form fields from user data
        self.fullName = user.name
        self.email = user.email
        self.phoneNumber = user.phoneNumber ?? ""
        self.address = user.address ?? ""
        self.city = user.city ?? ""
        self.postalCode = user.postalCode ?? ""
        self.dateOfBirth = user.dateOfBirth
    }
    
    // MARK: - Upload Profile Photo
    /// Converts the selected photo to Base64 (compressed) and stores it locally in UserDefaults
    /// This avoids Firestore size limits and reduces storage costs
    func uploadProfilePhoto() async {
        guard let photo = selectedPhoto else { return }
        // Compress aggressively: 0.3 quality to keep size manageable
        guard let jpegData = photo.jpegData(compressionQuality: 0.3) else { return }
        
        // Check size before storing
        let sizeInMB = Double(jpegData.count) / (1024 * 1024)
        guard sizeInMB < 0.5 else {
            errorMessage = "Image too large. Please choose a smaller image."
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        // Convert JPEG data to Base64 string
        let base64String = jpegData.base64EncodedString()
        
        // Store in UserDefaults (local storage) instead of Firestore
        UserDefaults.standard.set(base64String, forKey: "profileAvatar_\(user.id)")
        user.avatarURL = nil // Don't store in Firestore
        uploadProgress = 1.0
        
        print("DEBUG: Profile photo stored locally as Base64 (\(String(format: "%.2f", sizeInMB))MB)")
        
        isSaving = false
        uploadProgress = 0
        
        // Notify listeners that avatar has been updated
        NotificationCenter.default.post(name: NSNotification.Name("profileAvatarUpdated"), object: nil)
    }
    
    // MARK: - Update Profile
    /// Updates all user profile fields in Firestore and locally with provided form data
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
            // Update local user object with form data
            user.name = name
            user.phoneNumber = phone.isEmpty ? nil : phone
            user.address = address.isEmpty ? nil : address
            user.city = city.isEmpty ? nil : city
            user.postalCode = postalCode.isEmpty ? nil : postalCode
            user.dateOfBirth = dob
            
            // Upload photo if selected and not yet uploaded
            if selectedPhoto != nil && user.avatarURL == nil {
                await uploadProfilePhoto()
            }
            
            // Save to Firestore
            try await db.collection("users").document(user.id).setData(from: user, merge: true)
            
            print("DEBUG: Profile updated successfully")
            selectedPhoto = nil
        } catch {
            errorMessage = "Failed to update profile: \(error.localizedDescription)"
            print("ERROR updating profile: \(error)")
        }
        
        isSaving = false
    }
    
    // MARK: - Fetch Profile
    /// Loads the most up-to-date profile from Firestore
    func fetchProfile() async {
        do {
            let snapshot = try await db.collection("users").document(user.id).getDocument()
            do {
                let updatedUser = try snapshot.data(as: AppUser.self)
                self.user = updatedUser
                // Sync form fields
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
    /// Retrieves the locally stored avatar image from UserDefaults
    func loadAvatarFromUserDefaults() -> UIImage? {
        guard let base64String = UserDefaults.standard.string(forKey: "profileAvatar_\(user.id)") else {
            return nil
        }
        guard let imageData = Data(base64Encoded: base64String) else {
            return nil
        }
        return UIImage(data: imageData)
    }
}
