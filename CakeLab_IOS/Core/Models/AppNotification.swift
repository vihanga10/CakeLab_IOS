import Foundation

// MARK: - Notification Type
enum NotificationType: String, Codable {
    // Customer: Order/Request Lifecycle
    case requestPostedSuccess = "requestPostedSuccess"
    case newBidReceived = "newBidReceived"
    case bidAccepted = "bidAccepted"
    case orderConfirmed = "orderConfirmed"
    
    // Customer: Delivery & Completion
    case deliveryReminder = "deliveryReminder"
    case bakerOnTheWay = "bakerOnTheWay"
    case deliveryCompleted = "deliveryCompleted"
    case orderCancelled = "orderCancelled"
    
    // Customer: Engagement
    case reviewRequest = "reviewRequest"
    case bakerMessage = "bakerMessage"
    case paymentReceipt = "paymentReceipt"
    
    // Baker: Request Opportunities
    case newMatchingRequest = "newMatchingRequest"
    
    // Baker: Bid Management
    case bakerBidAccepted = "bakerBidAccepted"
    
    // Baker: Order Management
    case bakerOrderConfirmed = "bakerOrderConfirmed"
    case deliveryInstructionsUpdated = "deliveryInstructionsUpdated"
    case customerMessageReceived = "customerMessageReceived"
    case deliveryConfirmationNeeded = "deliveryConfirmationNeeded"
    
    // Baker: Engagement & Payments
    case bakerPaymentReceived = "bakerPaymentReceived"
    case bakerNewReview = "bakerNewReview"
    
    var title: String {
        switch self {
        case .requestPostedSuccess:
            return "Request Posted Successfully"
        case .newBidReceived:
            return "New Bid Received"
        case .bidAccepted:
            return "Bid Accepted"
        case .orderConfirmed:
            return "Order Confirmed"
        case .deliveryReminder:
            return "Delivery Reminder"
        case .bakerOnTheWay:
            return "Baker on the Way"
        case .deliveryCompleted:
            return "Delivery Completed"
        case .orderCancelled:
            return "Order Cancelled"
        case .reviewRequest:
            return "Please Review Your Baker"
        case .bakerMessage:
            return "Message from Baker"
        case .paymentReceipt:
            return "Payment Receipt"
        case .newMatchingRequest:
            return "New Matching Request"
        case .bakerBidAccepted:
            return "Your Bid Accepted"
        case .bakerOrderConfirmed:
            return "Order Confirmed - Ready to Bake"
        case .deliveryInstructionsUpdated:
            return "Delivery Instructions Updated"
        case .customerMessageReceived:
            return "New Message from Customer"
        case .deliveryConfirmationNeeded:
            return "Confirm Delivery"
        case .bakerPaymentReceived:
            return "Payment Received"
        case .bakerNewReview:
            return "New Review Received"
        }
    }
    
    var category: String {
        switch self {
        case .requestPostedSuccess, .newBidReceived, .bidAccepted, .orderConfirmed:
            return "Order Lifecycle"
        case .deliveryReminder, .bakerOnTheWay, .deliveryCompleted, .orderCancelled:
            return "Delivery & Completion"
        case .reviewRequest, .bakerMessage, .paymentReceipt:
            return "Engagement"
        case .newMatchingRequest:
            return "Request Opportunities"
        case .bakerBidAccepted:
            return "Bid Management"
        case .bakerOrderConfirmed, .deliveryInstructionsUpdated, .customerMessageReceived, .deliveryConfirmationNeeded:
            return "Order Management"
        case .bakerPaymentReceived, .bakerNewReview:
            return "Baker Engagement"
        }
    }
    
    var icon: String {
        switch self {
        case .requestPostedSuccess:
            return "checkmark.circle.fill"
        case .newBidReceived:
            return "person.badge.plus"
        case .bidAccepted:
            return "hand.thumbsup.fill"
        case .orderConfirmed:
            return "doc.text.fill"
        case .deliveryReminder:
            return "clock.fill"
        case .bakerOnTheWay:
            return "car.fill"
        case .deliveryCompleted:
            return "checkmark.circle.fill"
        case .orderCancelled:
            return "xmark.circle.fill"
        case .reviewRequest:
            return "star.fill"
        case .bakerMessage:
            return "bubble.left.fill"
        case .paymentReceipt:
            return "creditcard.fill"
        case .newMatchingRequest:
            return "sparkles"
        case .bakerBidAccepted:
            return "hand.thumbsup.fill"
        case .bakerOrderConfirmed:
            return "birthday.cake.fill"
        case .deliveryInstructionsUpdated:
            return "note.text"
        case .customerMessageReceived:
            return "envelope.fill"
        case .deliveryConfirmationNeeded:
            return "checkmark.square.fill"
        case .bakerPaymentReceived:
            return "dollarsign.circle.fill"
        case .bakerNewReview:
            return "star.leadinghalf.filled"
        }
    }
}

// MARK: - App Notification Model
struct AppNotification: Identifiable, Codable {
    let id: String
    let type: NotificationType
    let title: String
    let message: String
    let userType: String // "customer" or "baker"
    let timestamp: Date
    var isRead: Bool
    let relatedOrderID: String? // Link to order/request
    let relatedBakerID: String? // For customer notifications
    let relatedCustomerID: String? // For baker notifications
    
    enum CodingKeys: String, CodingKey {
        case id, type, title, message, userType, timestamp, isRead
        case relatedOrderID, relatedBakerID, relatedCustomerID
    }
    
    init(
        id: String = UUID().uuidString,
        type: NotificationType,
        title: String,
        message: String,
        userType: String,
        timestamp: Date = Date(),
        isRead: Bool = false,
        relatedOrderID: String? = nil,
        relatedBakerID: String? = nil,
        relatedCustomerID: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.userType = userType
        self.timestamp = timestamp
        self.isRead = isRead
        self.relatedOrderID = relatedOrderID
        self.relatedBakerID = relatedBakerID
        self.relatedCustomerID = relatedCustomerID
    }
    
    var timeAgo: String {
        let interval = Date().timeIntervalSince(timestamp)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)
        
        if minutes < 1 {
            return "Just now"
        } else if minutes < 60 {
            return "\(minutes)m ago"
        } else if hours < 24 {
            return "\(hours)h ago"
        } else if days < 7 {
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: timestamp)
        }
    }
    
    var isWithin7Days: Bool {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return timestamp >= sevenDaysAgo
    }
}
