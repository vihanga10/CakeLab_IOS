import Foundation

// MARK: - User Role
enum UserRole: String, Codable {
    case customer = "customer"
    case baker    = "baker"
}

// MARK: - App User Model
struct AppUser: Codable, Identifiable, Sendable {
    let id: String          // Firebase UID
    var email: String
    var name: String
    var role: UserRole
    var avatarURL: String?
    var fcmToken: String?
    var createdAt: Date

    // MARK: - Firestore field keys
    enum CodingKeys: String, CodingKey {
        case id          = "uid"
        case email
        case name
        case role
        case avatarURL
        case fcmToken
        case createdAt
    }
}

// MARK: - Mock for testing
extension AppUser {
    static var mock: AppUser {
        AppUser(
            id: "mock-uid-001",
            email: "test@cakelab.com",
            name: "Test User",
            role: .customer,
            avatarURL: nil,
            fcmToken: nil,
            createdAt: Date()
        )
    }

    static var mockBaker: AppUser {
        AppUser(
            id: "mock-uid-002",
            email: "baker@cakelab.com",
            name: "Baker User",
            role: .baker,
            avatarURL: nil,
            fcmToken: nil,
            createdAt: Date()
        )
    }
}
