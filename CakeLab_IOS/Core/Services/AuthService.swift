import Foundation
import AuthenticationServices //apple
import CryptoKit //apple
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn
import Security  //apple
import UIKit

// MARK: - Auth Service (Firebase implementation)
final class AuthService: AuthServiceProtocol {

    private let auth = Auth.auth()
    private let db   = Firestore.firestore()

    var currentUserID: String? { auth.currentUser?.uid }

    // MARK: Sign In
    func signIn(email: String, password: String) async throws -> AppUser {
        do {
            print("DEBUG: Starting sign-in for \(email)")
            let result = try await auth.signIn(withEmail: email, password: password)
            print("DEBUG: Firebase Auth sign-in successful: \(result.user.uid)")
            return try await fetchUser(uid: result.user.uid)
        } catch let error as NSError {
            print("ERROR Domain: \(error.domain)")
            print("ERROR Code: \(error.code)")
            print("ERROR Message: \(error.localizedDescription)")
            throw AuthError.networkError(error.localizedDescription)
        }
    }

    // MARK: Sign Up
    func signUp(email: String, password: String, role: UserRole) async throws -> AppUser {
        do {
            print("DEBUG: Starting sign-up for \(email)")
            let result = try await auth.createUser(withEmail: email, password: password)
            print("DEBUG: Firebase Auth user created: \(result.user.uid)")
            
            let uid = result.user.uid
            let user = AppUser(
                id: uid,
                email: email,
                name: "",
                role: role,
                avatarURL: nil,
                fcmToken: nil,
                createdAt: Date(),
                phoneNumber: nil,
                address: nil,
                city: nil,
                postalCode: nil,
                dateOfBirth: nil
            )
            
            print("DEBUG: Saving user profile to Firestore...")
            try await saveUser(user)
            print("DEBUG: User profile saved successfully")
            return user
        } catch let error as NSError {
            print("ERROR Domain: \(error.domain)")
            print("ERROR Code: \(error.code)")
            print("ERROR Message: \(error.localizedDescription)")
            print("FULL ERROR: \(error)")
            throw AuthError.networkError(error.localizedDescription)
        }
    }

    // MARK: Google Sign Up
    func signUpWithGoogle(role: UserRole, presentingViewController: UIViewController) async throws -> AppUser {
        do {
            print("DEBUG: Starting Google sign-up")
            let result = try await signInToFirebaseWithGoogle(presentingViewController: presentingViewController)
            let uid = result.user.uid

            if result.additionalUserInfo?.isNewUser == false,
               (try? await fetchUser(uid: uid)) != nil {
                try? auth.signOut()
                GIDSignIn.sharedInstance.signOut()
                throw AuthError.unknown("Account already exists. Please sign in.")
            }

            let email = result.user.email ?? ""
            guard !email.isEmpty else {
                throw AuthError.unknown("Google account did not provide an email address.")
            }

            let user = AppUser(
                id: uid,
                email: email,
                name: result.user.displayName ?? "",
                role: role,
                avatarURL: result.user.photoURL?.absoluteString,
                fcmToken: nil,
                createdAt: Date(),
                phoneNumber: nil,
                address: nil,
                city: nil,
                postalCode: nil,
                dateOfBirth: nil
            )

            try await saveUser(user)
            print("DEBUG: Google user profile saved successfully")
            return user
        } catch let error as AuthError {
            throw error
        } catch let error as NSError {
            print("GOOGLE SIGN-UP ERROR Domain: \(error.domain)")
            print("GOOGLE SIGN-UP ERROR Code: \(error.code)")
            print("GOOGLE SIGN-UP ERROR Message: \(error.localizedDescription)")
            throw AuthError.networkError(error.localizedDescription)
        }
    }

    // MARK: Google Sign In
    func signInWithGoogle(presentingViewController: UIViewController) async throws -> AppUser {
        do {
            print("DEBUG: Starting Google sign-in")
            let result = try await signInToFirebaseWithGoogle(presentingViewController: presentingViewController)
            return try await fetchUser(uid: result.user.uid)
        } catch let error as AuthError {
            throw error
        } catch let error as NSError {
            print("GOOGLE SIGN-IN ERROR Domain: \(error.domain)")
            print("GOOGLE SIGN-IN ERROR Code: \(error.code)")
            print("GOOGLE SIGN-IN ERROR Message: \(error.localizedDescription)")
            throw AuthError.networkError(error.localizedDescription)
        }
    }

    // MARK: Apple Sign Up
    func signUpWithApple(role: UserRole, presentationAnchor: ASPresentationAnchor) async throws -> AppUser {
        do {
            print("DEBUG: Starting Apple sign-up")
            let appleResult = try await signInToFirebaseWithApple(presentationAnchor: presentationAnchor)
            let result = appleResult.authResult
            let uid = result.user.uid

            if result.additionalUserInfo?.isNewUser == false,
               (try? await fetchUser(uid: uid)) != nil {
                try? auth.signOut()
                throw AuthError.unknown("Account already exists. Please sign in.")
            }

            let email = appleResult.appleEmail ?? result.user.email ?? ""
            guard !email.isEmpty else {
                throw AuthError.unknown("Apple account did not provide an email address.")
            }

            let fullName = appleResult.appleFullName
            let displayName = result.user.displayName
                ?? PersonNameComponentsFormatter().string(from: fullName ?? PersonNameComponents())

            let user = AppUser(
                id: uid,
                email: email,
                name: displayName,
                role: role,
                avatarURL: nil,
                fcmToken: nil,
                createdAt: Date(),
                phoneNumber: nil,
                address: nil,
                city: nil,
                postalCode: nil,
                dateOfBirth: nil
            )

            try await saveUser(user)
            print("DEBUG: Apple user profile saved successfully")
            return user
        } catch let error as AuthError {
            throw error
        } catch let error as NSError {
            print("APPLE SIGN-UP ERROR Domain: \(error.domain)")
            print("APPLE SIGN-UP ERROR Code: \(error.code)")
            print("APPLE SIGN-UP ERROR Message: \(error.localizedDescription)")
            throw AuthError.networkError(error.localizedDescription)
        }
    }

    // MARK: Apple Sign In
    func signInWithApple(presentationAnchor: ASPresentationAnchor) async throws -> AppUser {
        do {
            print("DEBUG: Starting Apple sign-in")
            let appleResult = try await signInToFirebaseWithApple(presentationAnchor: presentationAnchor)
            return try await fetchUser(uid: appleResult.authResult.user.uid)
        } catch let error as AuthError {
            throw error
        } catch let error as NSError {
            print("APPLE SIGN-IN ERROR Domain: \(error.domain)")
            print("APPLE SIGN-IN ERROR Code: \(error.code)")
            print("APPLE SIGN-IN ERROR Message: \(error.localizedDescription)")
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
            print("DEBUG: Saving OTP to Firestore for \(email)")
            let otpData: [String: Any] = [
                "email": email,
                "otp": otp,
                "createdAt": Timestamp(date: Date()),
                "expiresAt": Timestamp(date: Date().addingTimeInterval(600))  // 10 minutes expiry
            ]
            
            // Save to otps collection with email as document ID
            try await db.collection("otps").document(email).setData(otpData, merge: true)
            print("DEBUG: OTP saved successfully for \(email)")
        } catch let error as NSError {
            print("OTP SAVE ERROR Domain: \(error.domain)")
            print("OTP SAVE ERROR Code: \(error.code)")
            print("OTP SAVE ERROR Message: \(error.localizedDescription)")
            throw AuthError.networkError("Failed to save OTP: \(error.localizedDescription)")
        }
    }

    func verifyOTP(email: String, userOTP: String) async throws -> Bool {
        do {
            print("🔍 DEBUG: Verifying OTP for \(email)")
            let doc = try await db.collection("otps").document(email).getDocument()
            
            guard let data = doc.data() else {
                print("DEBUG: No OTP record found for \(email)")
                throw AuthError.unknown("OTP not found. Please request a new one.")
            }
            
            let savedOTP = data["otp"] as? String ?? ""
            let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue() ?? Date()
            
            // Check if OTP is expired
            if Date() > expiresAt {
                print("DEBUG: OTP expired for \(email)")
                throw AuthError.unknown("OTP has expired. Please request a new one.")
            }
            
            // Check if OTP matches
            let isValid = savedOTP == userOTP
            if isValid {
                print("DEBUG: OTP verification successful for \(email)")
                // Delete the OTP after successful verification
                try await db.collection("otps").document(email).delete()
            } else {
                print("DEBUG: OTP mismatch - saved: \(savedOTP), provided: \(userOTP)")
            }
            
            return isValid
        } catch let error as NSError {
            print("OTP VERIFY ERROR Domain: \(error.domain)")
            print("OTP VERIFY ERROR Code: \(error.code)")
            print("OTP VERIFY ERROR Message: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: Sign Out
    func signOut() throws {
        try auth.signOut()
    }

    // MARK: - Re-authenticate User
    func reauthenticate(email: String, password: String) async throws {
        do {
            guard let user = auth.currentUser else {
                throw AuthError.unknown("No user is currently signed in.")
            }
            
            print("🔐 DEBUG: Re-authenticating user: \(user.uid)")
            
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await user.reauthenticate(with: credential)
            
            print("✅ DEBUG: Re-authentication successful for user: \(user.uid)")
        } catch let error as NSError {
            print("RE-AUTH ERROR Domain: \(error.domain)")
            print("RE-AUTH ERROR Code: \(error.code)")
            print("RE-AUTH ERROR Message: \(error.localizedDescription)")
            throw AuthError.unknown(error.localizedDescription)
        }
    }

    // MARK: - Update Password
    func updatePassword(newPassword: String, currentEmail: String, currentPassword: String) async throws {
        do {
            guard let user = auth.currentUser else {
                throw AuthError.unknown("No user is currently signed in.")
            }
            
            print("🔐 DEBUG: Current user email: \(user.email ?? "nil")")
            print("🔐 DEBUG: Provided email for re-auth: \(currentEmail)")
            print("🔐 DEBUG: Re-authenticating before password update for user: \(user.uid)")
            
            // First, re-authenticate the user
            try await reauthenticate(email: currentEmail, password: currentPassword)
            
            print("🔐 DEBUG: Re-auth completed, refreshing user session...")
            // Refresh the user to ensure the session is updated
            try await user.reload()
            
            print("🔐 DEBUG: Updating password for user: \(user.uid)")
            
            try await user.updatePassword(to: newPassword)
            
            print("✅ DEBUG: Password updated successfully for user: \(user.uid)")
        } catch let error as NSError {
            print("PASSWORD UPDATE ERROR Domain: \(error.domain)")
            print("PASSWORD UPDATE ERROR Code: \(error.code)")
            print("PASSWORD UPDATE ERROR Message: \(error.localizedDescription)")
            throw AuthError.unknown(error.localizedDescription)
        }
    }

    // MARK: - Fetch User by Email
    func fetchUserByEmail(_ email: String) async throws -> AppUser {
        do {
            print("🔍 DEBUG: Fetching user by email: \(email)")
            
            // Query users collection where email matches
            let query = db.collection("users").whereField("email", isEqualTo: email)
            let snapshot = try await query.getDocuments()
            
            guard let document = snapshot.documents.first else {
                print("DEBUG: No user found with email: \(email)")
                throw AuthError.unknown("User not found. Please check your email or sign up.")
            }
            
            let data = document.data()
            let uid = document.documentID
            let user = try decodeUser(from: data, uid: uid)
            
            print("DEBUG: User found - Email: \(user.email), Role: \(user.role.rawValue)")
            return user
        } catch let error as NSError {
            print("FETCH USER ERROR Domain: \(error.domain)")
            print("FETCH USER ERROR Code: \(error.code)")
            print("FETCH USER ERROR Message: \(error.localizedDescription)")
            throw error
        }
    }

    private func fetchUser(uid: String) async throws -> AppUser {
        let doc = try await db.collection("users").document(uid).getDocument()
        guard let data = doc.data() else {
            throw AuthError.unknown("User profile not found.")
        }
        return try decodeUser(from: data, uid: uid)
    }

    @MainActor
    private func signInToFirebaseWithGoogle(presentingViewController: UIViewController) async throws -> AuthDataResult {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.unknown("Missing Google client ID.")
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.signOut()

        let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
        let user = signInResult.user

        guard let idToken = user.idToken?.tokenString else {
            throw AuthError.unknown("Missing Google ID token.")
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: user.accessToken.tokenString
        )

        return try await auth.signIn(with: credential)
    }
//apple
    @MainActor
    private func signInToFirebaseWithApple(presentationAnchor: ASPresentationAnchor) async throws -> AppleFirebaseAuthResult {
        let rawNonce = try randomNonceString()
        let coordinator = AppleSignInCoordinator(presentationAnchor: presentationAnchor)
        let appleCredential = try await coordinator.signIn(hashedNonce: sha256(rawNonce))

        guard let identityToken = appleCredential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.unknown("Missing Apple identity token.")
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: rawNonce,
            fullName: appleCredential.fullName
        )
        let authResult = try await auth.signIn(with: credential)

        return AppleFirebaseAuthResult(
            authResult: authResult,
            appleEmail: appleCredential.email,
            appleFullName: appleCredential.fullName
        )
    }

    private func randomNonceString(length: Int = 32) throws -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            if errorCode != errSecSuccess {
                throw AuthError.unknown("Unable to generate secure Apple sign-in nonce.")
            }

            randomBytes.forEach { randomByte in
                if remainingLength == 0 {
                    return
                }

                if randomByte < charset.count {
                    result.append(charset[Int(randomByte)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    } //apple

    private func saveUser(_ user: AppUser) async throws {
        do {
            // Use Codable to encode all user fields including profile fields
            try await db.collection("users").document(user.id).setData(from: user)
            print("DEBUG: Firestore write successful for user \(user.id)")
        } catch let error as NSError {
            print("FIRESTORE ERROR Domain: \(error.domain)")
            print("FIRESTORE ERROR Code: \(error.code)")
            print("FIRESTORE ERROR Message: \(error.localizedDescription)")
            print("FIRESTORE FULL ERROR: \(error)")
            throw error
        }
    }

    private func decodeUser(from data: [String: Any], uid: String) throws -> AppUser {
        let email     = data["email"] as? String ?? ""
        let name      = data["name"]  as? String ?? ""
        let roleRaw   = data["role"]  as? String ?? "customer"
        let role      = UserRole(rawValue: roleRaw) ?? .customer
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        
        // Profile fields
        let phoneNumber = data["phoneNumber"] as? String
        let address = data["address"] as? String
        let city = data["city"] as? String
        let postalCode = data["postalCode"] as? String
        let dateOfBirth = (data["dateOfBirth"] as? Timestamp)?.dateValue()
        
        return AppUser(
            id: uid,
            email: email,
            name: name,
            role: role,
            avatarURL: data["avatarURL"] as? String,
            fcmToken:  data["fcmToken"]  as? String,
            createdAt: createdAt,
            phoneNumber: phoneNumber,
            address: address,
            city: city,
            postalCode: postalCode,
            dateOfBirth: dateOfBirth
        )
    }
}

private struct AppleFirebaseAuthResult {
    let authResult: AuthDataResult
    let appleEmail: String?
    let appleFullName: PersonNameComponents?
}

private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let presentationAnchor: ASPresentationAnchor
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    private var controller: ASAuthorizationController?

    init(presentationAnchor: ASPresentationAnchor) {
        self.presentationAnchor = presentationAnchor
    }

    func signIn(hashedNonce: String) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce

            self.controller = ASAuthorizationController(authorizationRequests: [request])
            self.controller?.delegate = self
            self.controller?.presentationContextProvider = self
            self.controller?.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchor
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: AuthError.unknown("Invalid Apple authorization response."))
            continuation = nil
            self.controller = nil
            return
        }

        continuation?.resume(returning: credential)
        continuation = nil
        self.controller = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
        self.controller = nil
    }
}
