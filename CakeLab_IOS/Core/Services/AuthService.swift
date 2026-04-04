import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Auth Service (Firebase implementation)
final class AuthService: AuthServiceProtocol {

    private let auth = Auth.auth()
    private let db   = Firestore.firestore()

    var currentUserID: String? { auth.currentUser?.uid }

    // MARK: Sign In
    func signIn(email: String, password: String) async throws -> AppUser {
        do {
            print("🔐 DEBUG: Starting sign-in for \(email)")
            let result = try await auth.signIn(withEmail: email, password: password)
            print("✅ DEBUG: Firebase Auth sign-in successful: \(result.user.uid)")
            return try await fetchUser(uid: result.user.uid)
        } catch let error as NSError {
            print("❌ ERROR Domain: \(error.domain)")
            print("❌ ERROR Code: \(error.code)")
            print("❌ ERROR Message: \(error.localizedDescription)")
            throw AuthError.networkError(error.localizedDescription)
        }
    }

    // MARK: Sign Up
    func signUp(email: String, password: String, role: UserRole) async throws -> AppUser {
        do {
            print("🔐 DEBUG: Starting sign-up for \(email)")
            let result = try await auth.createUser(withEmail: email, password: password)
            print("✅ DEBUG: Firebase Auth user created: \(result.user.uid)")
            
            let uid = result.user.uid
            let user = AppUser(
                id: uid,
                email: email,
                name: "",
                role: role,
                avatarURL: nil,
                fcmToken: nil,
                createdAt: Date()
            )
            
            print("💾 DEBUG: Saving user profile to Firestore...")
            try await saveUser(user)
            print("✅ DEBUG: User profile saved successfully")
            return user
        } catch let error as NSError {
            print("❌ ERROR Domain: \(error.domain)")
            print("❌ ERROR Code: \(error.code)")
            print("❌ ERROR Message: \(error.localizedDescription)")
            print("❌ FULL ERROR: \(error)")
            throw AuthError.networkError(error.localizedDescription)
        }
    }

    // MARK: Password Reset
    func sendPasswordReset(email: String) async throws {
        do {
            try await auth.sendPasswordReset(withEmail: email)
        } catch let error as NSError {
            throw AuthError.networkError(error.localizedDescription)
        }
    }

    // MARK: OTP Management
    func saveOTP(email: String, otp: String) async throws {
        do {
            print("💾 DEBUG: Saving OTP to Firestore for \(email)")
            let otpData: [String: Any] = [
                "email": email,
                "otp": otp,
                "createdAt": Timestamp(date: Date()),
                "expiresAt": Timestamp(date: Date().addingTimeInterval(600))  // 10 minutes expiry
            ]
            
            // Save to otps collection with email as document ID
            try await db.collection("otps").document(email).setData(otpData, merge: true)
            print("✅ DEBUG: OTP saved successfully for \(email)")
        } catch let error as NSError {
            print("❌ OTP SAVE ERROR Domain: \(error.domain)")
            print("❌ OTP SAVE ERROR Code: \(error.code)")
            print("❌ OTP SAVE ERROR Message: \(error.localizedDescription)")
            throw AuthError.networkError("Failed to save OTP: \(error.localizedDescription)")
        }
    }

    func verifyOTP(email: String, userOTP: String) async throws -> Bool {
        do {
            print("🔍 DEBUG: Verifying OTP for \(email)")
            let doc = try await db.collection("otps").document(email).getDocument()
            
            guard let data = doc.data() else {
                print("❌ DEBUG: No OTP record found for \(email)")
                throw AuthError.unknown("OTP not found. Please request a new one.")
            }
            
            let savedOTP = data["otp"] as? String ?? ""
            let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue() ?? Date()
            
            // Check if OTP is expired
            if Date() > expiresAt {
                print("❌ DEBUG: OTP expired for \(email)")
                throw AuthError.unknown("OTP has expired. Please request a new one.")
            }
            
            // Check if OTP matches
            let isValid = savedOTP == userOTP
            if isValid {
                print("✅ DEBUG: OTP verification successful for \(email)")
                // Delete the OTP after successful verification
                try await db.collection("otps").document(email).delete()
            } else {
                print("❌ DEBUG: OTP mismatch - saved: \(savedOTP), provided: \(userOTP)")
            }
            
            return isValid
        } catch let error as NSError {
            print("❌ OTP VERIFY ERROR Domain: \(error.domain)")
            print("❌ OTP VERIFY ERROR Code: \(error.code)")
            print("❌ OTP VERIFY ERROR Message: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: Sign Out
    func signOut() throws {
        try auth.signOut()
    }

    // MARK: - Private helpers

    private func fetchUser(uid: String) async throws -> AppUser {
        let doc = try await db.collection("users").document(uid).getDocument()
        guard let data = doc.data() else {
            throw AuthError.unknown("User profile not found.")
        }
        return try decodeUser(from: data, uid: uid)
    }

    private func saveUser(_ user: AppUser) async throws {
        let data: [String: Any] = [
            "uid":       user.id,
            "email":     user.email,
            "name":      user.name,
            "role":      user.role.rawValue,
            "createdAt": Timestamp(date: user.createdAt)
        ]
        do {
            try await db.collection("users").document(user.id).setData(data)
            print("✅ DEBUG: Firestore write successful for user \(user.id)")
        } catch let error as NSError {
            print("❌ FIRESTORE ERROR Domain: \(error.domain)")
            print("❌ FIRESTORE ERROR Code: \(error.code)")
            print("❌ FIRESTORE ERROR Message: \(error.localizedDescription)")
            print("❌ FIRESTORE FULL ERROR: \(error)")
            throw error
        }
    }

    private func decodeUser(from data: [String: Any], uid: String) throws -> AppUser {
        let email     = data["email"] as? String ?? ""
        let name      = data["name"]  as? String ?? ""
        let roleRaw   = data["role"]  as? String ?? "customer"
        let role      = UserRole(rawValue: roleRaw) ?? .customer
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        return AppUser(
            id: uid,
            email: email,
            name: name,
            role: role,
            avatarURL: data["avatarURL"] as? String,
            fcmToken:  data["fcmToken"]  as? String,
            createdAt: createdAt
        )
    }
}
