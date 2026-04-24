import Foundation
import SwiftUI
import Combine

// MARK: - In-App Notification Popup
struct InAppNotificationPopup: Identifiable, Equatable {
    let id: UUID
    let notification: AppNotification
    
    init(notification: AppNotification) {
        self.id = UUID()
        self.notification = notification
    }
    
    static func == (lhs: InAppNotificationPopup, rhs: InAppNotificationPopup) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Notification Manager
class NotificationManager: ObservableObject {
    @Published var currentPopup: InAppNotificationPopup?
    @Published var notificationService: NotificationService
    
    private var popupTimer: Timer?
    
    init(notificationService: NotificationService = NotificationService()) {
        self.notificationService = notificationService
    }
    
    // MARK: - Reload Notifications (for login)
    func reloadNotifications(for userType: String) {
        notificationService.loadNotifications()
        print("🔄 [NotificationManager] Notifications reloaded on login for \(userType)")
        
        // Filter notifications by userType and unread status
        let relevantNotifications = notificationService.notifications
            .filter { !$0.isRead && $0.userType == userType }
            .prefix(3) // Show max 3 popups
        
        for (index, notification) in relevantNotifications.enumerated() {
            // Space out popups by 0.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) { [weak self] in
                self?.showPopupOnly(notification)
                // Mark as read after showing
                self?.markNotificationAsRead(notification)
            }
        }
    }
    
    // MARK: - Show Popup Only (without saving again)
    private func showPopupOnly(_ notification: AppNotification, duration: TimeInterval = 5.0) {
        print("🔔 [NotificationManager] Showing loaded notification: \(notification.title)")
        
        // Show popup (already saved in storage)
        withAnimation(.easeInOut(duration: 0.3)) {
            self.currentPopup = InAppNotificationPopup(notification: notification)
            print("📱 [UI] Popup displayed for: \(notification.title)")
        }
        
        // Auto-dismiss after duration
        popupTimer?.invalidate()
        popupTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.dismissPopup()
        }
    }
    
    // MARK: - Mark Notification as Read
    func markNotificationAsRead(_ notification: AppNotification) {
        notificationService.markAsRead(notification)
    }
    
    // MARK: - Show Notification Popup
    func showNotification(_ notification: AppNotification, duration: TimeInterval = 5.0) {
        print("🔔 [NotificationManager] Showing notification: \(notification.title)")
        
        // Save to persistent storage
        notificationService.saveNotification(notification)
        print("💾 [NotificationService] Notification saved. Total notifications: \(notificationService.notifications.count)")
        
        // Show popup
        withAnimation(.easeInOut(duration: 0.3)) {
            self.currentPopup = InAppNotificationPopup(notification: notification)
            print("📱 [UI] Popup displayed for: \(notification.title)")
        }
        
        // Auto-dismiss after duration
        popupTimer?.invalidate()
        popupTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.dismissPopup()
        }
    }
    
    // MARK: - Dismiss Popup
    func dismissPopup() {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.currentPopup = nil
        }
        popupTimer?.invalidate()
    }
    
    // MARK: - Customer: Request Posted Successfully
    func notifyRequestPosted(requestTitle: String, bidCount: Int = 0, userID: String) {
        print("✅ [notifyRequestPosted] Called with title: '\(requestTitle)', userID: \(userID)")
        let notification = AppNotification(
            type: .requestPostedSuccess,
            title: NotificationType.requestPostedSuccess.title,
            message: "Your request '\(requestTitle)' has been published successfully.",
            userType: "customer",
            relatedOrderID: UUID().uuidString,
            relatedBakerID: nil,
            relatedCustomerID: userID
        )
        showNotification(notification)
    }
    
    // MARK: - Customer: New Bid Received
    func notifyNewBidReceived(bakerName: String, bidAmount: Double, requestTitle: String, bakerID: String, orderID: String, customerID: String) {
        let notification = AppNotification(
            type: .newBidReceived,
            title: NotificationType.newBidReceived.title,
            message: "\(bakerName) placed a bid of LKR \(Int(bidAmount).formatted()) on '\(requestTitle)'",
            userType: "customer",
            relatedOrderID: orderID,
            relatedBakerID: bakerID,
            relatedCustomerID: customerID
        )
        showNotification(notification)
    }
    
    // MARK: - Customer: Bid Accepted
    func notifyBidAccepted(bakerName: String, requestTitle: String, bakerID: String, orderID: String, customerID: String) {
        let notification = AppNotification(
            type: .bidAccepted,
            title: NotificationType.bidAccepted.title,
            message: "Your bid with \(bakerName) for '\(requestTitle)' has been accepted.",
            userType: "customer",
            relatedOrderID: orderID,
            relatedBakerID: bakerID,
            relatedCustomerID: customerID
        )
        showNotification(notification)
    }
    
    // MARK: - Customer: Order Confirmed
    func notifyOrderConfirmed(bakerName: String, deliveryDate: Date, orderID: String, customerID: String) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateString = formatter.string(from: deliveryDate)
        
        let notification = AppNotification(
            type: .orderConfirmed,
            title: NotificationType.orderConfirmed.title,
            message: "Your order with \(bakerName) is confirmed. Delivery date: \(dateString)",
            userType: "customer",
            relatedOrderID: orderID,
            relatedBakerID: nil,
            relatedCustomerID: customerID
        )
        showNotification(notification)
    }
    
    // MARK: - Customer: Delivery Reminder
    func notifyDeliveryReminder(bakerName: String, deliveryDate: Date, orderID: String, customerID: String) {
        let notification = AppNotification(
            type: .deliveryReminder,
            title: NotificationType.deliveryReminder.title,
            message: "Your cake will be delivered tomorrow by \(bakerName).",
            userType: "customer",
            relatedOrderID: orderID,
            relatedBakerID: nil,
            relatedCustomerID: customerID
        )
        showNotification(notification)
    }
    
    // MARK: - Customer: Baker on the Way
    func notifyBakerOnTheWay(bakerName: String, orderID: String, customerID: String) {
        let notification = AppNotification(
            type: .bakerOnTheWay,
            title: NotificationType.bakerOnTheWay.title,
            message: "\(bakerName) is on the way to deliver your cake!",
            userType: "customer",
            relatedOrderID: orderID,
            relatedBakerID: nil,
            relatedCustomerID: customerID
        )
        showNotification(notification)
    }
    
    // MARK: - Customer: Delivery Completed
    func notifyDeliveryCompleted(bakerName: String, orderID: String, customerID: String) {
        let notification = AppNotification(
            type: .deliveryCompleted,
            title: NotificationType.deliveryCompleted.title,
            message: "Your cake has been delivered by \(bakerName). Rate your experience!",
            userType: "customer",
            relatedOrderID: orderID,
            relatedBakerID: nil,
            relatedCustomerID: customerID
        )
        showNotification(notification)
    }
    
    // MARK: - Customer: Order Cancelled
    func notifyOrderCancelled(bakerName: String, reason: String = "", orderID: String, customerID: String) {
        let message = reason.isEmpty ? "Your order with \(bakerName) has been cancelled." : "Your order has been cancelled. Reason: \(reason)"
        let notification = AppNotification(
            type: .orderCancelled,
            title: NotificationType.orderCancelled.title,
            message: message,
            userType: "customer",
            relatedOrderID: orderID,
            relatedBakerID: nil,
            relatedCustomerID: customerID
        )
        showNotification(notification)
    }
    

    
    // MARK: - Customer: Baker Message
    func notifyBakerMessage(bakerName: String, message: String, bakerID: String, customerID: String) {
        let notification = AppNotification(
            type: .bakerMessage,
            title: NotificationType.bakerMessage.title,
            message: "\(bakerName): \(message)",
            userType: "customer",
            relatedOrderID: nil,
            relatedBakerID: bakerID,
            relatedCustomerID: customerID
        )
        showNotification(notification)
    }
    
    // MARK: - Customer: Payment Receipt
    func notifyPaymentReceipt(amount: Double, bakerName: String, orderID: String, customerID: String) {
        let notification = AppNotification(
            type: .paymentReceipt,
            title: NotificationType.paymentReceipt.title,
            message: "Payment of LKR \(Int(amount).formatted()) confirmed for \(bakerName).",
            userType: "customer",
            relatedOrderID: orderID,
            relatedBakerID: nil,
            relatedCustomerID: customerID
        )
        showNotification(notification)
    }
    
    // MARK: - Baker: New Matching Request
    func notifyNewMatchingRequest(requestTitle: String, category: String, budget: Double, customerID: String, bakerID: String, orderID: String) {
        let notification = AppNotification(
            type: .newMatchingRequest,
            title: NotificationType.newMatchingRequest.title,
            message: "New request: '\(requestTitle)' (\(category)) - Budget: LKR \(Int(budget).formatted())",
            userType: "baker",
            relatedOrderID: orderID,
            relatedBakerID: bakerID,
            relatedCustomerID: customerID
        )
        showNotification(notification)
    }
    
    // MARK: - Baker: Bid Accepted
    func notifyBakerBidAccepted(customerName: String, requestTitle: String, bidAmount: Double, customerID: String, bakerID: String, orderID: String) {
        let notification = AppNotification(
            type: .bakerBidAccepted,
            title: NotificationType.bakerBidAccepted.title,
            message: "\(customerName) accepted your bid of LKR \(Int(bidAmount).formatted()) for '\(requestTitle)'",
            userType: "baker",
            relatedOrderID: orderID,
            relatedBakerID: bakerID,
            relatedCustomerID: customerID
        )
        showNotification(notification)
    }
    
    // MARK: - Baker: Order Confirmed
    func notifyBakerOrderConfirmed(customerName: String, requestTitle: String, deliveryDate: Date, orderID: String, customerID: String, bakerID: String) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateString = formatter.string(from: deliveryDate)
        
        let notification = AppNotification(
            type: .bakerOrderConfirmed,
            title: NotificationType.bakerOrderConfirmed.title,
            message: "Order confirmed with \(customerName). Delivery: \(dateString). Start preparing!",
            userType: "baker",
            relatedOrderID: orderID,
            relatedBakerID: bakerID,
            relatedCustomerID: customerID
        )
        showNotification(notification)
    }
    
    // MARK: - Baker: Delivery Instructions Updated
    func notifyDeliveryInstructionsUpdated(customerName: String, orderID: String, customerID: String, bakerID: String) {
        let notification = AppNotification(
            type: .deliveryInstructionsUpdated,
            title: NotificationType.deliveryInstructionsUpdated.title,
            message: "\(customerName) updated delivery instructions. Check the details.",
            userType: "baker",
            relatedOrderID: orderID,
            relatedBakerID: bakerID,
            relatedCustomerID: customerID
        )
        showNotification(notification)
    }
    
    // MARK: - Baker: Customer Message Received
    func notifyCustomerMessageReceived(customerName: String, message: String, customerID: String, bakerID: String, orderID: String) {
        let notification = AppNotification(
            type: .customerMessageReceived,
            title: NotificationType.customerMessageReceived.title,
            message: "\(customerName): \(message)",
            userType: "baker",
            relatedOrderID: orderID,
            relatedBakerID: bakerID,
            relatedCustomerID: customerID
        )
        showNotification(notification)
    }
    
    // MARK: - Baker: Delivery Confirmation Needed
    func notifyDeliveryConfirmationNeeded(customerName: String, orderID: String, customerID: String, bakerID: String) {
        let notification = AppNotification(
            type: .deliveryConfirmationNeeded,
            title: NotificationType.deliveryConfirmationNeeded.title,
            message: "Confirm delivery to \(customerName). Tap to update status.",
            userType: "baker",
            relatedOrderID: orderID,
            relatedBakerID: bakerID,
            relatedCustomerID: customerID
        )
        showNotification(notification)
    }
    
    // MARK: - Baker: Payment Received
    func notifyBakerPaymentReceived(customerName: String, amount: Double, orderID: String, customerID: String, bakerID: String) {
        let notification = AppNotification(
            type: .bakerPaymentReceived,
            title: NotificationType.bakerPaymentReceived.title,
            message: "Payment of LKR \(Int(amount).formatted()) received from \(customerName).",
            userType: "baker",
            relatedOrderID: orderID,
            relatedBakerID: bakerID,
            relatedCustomerID: customerID
        )
        showNotification(notification)
    }
    
    // MARK: - Baker: New Review Received
    func notifyBakerNewReview(customerName: String, rating: Int, reviewText: String = "", bakerID: String) {
        let message = reviewText.isEmpty ? "\(customerName) gave you a \(rating)★ review!" : "\(customerName): \(rating)★ - \(reviewText)"
        let notification = AppNotification(
            type: .bakerNewReview,
            title: NotificationType.bakerNewReview.title,
            message: message,
            userType: "baker",
            relatedOrderID: nil,
            relatedBakerID: bakerID,
            relatedCustomerID: nil
        )
        showNotification(notification)
    }
}
