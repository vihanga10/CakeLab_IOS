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
            let result = try await auth.signIn(withEmail: email, password: password)
            return try await fetchUser(uid: result.user.uid)
        } catch let error as NSError {
            throw AuthError.networkError(error.localizedDescription)
        }
    }

    // MARK: Sign Up
    func signUp(email: String, password: String, role: UserRole) async throws -> AppUser {
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
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
            try await saveUser(user)
            return user
        } catch let error as NSError {
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
        try await db.collection("users").document(user.id).setData(data)
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
