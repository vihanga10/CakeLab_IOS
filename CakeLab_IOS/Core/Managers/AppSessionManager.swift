import Foundation
import FirebaseAuth

extension Notification.Name {
    static let appUserDidSignOut = Notification.Name("appUserDidSignOut")
    static let appUserDidAuthenticate = Notification.Name("appUserDidAuthenticate")
}

final class AppSessionManager {
    static let shared = AppSessionManager()

    private init() {}

    func registerAuthenticatedSession(for user: AppUser) {
        NotificationCenter.default.post(name: .appUserDidAuthenticate, object: user)
    }

    func clearLocalSessionData() {
        WidgetDataSyncManager.shared.clearWidgetData()
    }

    func discardAuthenticatedSession() {
        if Auth.auth().currentUser != nil {
            try? Auth.auth().signOut()
        }
        clearLocalSessionData()
    }

    func signOutCompletely() throws {
        try Auth.auth().signOut()
        clearLocalSessionData()
        NotificationCenter.default.post(name: .appUserDidSignOut, object: nil)
    }
}
