import Foundation
import Combine
import SwiftUI
import PhotosUI
import FirebaseFirestore
import UIKit

@MainActor
final class BakerEditProfileViewModel: ObservableObject {
    let user: AppUser

    @Published var isActive = true
    @Published var bakeryName = ""
    @Published var email = ""
    @Published var phoneNumber = ""
    @Published var address = ""
    @Published var city = ""
    @Published var bio = ""
    @Published var selectedCategories: [String] = []
    @Published var selectedCoverImage: UIImage?
    @Published var selectedProfileImage: UIImage?
    @Published var coverImageBase64 = ""
    @Published var profileImageBase64 = ""
    @Published var isLoading = false
    @Published var showSuccessMessage = false
    @Published var errorMessage = ""

    init(user: AppUser) {
        self.user = user
    }

    func loadExistingData() async {
        let db = Firestore.firestore()
        bakeryName = user.name
        email = user.email
        phoneNumber = user.phoneNumber ?? ""
        address = user.address ?? ""
        city = SriLankaDistricts.canonical(user.city) ?? (user.city ?? "")

        do {
            let artisanSnapshot = try await loadArtisanDocument(db: db, userID: user.id)
            if let data = artisanSnapshot.data() {
                bakeryName = data["shopName"] as? String ?? user.name
                email = user.email
                phoneNumber = data["phoneNumber"] as? String ?? ""
                address = data["address"] as? String ?? (user.address ?? "")
                city = SriLankaDistricts.canonical(data["city"] as? String) ?? (user.city ?? "")
                bio = data["about"] as? String ?? ""
                selectedCategories = data["specialties"] as? [String] ?? []
                isActive = data["isOnline"] as? Bool ?? true
                coverImageBase64 = data["coverImageBase64"] as? String ?? ""
                profileImageBase64 = data["profileImageBase64"] as? String ?? ""
            }
        } catch {
            print("Error loading profile: \(error.localizedDescription)")
        }
    }

    func updateCoverImage(from item: PhotosPickerItem?) async {
        guard let data = try? await item?.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        selectedCoverImage = image
        coverImageBase64 = encodeImageToBase64(image)
    }

    func updateProfileImage(from item: PhotosPickerItem?) async {
        guard let data = try? await item?.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        selectedProfileImage = image
        profileImageBase64 = encodeImageToBase64(image)
    }

    func toggleCategory(_ categoryName: String) {
        if selectedCategories.contains(categoryName) {
            selectedCategories.removeAll { $0 == categoryName }
        } else {
            selectedCategories.append(categoryName)
        }
    }

    func decodeBase64Image(_ rawBase64: String) -> UIImage? {
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

    func saveProfile() async {
        isLoading = true
        defer { isLoading = false }

        let db = Firestore.firestore()
        let resolvedCity = SriLankaDistricts.canonical(city)
        let resolvedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedLocation = SriLankaDistricts.displayLocation(address: resolvedAddress, city: resolvedCity)

        let profileData: [String: Any] = [
            "shopName": bakeryName,
            "name": bakeryName,
            "email": user.email,
            "phoneNumber": phoneNumber,
            "address": resolvedAddress,
            "city": resolvedCity as Any,
            "location": resolvedLocation,
            "about": bio,
            "specialties": selectedCategories,
            "isOnline": isActive,
            "coverImageBase64": coverImageBase64,
            "profileImageBase64": profileImageBase64,
            "updatedAt": Timestamp(date: Date())
        ]

        do {
            try await db.collection("artisans").document(user.id).setData(profileData, merge: true)
            try await db.collection("users").document(user.id).setData([
                "name": bakeryName,
                "phoneNumber": phoneNumber,
                "address": resolvedAddress,
                "city": resolvedCity as Any,
                "updatedAt": Timestamp(date: Date())
            ], merge: true)
            print("Profile updated successfully!")
            NotificationCenter.default.post(name: Notification.Name("bakerProfileDidChange"), object: nil)
            showSuccessMessage = true
        } catch {
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
            print("Error saving profile: \(error.localizedDescription)")
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
}
