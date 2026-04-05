import Foundation
import Combine
import FirebaseFirestore
import FirebaseStorage
import UIKit

// MARK: - ProfileViewModel
//
// Manages profile photo uploads to Firebase Storage and
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
    private let storage = Storage.storage()

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
    /// Uploads the selected photo to Firebase Storage at:
    /// gs://bucket/users/{userId}/profile/{timestamp}.jpg
    func uploadProfilePhoto() async {
        guard let photo = selectedPhoto else { return }
        guard let jpegData = photo.jpegData(compressionQuality: 0.8) else { return }

        isSaving = true
        errorMessage = nil

        let filename = "\(Date().timeIntervalSince1970).jpg"
        let path = "users/\(user.id)/profile/\(filename)"
        let ref = storage.reference().child(path)

        do {
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"

            // Upload without progress tracking (simplified)
            let _ = try await ref.putDataAsync(jpegData, metadata: metadata)
            
            // Get download URL
            let downloadURL = try await ref.downloadURL()
            user.avatarURL = downloadURL.absoluteString
            uploadProgress = 1.0

            print("DEBUG: Profile photo uploaded successfully: \(downloadURL)")
        } catch {
            errorMessage = "Failed to upload photo: \(error.localizedDescription)"
            print("ERROR uploading profile photo: \(error)")
        }

        isSaving = false
        uploadProgress = 0
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
}
