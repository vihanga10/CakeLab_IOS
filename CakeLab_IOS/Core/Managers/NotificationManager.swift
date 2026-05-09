import Foundation
import Combine
import FirebaseFirestore
import UserNotifications

// MARK: - Notification Manager
@MainActor
class NotificationManager: Combine.ObservableObject {
    @Combine.Published var notificationService: NotificationService

    init(notificationService: NotificationService = NotificationService()) {
        self.notificationService = notificationService
    }
    
    // MARK: - Reload Notifications (for login)
    func reloadNotifications(for userType: String, userID: String? = nil) {
        notificationService.loadNotifications()
        print(" [NotificationManager] Notifications reloaded on login for \(userType)")
    }

    // MARK: - Mark Notification as Read
    func markNotificationAsRead(_ notification: AppNotification) {
        notificationService.markAsRead(notification)
    }
    
    // MARK: - Show Notification
    func showNotification(_ notification: AppNotification, duration: TimeInterval = 5.0) {
        print(" [NotificationManager] Showing notification: \(notification.title)")
        
        // Save to persistent storage
        saveNotificationAndScheduleLocal(notification)
        print(" [NotificationService] Notification saved. Total notifications: \(notificationService.notifications.count)")
    }

    private func scheduleLocalNotification(
        _ notification: AppNotification,
        replacePrevious: Bool = true,
        timeInterval: TimeInterval = 1
    ) {
        Task {
            await Self.scheduleLocalNotification(
                title: notification.title,
                body: notification.message,
                identifier: "app-notification-\(notification.id)",
                timeInterval: timeInterval,
                replacePrevious: replacePrevious
            )
        }
    }

    private func saveNotificationAndScheduleLocal(
        _ notification: AppNotification,
        replacePrevious: Bool = true,
        timeInterval: TimeInterval = 1
    ) {
        let isNewNotification = !hasStoredNotification(notification)
        notificationService.saveNotification(notification)

        if isNewNotification {
            scheduleLocalNotification(
                notification,
                replacePrevious: replacePrevious,
                timeInterval: timeInterval
            )
        }
    }

    nonisolated static func scheduleLocalNotification(
        title: String,
        body: String,
        identifier: String = UUID().uuidString,
        timeInterval: TimeInterval = 1,
        replacePrevious: Bool = true
    ) async {
        let center = UNUserNotificationCenter.current()
        guard await requestNotificationAuthorizationIfNeeded(center: center) else { return }
        if replacePrevious {
            await removePreviousAppLocalNotifications(center: center)
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(timeInterval, 1),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            print("Local notification failed: \(error.localizedDescription)")
        }
    }

    nonisolated private static func removePreviousAppLocalNotifications(
        center: UNUserNotificationCenter
    ) async {
        let appNotificationPrefixes = ["app-notification-", "account-created-"]

        let pendingIDs = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { identifier in
                appNotificationPrefixes.contains { identifier.hasPrefix($0) }
            }
        if !pendingIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
        }

        let deliveredIDs = await center.deliveredNotifications()
            .map { $0.request.identifier }
            .filter { identifier in
                appNotificationPrefixes.contains { identifier.hasPrefix($0) }
            }
        if !deliveredIDs.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
        }
    }

    nonisolated private static func requestNotificationAuthorizationIfNeeded(
        center: UNUserNotificationCenter
    ) async -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                print("Notification permission request failed: \(error.localizedDescription)")
                return false
            }
        @unknown default:
            return false
        }
    }

    private func hasStoredNotification(_ notification: AppNotification) -> Bool {
        notificationService.existingNotification(
            type: notification.type,
            userType: notification.userType,
            relatedOrderID: notification.relatedOrderID,
            relatedBakerID: notification.relatedBakerID,
            relatedCustomerID: notification.relatedCustomerID
        ) != nil
    }

    private func fetchBakerOrderDocuments(db: Firestore, bakerID: String) async throws -> [QueryDocumentSnapshot] {
        var documents: [QueryDocumentSnapshot] = []
        var seenIDs: Set<String> = []

        for field in ["artisanId", "bakerID", "bakerId"] {
            let snapshot = try await db.collection("orders")
                .whereField(field, isEqualTo: bakerID)
                .whereField("status", isEqualTo: "confirmed")
                .getDocuments()

            for document in snapshot.documents where seenIDs.insert(document.documentID).inserted {
                documents.append(document)
            }
        }

        return documents
    }

    private func fetchBakerPaymentDocuments(db: Firestore, bakerID: String) async throws -> [QueryDocumentSnapshot] {
        var documents: [QueryDocumentSnapshot] = []
        var seenIDs: Set<String> = []

        for field in ["bakerId", "bakerID"] {
            let snapshot = try await db.collection("payments")
                .whereField(field, isEqualTo: bakerID)
                .whereField("status", isEqualTo: "success")
                .getDocuments()

            for document in snapshot.documents where seenIDs.insert(document.documentID).inserted {
                documents.append(document)
            }
        }

        return documents
    }

    private func stageNotificationOrderID(orderID: String, statusKey: String) -> String {
        "\(orderID)#\(statusKey)"
    }

    private func statusStageTitle(for statusKey: String) -> String {
        switch statusKey {
        case "confirmed":
            return "Confirmed"
        case "baking":
            return "Baking"
        case "decorating":
            return "Decorating"
        case "quality_check":
            return "Quality Checking"
        case "delivered", "completed", "done":
            return "Delivered"
        default:
            return statusKey
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    private func normalizedOrderStatusKey(_ status: String) -> String {
        let normalized = status
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized == "completed" || normalized == "done" {
            return "delivered"
        }

        return normalized
    }
    
    // MARK: - Customer: Request Posted Successfully
    func notifyRequestPosted(requestTitle: String, bidCount: Int = 0, userID: String) {
        print(" [notifyRequestPosted] Called with title: '\(requestTitle)', userID: \(userID)")
        let notification = AppNotification(
            type: .requestPostedSuccess,
            title: NotificationType.requestPostedSuccess.title,
            message: "Your request '\(requestTitle)' has been published successfully.",
            userType: "customer",
            relatedOrderID: UUID().uuidString,
            relatedBakerID: nil,
            relatedCustomerID: userID
        )
        scheduleLocalNotification(notification)
    }
    
    // MARK: - Customer: Draft Saved Successfully
    func notifyDraftSaved(requestTitle: String = "", userID: String) {
        let trimmedTitle = requestTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = trimmedTitle.isEmpty
            ? "Your cake request draft has been saved successfully."
            : "Your draft '\(trimmedTitle)' has been saved successfully."
        
        let notification = AppNotification(
            type: .draftSavedSuccess,
            title: NotificationType.draftSavedSuccess.title,
            message: message,
            userType: "customer",
            relatedOrderID: nil,
            relatedBakerID: nil,
            relatedCustomerID: userID
        )
        scheduleLocalNotification(notification)
    }
    
    // MARK: - Customer: New Bid Received
    func notifyNewBidReceived(bakerName: String, bidAmount: Double, requestTitle: String, bakerID: String, orderID: String, customerID: String, showPopup: Bool = true) {
        let notification = AppNotification(
            type: .newBidReceived,
            title: NotificationType.newBidReceived.title,
            message: "\(bakerName) placed a bid of LKR \(Int(bidAmount).formatted()) on '\(requestTitle)'",
            userType: "customer",
            relatedOrderID: orderID,
            relatedBakerID: bakerID,
            relatedCustomerID: customerID
        )
        if showPopup {
            showNotification(notification)
        } else {
            // Cross-user notification: do not show or store it on the sender's device.
            // The customer's app will create the local notification during Firestore sync.
            return
        }
    }

    // MARK: - Customer: Sync New Bid Notifications From Firestore
    func syncNewBidReceivedNotifications(customerID: String) async {
        let trimmedCustomerID = customerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCustomerID.isEmpty else { return }

        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("bids")
                .whereField("customerID", isEqualTo: trimmedCustomerID)
                .getDocuments()

            var requestTitleCache: [String: String] = [:]

            for document in snapshot.documents {
                let data = document.data()
                let requestID = (data["requestDocumentID"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let bakerID = (data["bakerID"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !requestID.isEmpty, !bakerID.isEmpty else { continue }

                if notificationService.existingNotification(
                    type: .newBidReceived,
                    userType: "customer",
                    relatedOrderID: requestID,
                    relatedBakerID: bakerID,
                    relatedCustomerID: trimmedCustomerID
                ) != nil {
                    continue
                }

                let requestTitle: String
                if let cached = requestTitleCache[requestID] {
                    requestTitle = cached
                } else if let savedTitle = data["requestTitle"] as? String, !savedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    requestTitle = savedTitle
                    requestTitleCache[requestID] = savedTitle
                } else {
                    let requestDoc = try await db.collection("cakeRequests").document(requestID).getDocument()
                    let resolvedTitle = requestDoc.data()?["title"] as? String ?? "your cake request"
                    requestTitleCache[requestID] = resolvedTitle
                    requestTitle = resolvedTitle
                }

                let bakerName = data["bakerName"] as? String ?? "A baker"
                let amount = Self.doubleValue(data["amount"])
                let submittedAt = (data["submittedAt"] as? Timestamp)?.dateValue() ?? Date()

                let notification = AppNotification(
                    type: .newBidReceived,
                    title: NotificationType.newBidReceived.title,
                    message: "\(bakerName) placed a bid of LKR \(Int(amount).formatted()) on '\(requestTitle)'",
                    userType: "customer",
                    timestamp: submittedAt,
                    relatedOrderID: requestID,
                    relatedBakerID: bakerID,
                    relatedCustomerID: trimmedCustomerID
                )
                saveNotificationAndScheduleLocal(notification)
            }
        } catch {
            print(" [NotificationManager] Failed to sync new bid notifications: \(error.localizedDescription)")
        }
    }

    // MARK: - Baker: Sync Order Confirmed and Payment Received Notifications
    func syncBakerOrderAndPaymentNotifications(bakerID: String) async {
        let trimmedBakerID = bakerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBakerID.isEmpty else { return }

        do {
            let db = Firestore.firestore()
            var localDelay: TimeInterval = 1

            let orderDocuments = try await fetchBakerOrderDocuments(db: db, bakerID: trimmedBakerID)
            for document in orderDocuments {
                let data = document.data()
                let timestamp = Self.dateValue(data["createdAt"]) ?? Self.dateValue(data["updatedAt"]) ?? Date()
                guard Self.isRecentNotificationDate(timestamp) else { continue }

                let requestSnapshot = data["requestSnapshot"] as? [String: Any] ?? [:]
                let customerID = Self.firstString(data["customerId"], data["customerID"])
                let customerName = Self.firstString(
                    data["customerName"],
                    data["customerFullName"],
                    requestSnapshot["customerName"],
                    "Customer"
                )
                let cakeTitle = Self.firstString(data["cakeName"], data["title"], requestSnapshot["title"], "Cake Order")
                let deliveryDate = Self.dateValue(data["deliveryDate"]) ?? Date()
                let formatter = DateFormatter()
                formatter.dateStyle = .medium

                let notification = AppNotification(
                    type: .bakerOrderConfirmed,
                    title: NotificationType.bakerOrderConfirmed.title,
                    message: "Order confirmed by \(customerName) for '\(cakeTitle)'. Delivery: \(formatter.string(from: deliveryDate)).",
                    userType: "baker",
                    timestamp: timestamp,
                    relatedOrderID: document.documentID,
                    relatedBakerID: trimmedBakerID,
                    relatedCustomerID: customerID.isEmpty ? nil : customerID
                )
                saveNotificationAndScheduleLocal(
                    notification,
                    replacePrevious: false,
                    timeInterval: localDelay
                )
                localDelay += 1
            }

            let paymentDocuments = try await fetchBakerPaymentDocuments(db: db, bakerID: trimmedBakerID)
            for document in paymentDocuments {
                let data = document.data()
                let timestamp = Self.dateValue(data["createdAt"]) ?? Date()
                guard Self.isRecentNotificationDate(timestamp) else { continue }

                let customerID = Self.firstString(data["customerId"], data["customerID"])
                let customerName = Self.firstString(data["customerName"], "Customer")
                let orderID = Self.firstString(data["orderID"], document.documentID)
                let amount = Self.doubleValue(data["amount"])

                let notification = AppNotification(
                    type: .bakerPaymentReceived,
                    title: NotificationType.bakerPaymentReceived.title,
                    message: "Payment of LKR \(Int(amount).formatted()) received from \(customerName).",
                    userType: "baker",
                    timestamp: timestamp,
                    relatedOrderID: orderID,
                    relatedBakerID: trimmedBakerID,
                    relatedCustomerID: customerID.isEmpty ? nil : customerID
                )
                saveNotificationAndScheduleLocal(
                    notification,
                    replacePrevious: false,
                    timeInterval: localDelay
                )
                localDelay += 1
            }
        } catch {
            print(" [NotificationManager] Failed to sync baker order/payment notifications: \(error.localizedDescription)")
        }
    }

    // MARK: - Customer: Sync Order Status Update Notifications From Firestore
    func syncCustomerOrderStatusNotifications(customerID: String) async {
        let trimmedCustomerID = customerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCustomerID.isEmpty else { return }

        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("orders")
                .whereField("customerId", isEqualTo: trimmedCustomerID)
                .whereField("status", in: ["baking", "decorating", "quality_check", "delivered", "completed", "done"])
                .getDocuments()

            var localDelay: TimeInterval = 1
            for document in snapshot.documents {
                let data = document.data()
                let statusKey = normalizedOrderStatusKey(Self.firstString(data["status"]))
                guard !statusKey.isEmpty, statusKey != "confirmed" else { continue }

                let progressTimestamps = data["progressTimestamps"] as? [String: Any] ?? [:]
                let timestamp = Self.dateValue(progressTimestamps[statusKey])
                    ?? Self.dateValue(data["updatedAt"])
                    ?? Date()
                guard Self.isRecentNotificationDate(timestamp) else { continue }

                let bakerID = Self.firstString(data["artisanId"], data["bakerID"], data["bakerId"])
                let bakerName = Self.firstString(data["artisanName"], data["bakerName"], "Your baker")
                let cakeName = Self.firstString(data["cakeName"], data["title"], "your cake order")
                let stageTitle = statusStageTitle(for: statusKey)

                let notification = AppNotification(
                    type: .orderStatusUpdated,
                    title: NotificationType.orderStatusUpdated.title,
                    message: "\(bakerName) updated '\(cakeName)' to \(stageTitle).",
                    userType: "customer",
                    timestamp: timestamp,
                    relatedOrderID: stageNotificationOrderID(orderID: document.documentID, statusKey: statusKey),
                    relatedBakerID: bakerID.isEmpty ? nil : bakerID,
                    relatedCustomerID: trimmedCustomerID
                )
                saveNotificationAndScheduleLocal(
                    notification,
                    replacePrevious: false,
                    timeInterval: localDelay
                )
                localDelay += 1
            }
        } catch {
            print(" [NotificationManager] Failed to sync customer order status notifications: \(error.localizedDescription)")
        }
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

    // MARK: - Baker: Order Status Updated
    func notifyBakerOrderStatusUpdated(cakeName: String, stageTitle: String, statusKey: String, orderID: String, customerID: String, bakerID: String) {
        let notification = AppNotification(
            type: .orderStatusUpdated,
            title: NotificationType.orderStatusUpdated.title,
            message: "'\(cakeName)' status updated to \(stageTitle) successfully.",
            userType: "baker",
            relatedOrderID: stageNotificationOrderID(orderID: orderID, statusKey: statusKey),
            relatedBakerID: bakerID,
            relatedCustomerID: customerID
        )
        showNotification(notification)
    }

    // MARK: - Customer: Order Status Updated
    func notifyCustomerOrderStatusUpdated(bakerName: String, cakeName: String, stageTitle: String, statusKey: String, orderID: String, customerID: String, bakerID: String) {
        let notification = AppNotification(
            type: .orderStatusUpdated,
            title: NotificationType.orderStatusUpdated.title,
            message: "\(bakerName) updated '\(cakeName)' to \(stageTitle).",
            userType: "customer",
            relatedOrderID: stageNotificationOrderID(orderID: orderID, statusKey: statusKey),
            relatedBakerID: bakerID.isEmpty ? nil : bakerID,
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
        if let existing = notificationService.existingNotification(
            type: .newMatchingRequest,
            userType: "baker",
            relatedOrderID: orderID,
            relatedBakerID: bakerID,
            relatedCustomerID: customerID
        ) {
            return
        }

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

    // MARK: - Baker: Bid Submitted Popup Only
    func notifyBakerBidSubmitted(requestTitle: String, bidAmount: Double, customerID: String, bakerID: String, orderID: String) {
        let notification = AppNotification(
            type: .bakerBidSubmitted,
            title: "Bid Sent Successfully",
            message: "Your bid of LKR \(Int(bidAmount).formatted()) has been sent to the customer for '\(requestTitle)'.",
            userType: "baker",
            relatedOrderID: orderID,
            relatedBakerID: bakerID,
            relatedCustomerID: customerID
        )
        scheduleLocalNotification(notification)
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
    func notifyBakerOrderConfirmed(customerName: String, requestTitle: String, deliveryDate: Date, orderID: String, customerID: String, bakerID: String, showPopup: Bool = true) {
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
        if showPopup {
            showNotification(notification)
        } else {
            // Cross-user notification: do not show or store it on the customer's device.
            // The baker app creates the real banner and history item during Firestore sync.
            return
        }
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
    func notifyBakerPaymentReceived(customerName: String, amount: Double, orderID: String, customerID: String, bakerID: String, showPopup: Bool = true) {
        let notification = AppNotification(
            type: .bakerPaymentReceived,
            title: NotificationType.bakerPaymentReceived.title,
            message: "Payment of LKR \(Int(amount).formatted()) received from \(customerName).",
            userType: "baker",
            relatedOrderID: orderID,
            relatedBakerID: bakerID,
            relatedCustomerID: customerID
        )
        if showPopup {
            showNotification(notification)
        } else {
            // Cross-user notification: do not show or store it on the customer's device.
            // The baker app creates the real banner and history item during Firestore sync.
            return
        }
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

    private static func firstString(_ values: Any?...) -> String {
        for value in values {
            if let string = value as? String {
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            } else if let number = value as? NSNumber {
                return number.stringValue
            }
        }
        return ""
    }

    private static func dateValue(_ value: Any?) -> Date? {
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }

        if let date = value as? Date {
            return date
        }

        if let timeInterval = value as? TimeInterval {
            return Date(timeIntervalSince1970: timeInterval)
        }

        if let number = value as? NSNumber {
            return Date(timeIntervalSince1970: number.doubleValue)
        }

        return nil
    }

    private static func isRecentNotificationDate(_ date: Date) -> Bool {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return date >= sevenDaysAgo
    }

    private static func doubleValue(_ value: Any?) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String {
            let cleaned = value.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(cleaned) ?? 0
        }
        return 0
    }
}
