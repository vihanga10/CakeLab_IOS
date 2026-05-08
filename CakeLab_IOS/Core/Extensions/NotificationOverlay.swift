import SwiftUI

// MARK: - Notification Overlay Modifier
// ViewModifier that layers a notification popup on top of any view using a ZStack
struct NotificationOverlay: ViewModifier {
    // Observes NotificationManager so the overlay reacts when a new popup is triggered or dismissed
    @ObservedObject var notificationManager: NotificationManager

    func body(content: Content) -> some View {
        // Places the popup above the existing content, anchored to the top of the screen
        ZStack(alignment: .top) {
            content

            // Only renders the popup when NotificationManager has an active popup to show
            if let popup = notificationManager.currentPopup {
                VStack {
                    NotificationPopupView(
                        notification: popup.notification,
                        onDismiss: {
                            // Calls dismissPopup() so NotificationManager clears the current popup
                            notificationManager.dismissPopup()
                        }
                    )
                    // Slides in from the top edge and fades in; reverses on dismiss
                    .transition(.move(edge: .top).combined(with: .opacity))

                    Spacer()
                }
                // Allows the popup to extend into the safe area at the bottom without clipping
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

// View extension that provides a clean call-site API to attach the notification overlay to any view
extension View {
    func notificationOverlay(_ notificationManager: NotificationManager) -> some View {
        modifier(NotificationOverlay(notificationManager: notificationManager))
    }
}
