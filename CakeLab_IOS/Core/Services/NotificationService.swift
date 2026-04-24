import Foundation
import Combine

// MARK: - Notification Service
class NotificationService: ObservableObject {
    @Published var notifications: [AppNotification] = []
    
    private let userDefaults = UserDefaults.standard
    private let notificationKey = "app_notifications"
    
    init() {
        loadNotifications()
    }
    
    // MARK: - Save Notification
    func saveNotification(_ notification: AppNotification) {
        notifications.insert(notification, at: 0) // Add to top
        persistNotifications()
    }
    
    // MARK: - Load Notifications
    func loadNotifications() {
        if let data = userDefaults.data(forKey: notificationKey) {
            do {
                let decoded = try JSONDecoder().decode([AppNotification].self, from: data)
                // Filter to only show last 7 days
                self.notifications = decoded.filter { $0.isWithin7Days }.sorted { $0.timestamp > $1.timestamp }
            } catch {
                print("Error decoding notifications: \(error)")
                self.notifications = []
            }
        }
    }
    
    // MARK: - Persist Notifications
    private func persistNotifications() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(notifications)
            userDefaults.set(data, forKey: notificationKey)
        } catch {
            print("Error persisting notifications: \(error)")
        }
    }
    
    // MARK: - Mark as Read
    func markAsRead(_ notification: AppNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            var updated = notifications[index]
            updated.isRead = true
            notifications[index] = updated
            persistNotifications()
        }
    }
    
    // MARK: - Delete Notification
    func deleteNotification(_ notification: AppNotification) {
        notifications.removeAll { $0.id == notification.id }
        persistNotifications()
    }
    
    // MARK: - Delete All Notifications
    func deleteAllNotifications() {
        notifications.removeAll()
        persistNotifications()
    }
    
    // MARK: - Get Unread Count
    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }
    
    // MARK: - Get Notifications for User Type
    func getNotifications(for userType: String) -> [AppNotification] {
        notifications.filter { $0.userType == userType }
    }
}
