import SwiftUI

// MARK: - Notification Overlay Modifier
struct NotificationOverlay: ViewModifier {
    @ObservedObject var notificationManager: NotificationManager
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            if let popup = notificationManager.currentPopup {
                VStack {
                    NotificationPopupView(
                        notification: popup.notification,
                        onDismiss: {
                            notificationManager.dismissPopup()
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    
                    Spacer()
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

extension View {
    func notificationOverlay(_ notificationManager: NotificationManager) -> some View {
        modifier(NotificationOverlay(notificationManager: notificationManager))
    }
}
