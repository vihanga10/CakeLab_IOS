import SwiftUI

// MARK: - Notification Center View
struct NotificationCenterView: View {
    @ObservedObject var notificationManager: NotificationManager
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    
    let userType: String // "customer" or "baker"
    
    private var filteredNotifications: [AppNotification] {
        notificationManager.notificationService.getNotifications(for: userType)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Header (PublishRequestView pattern)
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.cakeBrown)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text("Notifications")
                                .font(.urbanistBold(18))
                                .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
                        }
                        
                        Spacer()
                        
                        // Three dots menu
                        if !filteredNotifications.isEmpty {
                            Menu {
                                Button(role: .destructive) {
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Clear All", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                        } else {
                            Color.clear.frame(width: 24)
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                    .background(Color.white)
                    
                    // MARK: - "All" Tab (No filter section)
                    VStack(spacing: 0) {
                        HStack(spacing: 6) {
                            Text("All")
                                .font(.urbanistMedium(14))
                                .foregroundColor(.gray)
                            
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 44)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // No line under "All"
                    }
                    .background(Color.white)
                    
                    // MARK: - Notifications List
                    if filteredNotifications.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "bell.slash.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.cakeBrown.opacity(0.3))
                            
                            Text("No Notifications")
                                .font(.urbanistSemiBold(18))
                                .foregroundColor(.cakeBrown)
                            
                            Text("You're all caught up!")
                                .font(.urbanistRegular(14))
                                .foregroundColor(.cakeGrey)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                ForEach(filteredNotifications, id: \.id) { notification in
                                    NotificationItemView(
                                        notification: notification,
                                        notificationManager: notificationManager,
                                        onTap: {
                                            notificationManager.notificationService.markAsRead(notification)
                                            // No need to reload - markAsRead already updates @Published notifications
                                        },
                                        onDelete: {
                                            notificationManager.notificationService.deleteNotification(notification)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        }
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
        }
        .alert("Clear All Notifications", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                notificationManager.notificationService.deleteAllNotifications()
            }
        } message: {
            Text("Are you sure you want to delete all notifications? This action cannot be undone.")
        }
    }
}

// MARK: - Notification Item View
private struct NotificationItemView: View {
    let notification: AppNotification
    let notificationManager: NotificationManager
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteConfirm = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Icon Circle
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                    
                    Image(systemName: notification.type.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.cakeBrown)
                }
                .frame(width: 50, height: 50)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(notification.title)
                            .font(.urbanistBold(14))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Time on right side
                        Text(notification.timeAgo)
                            .font(.urbanistRegular(11))
                            .foregroundColor(.cakeGrey)
                    }
                    
                    Text(notification.message)
                        .font(.urbanistRegular(13))
                        .foregroundColor(.cakeGrey)
                        .lineLimit(2)
                }
            }
            .padding(14)
            .onTapGesture {
                onTap()
            }
            
            // Delete Icon in bottom-right corner
            HStack {
                Spacer()
                
                Button(action: { showDeleteConfirm = true }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.cakeGrey)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
        .background(notification.isRead ? Color.white : Color(red: 0.9, green: 0.9, blue: 0.9)) // E5E5E5 for unread, white for read
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.06), lineWidth: 0.8)
        )
        .alert("Delete Notification", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this notification?")
        }
    }
}
