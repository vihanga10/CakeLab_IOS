import Foundation

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case invalidEmail
    case emptyPassword
    case passwordTooShort
    case passwordMismatch
    case roleNotSelected
    case networkError(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:          return "Please enter a valid email address."
        case .emptyPassword:         return "Please enter your password."
        case .passwordTooShort:      return "Password must be at least 6 characters."
        case .passwordMismatch:      return "Passwords do not match."
        case .roleNotSelected:       return "Please select who you are."
        case .networkError(let msg): return msg
        case .unknown(let msg):      return msg
        }
    }
}

// MARK: - Auth Service Protocol (enables mock injection for unit tests)
protocol AuthServiceProtocol {
    /// Sign in with email and password. Returns the authenticated AppUser.
    func signIn(email: String, password: String) async throws -> AppUser
    /// Create a new account with given role. Returns the created AppUser.
    func signUp(email: String, password: String, role: UserRole) async throws -> AppUser
    /// Send a password reset email.
    func sendPasswordReset(email: String) async throws
    /// Save OTP for password reset to Firestore.
    func saveOTP(email: String, otp: String) async throws
    /// Verify the OTP provided by user for password reset.
    func verifyOTP(email: String, userOTP: String) async throws -> Bool
    /// Fetch user profile by email from Firestore.
    func fetchUserByEmail(_ email: String) async throws -> AppUser
    /// Sign out the current user.
    func signOut() throws
    /// Currently signed-in user's UID, nil if not authenticated.
    var currentUserID: String? { get }
}
