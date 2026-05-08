import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(
            name: "CakeLabLocalStore",
            managedObjectModel: Self.makeManagedObjectModel()
        )

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        }

        container.persistentStoreDescriptions.forEach { description in
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }

        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Core Data failed to load: \(error.localizedDescription)")
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func saveIfNeeded() {
        let context = viewContext
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            context.rollback()
            print("Core Data save failed: \(error.localizedDescription)")
        }
    }
}

private extension CoreDataStack {
    static func makeManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.entities = [
            cachedReviewEntity(),
            cachedCustomerProfileEntity(),
            cachedBakerPaymentEntity()
        ]
        return model
    }

    static func cachedReviewEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "CachedReview"
        entity.managedObjectClassName = NSStringFromClass(CachedReviewEntity.self)
        entity.properties = [
            attribute("id", .stringAttributeType, isOptional: false),
            attribute("bakerID", .stringAttributeType, isOptional: false),
            attribute("customerID", .stringAttributeType, isOptional: false),
            attribute("customerName", .stringAttributeType),
            attribute("customerImage", .stringAttributeType),
            attribute("rating", .integer16AttributeType, defaultValue: 0),
            attribute("comment", .stringAttributeType),
            attribute("createdAt", .dateAttributeType),
            attribute("cachedAt", .dateAttributeType)
        ]
        return entity
    }

    static func cachedBakerPaymentEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "CachedBakerPayment"
        entity.managedObjectClassName = NSStringFromClass(CachedBakerPaymentEntity.self)
        entity.properties = [
            attribute("id", .stringAttributeType, isOptional: false),
            attribute("bakerID", .stringAttributeType, isOptional: false),
            attribute("orderID", .stringAttributeType),
            attribute("customerID", .stringAttributeType),
            attribute("cakeName", .stringAttributeType),
            attribute("customerName", .stringAttributeType),
            attribute("amount", .doubleAttributeType, defaultValue: 0),
            attribute("serviceFee", .doubleAttributeType, defaultValue: 0),
            attribute("total", .doubleAttributeType, defaultValue: 0),
            attribute("method", .stringAttributeType),
            attribute("cardLast4", .stringAttributeType),
            attribute("status", .stringAttributeType),
            attribute("paidAt", .dateAttributeType),
            attribute("cachedAt", .dateAttributeType)
        ]
        return entity
    }

    static func cachedCustomerProfileEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "CachedCustomerProfile"
        entity.managedObjectClassName = NSStringFromClass(CachedCustomerProfileEntity.self)
        entity.properties = [
            attribute("userID", .stringAttributeType, isOptional: false),
            attribute("name", .stringAttributeType),
            attribute("imageReference", .stringAttributeType),
            attribute("cachedAt", .dateAttributeType)
        ]
        return entity
    }

    static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        isOptional: Bool = true,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = isOptional
        attribute.defaultValue = defaultValue
        return attribute
    }
}

@objc(CachedReviewEntity)
final class CachedReviewEntity: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var bakerID: String
    @NSManaged var customerID: String
    @NSManaged var customerName: String?
    @NSManaged var customerImage: String?
    @NSManaged var rating: Int16
    @NSManaged var comment: String?
    @NSManaged var createdAt: Date?
    @NSManaged var cachedAt: Date?
}

@objc(CachedCustomerProfileEntity)
final class CachedCustomerProfileEntity: NSManagedObject {
    @NSManaged var userID: String
    @NSManaged var name: String?
    @NSManaged var imageReference: String?
    @NSManaged var cachedAt: Date?
}

@objc(CachedBakerPaymentEntity)
final class CachedBakerPaymentEntity: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var bakerID: String
    @NSManaged var orderID: String?
    @NSManaged var customerID: String?
    @NSManaged var cakeName: String?
    @NSManaged var customerName: String?
    @NSManaged var amount: Double
    @NSManaged var serviceFee: Double
    @NSManaged var total: Double
    @NSManaged var method: String?
    @NSManaged var cardLast4: String?
    @NSManaged var status: String?
    @NSManaged var paidAt: Date?
    @NSManaged var cachedAt: Date?
}
