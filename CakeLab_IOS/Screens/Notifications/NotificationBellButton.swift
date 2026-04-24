import SwiftUI

// MARK: - Notification Bell Button with Badge
struct NotificationBellButton: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @ObservedObject var notificationService: NotificationService
    let userType: String // "customer" or "baker"
    
    var body: some View {
        NavigationLink(destination: NotificationCenterView(notificationManager: notificationManager, userType: userType)) {
            ZStack(alignment: .topTrailing) {
                // Bell Icon with circle background
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .stroke(Color.cakeGrey.opacity(0.2), lineWidth: 1)
                    
                    Image(systemName: "bell.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.cakeGrey)
                }
                .frame(width: 40, height: 40)
                
                // Badge showing unread count for current user type
                let userNotifications = notificationService.getNotifications(for: userType)
                let unreadCount = userNotifications.filter { !$0.isRead }.count
                
                if unreadCount > 0 {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.95, green: 0.2, blue: 0.2))
                        
                        Text("\(unreadCount)")
                            .font(.urbanistBold(11))
                            .foregroundColor(.white)
                    }
                    .frame(width: 22, height: 22)
                    .offset(x: 10, y: -10)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationBellButton(notificationService: NotificationService(), userType: "customer")
            .environmentObject(NotificationManager())
    }
}
