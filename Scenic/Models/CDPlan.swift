import Foundation
import CoreData

@objc(CDPlan)
public class CDPlan: NSManagedObject {
    
}

extension CDPlan {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDPlan> {
        return NSFetchRequest<CDPlan>(entityName: "CDPlan")
    }
    
    // Basic Properties
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var description_: String?
    @NSManaged public var createdBy: UUID
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var isPublic: Bool
    @NSManaged public var originalPlanId: UUID?
    @NSManaged public var estimatedDuration: Int32 // -1 means nil
    @NSManaged public var startDate: Date?
    @NSManaged public var endDate: Date?
    
    // Server Sync Properties
    @NSManaged public var serverPlanId: String? // nil if not published to server
    @NSManaged public var lastSynced: Date?
    
    // Relationships
    @NSManaged public var items: NSSet?
}

// MARK: - Computed Properties
extension CDPlan {
    var estimatedDurationOptional: Int? {
        get {
            estimatedDuration == -1 ? nil : Int(estimatedDuration)
        }
        set {
            estimatedDuration = Int32(newValue ?? -1)
        }
    }
    
    var planDescription: String? {
        get {
            description_
        }
        set {
            description_ = newValue
        }
    }
    
    var itemsArray: [CDPlanItem] {
        (items?.allObjects as? [CDPlanItem])?.sorted { $0.orderIndex < $1.orderIndex } ?? []
    }
}

// MARK: - Core Data Generated accessors for items
extension CDPlan {
    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: CDPlanItem)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: CDPlanItem)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)
}

// MARK: - Conversion Methods
extension CDPlan {
    func toPlan() -> Plan {
        return Plan(
            id: id,
            title: title,
            description: planDescription,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isPublic: isPublic,
            originalPlanId: originalPlanId,
            estimatedDuration: estimatedDurationOptional,
            startDate: startDate,
            endDate: endDate,
            items: itemsArray.map { $0.toPlanItem() }
        )
    }
    
    func updateFromPlan(_ plan: Plan) {
        // Don't update id - that should never change
        title = plan.title
        planDescription = plan.description
        createdBy = plan.createdBy
        createdAt = plan.createdAt
        updatedAt = plan.updatedAt
        isPublic = plan.isPublic
        originalPlanId = plan.originalPlanId
        estimatedDurationOptional = plan.estimatedDuration
        startDate = plan.startDate
        endDate = plan.endDate
    }
    
    static func fromPlan(_ plan: Plan, in context: NSManagedObjectContext) -> CDPlan {
        let cdPlan = CDPlan(context: context)
        cdPlan.id = plan.id
        cdPlan.updateFromPlan(plan)
        return cdPlan
    }
}