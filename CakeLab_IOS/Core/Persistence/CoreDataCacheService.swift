import CoreData
import Foundation

@MainActor
final class CoreDataCacheService {
    static let shared = CoreDataCacheService()

    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    func cachedReviews(for bakerID: String) -> [Review] {
        let request = NSFetchRequest<CachedReviewEntity>(entityName: "CachedReview")
        request.predicate = NSPredicate(format: "bakerID == %@", bakerID)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            return try stack.viewContext.fetch(request).map { entity in
                Review(
                    id: entity.id,
                    bakerID: entity.bakerID,
                    customerID: entity.customerID,
                    customerName: entity.customerName ?? "Customer",
                    customerImage: entity.customerImage,
                    rating: Int(entity.rating),
                    comment: entity.comment ?? "",
                    createdAt: entity.createdAt ?? Date()
                )
            }
        } catch {
            print("Core Data cached reviews fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    func cacheReviews(_ reviews: [Review], for bakerID: String) {
        for review in reviews {
            let entity = cachedReview(id: review.id)
            entity.id = review.id
            entity.bakerID = bakerID
            entity.customerID = review.customerID
            entity.customerName = review.customerName
            entity.customerImage = review.customerImage
            entity.rating = Int16(review.rating)
            entity.comment = review.comment
            entity.createdAt = review.createdAt
            entity.cachedAt = Date()
        }

        stack.saveIfNeeded()
    }

    func cachedCustomerProfiles(for customerIDs: Set<String>) -> [String: ReviewCustomerProfile] {
        guard !customerIDs.isEmpty else { return [:] }

        let request = NSFetchRequest<CachedCustomerProfileEntity>(entityName: "CachedCustomerProfile")
        request.predicate = NSPredicate(format: "userID IN %@", Array(customerIDs))

        do {
            return try stack.viewContext.fetch(request).reduce(into: [String: ReviewCustomerProfile]()) { result, entity in
                result[entity.userID] = ReviewCustomerProfile(
                    name: entity.name ?? "",
                    imageReference: entity.imageReference ?? ""
                )
            }
        } catch {
            print("Core Data cached customer profiles fetch failed: \(error.localizedDescription)")
            return [:]
        }
    }

    func cacheCustomerProfiles(_ profiles: [String: ReviewCustomerProfile]) {
        for (userID, profile) in profiles {
            let entity = cachedCustomerProfile(userID: userID)
            entity.userID = userID
            entity.name = profile.name
            entity.imageReference = profile.imageReference
            entity.cachedAt = Date()
        }

        stack.saveIfNeeded()
    }

    func cachedBakerPayments(for bakerID: String) -> [BakerPaymentDetailsRecord] {
        let request = NSFetchRequest<CachedBakerPaymentEntity>(entityName: "CachedBakerPayment")
        request.predicate = NSPredicate(format: "bakerID == %@", bakerID)
        request.sortDescriptors = [NSSortDescriptor(key: "paidAt", ascending: false)]

        do {
            return try stack.viewContext.fetch(request).map { entity in
                BakerPaymentDetailsRecord(
                    id: entity.id,
                    orderID: entity.orderID ?? "",
                    customerID: entity.customerID ?? "",
                    cakeName: entity.cakeName ?? "Cake Order",
                    customerName: entity.customerName ?? "Customer",
                    amount: entity.amount,
                    serviceFee: entity.serviceFee,
                    total: entity.total,
                    method: entity.method ?? "Card",
                    cardLast4: entity.cardLast4 ?? "",
                    status: entity.status ?? "success",
                    paidAt: entity.paidAt ?? Date()
                )
            }
        } catch {
            print("Core Data cached baker payments fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    func cacheBakerPayments(_ payments: [BakerPaymentDetailsRecord], for bakerID: String) {
        for payment in payments {
            let entity = cachedBakerPayment(id: payment.id)
            entity.id = payment.id
            entity.bakerID = bakerID
            entity.orderID = payment.orderID
            entity.customerID = payment.customerID
            entity.cakeName = payment.cakeName
            entity.customerName = payment.customerName
            entity.amount = payment.amount
            entity.serviceFee = payment.serviceFee
            entity.total = payment.total
            entity.method = payment.method
            entity.cardLast4 = payment.cardLast4
            entity.status = payment.status
            entity.paidAt = payment.paidAt
            entity.cachedAt = Date()
        }

        stack.saveIfNeeded()
    }

    private func cachedReview(id: String) -> CachedReviewEntity {
        if let existing = fetchSingleReview(id: id) {
            return existing
        }

        return CachedReviewEntity(context: stack.viewContext)
    }

    private func cachedCustomerProfile(userID: String) -> CachedCustomerProfileEntity {
        if let existing = fetchSingleCustomerProfile(userID: userID) {
            return existing
        }

        return CachedCustomerProfileEntity(context: stack.viewContext)
    }

    private func cachedBakerPayment(id: String) -> CachedBakerPaymentEntity {
        if let existing = fetchSingleBakerPayment(id: id) {
            return existing
        }

        return CachedBakerPaymentEntity(context: stack.viewContext)
    }

    private func fetchSingleReview(id: String) -> CachedReviewEntity? {
        let request = NSFetchRequest<CachedReviewEntity>(entityName: "CachedReview")
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        return try? stack.viewContext.fetch(request).first
    }

    private func fetchSingleCustomerProfile(userID: String) -> CachedCustomerProfileEntity? {
        let request = NSFetchRequest<CachedCustomerProfileEntity>(entityName: "CachedCustomerProfile")
        request.predicate = NSPredicate(format: "userID == %@", userID)
        request.fetchLimit = 1
        return try? stack.viewContext.fetch(request).first
    }

    private func fetchSingleBakerPayment(id: String) -> CachedBakerPaymentEntity? {
        let request = NSFetchRequest<CachedBakerPaymentEntity>(entityName: "CachedBakerPayment")
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        return try? stack.viewContext.fetch(request).first
    }
}

struct ReviewCustomerProfile {
    let name: String
    let imageReference: String
}
