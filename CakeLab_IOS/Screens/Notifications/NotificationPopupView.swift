import SwiftUI

// MARK: - In-App Notification Popup (Simple Card Design)
struct NotificationPopupView: View {
    let notification: AppNotification
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with APP NAME and close button
            HStack {
                Text("CakeLab")
                    .font(.urbanistRegular(10))
                    .foregroundColor(.gray)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text(notification.timeAgo)
                        .font(.urbanistRegular(10))
                        .foregroundColor(.gray)
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Divider
            Divider()
                .padding(.horizontal, 16)
            
            // Content
            HStack(alignment: .top, spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.15))
                    
                    Image(systemName: notification.type.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .frame(width: 44, height: 44)
                
                // Text Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.title)
                        .font(.urbanistBold(14))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .lineLimit(1)
                    
                    Text(notification.message)
                        .font(.urbanistRegular(13))
                        .foregroundColor(.gray)
                        .lineLimit(3)
                }
                
                Spacer()
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.95, green: 0.95, blue: 0.95)) // Light gray background
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview {
    NotificationPopupView(
        notification: AppNotification(
            type: .newBidReceived,
            title: "Title",
            message: "This is a test data body message",
            userType: "customer"
        ),
        onDismiss: {}
    )
}
