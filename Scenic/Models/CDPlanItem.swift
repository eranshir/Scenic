import Foundation
import CoreData

@objc(CDPlanItem)
public class CDPlanItem: NSManagedObject {
    
}

extension CDPlanItem {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDPlanItem> {
        return NSFetchRequest<CDPlanItem>(entityName: "CDPlanItem")
    }
    
    // Basic Properties
    @NSManaged public var id: UUID
    @NSManaged public var type: String
    @NSManaged public var orderIndex: Int32
    @NSManaged public var scheduledDate: Date?
    @NSManaged public var scheduledStartTime: Date?
    @NSManaged public var scheduledEndTime: Date?
    @NSManaged public var timingPreference: String?
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date
    
    // Item Type Specific Properties
    @NSManaged public var spotId: UUID? // For spot items
    @NSManaged public var poiDataJSON: String? // For POI items (accommodation, restaurant, attraction)
    
    // Server Sync Properties
    @NSManaged public var serverPlanItemId: String? // nil if not published to server
    @NSManaged public var lastSynced: Date?
    
    // Relationships
    @NSManaged public var plan: CDPlan
    @NSManaged public var spot: CDSpot? // Only populated when type is "spot"
}

// MARK: - Computed Properties
extension CDPlanItem {
    var typeEnum: PlanItemType {
        get {
            PlanItemType(rawValue: type) ?? .spot
        }
        set {
            type = newValue.rawValue
        }
    }
    
    var timingPreferenceEnum: TimingPreference? {
        get {
            guard let timingPreference = timingPreference else { return nil }
            return TimingPreference(rawValue: timingPreference)
        }
        set {
            timingPreference = newValue?.rawValue
        }
    }
    
    var poiData: POIData? {
        get {
            guard let json = poiDataJSON,
                  let data = json.data(using: .utf8),
                  let poi = try? JSONDecoder().decode(POIData.self, from: data) else {
                return nil
            }
            return poi
        }
        set {
            if let newValue = newValue,
               let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                poiDataJSON = json
            } else {
                poiDataJSON = nil
            }
        }
    }
}

// MARK: - Conversion Methods
extension CDPlanItem {
    func toPlanItem() -> PlanItem {
        return PlanItem(
            id: id,
            planId: plan.id,
            type: typeEnum,
            orderIndex: Int(orderIndex),
            scheduledDate: scheduledDate,
            scheduledStartTime: scheduledStartTime,
            scheduledEndTime: scheduledEndTime,
            timingPreference: timingPreferenceEnum,
            spotId: spotId,
            spot: spot?.toSpot(),
            poiData: poiData,
            notes: notes,
            createdAt: createdAt
        )
    }
    
    func updateFromPlanItem(_ planItem: PlanItem) {
        // Don't update id or planId - those should never change
        typeEnum = planItem.type
        orderIndex = Int32(planItem.orderIndex)
        scheduledDate = planItem.scheduledDate
        scheduledStartTime = planItem.scheduledStartTime
        scheduledEndTime = planItem.scheduledEndTime
        timingPreferenceEnum = planItem.timingPreference
        spotId = planItem.spotId
        poiData = planItem.poiData
        notes = planItem.notes
        createdAt = planItem.createdAt
    }
    
    static func fromPlanItem(_ planItem: PlanItem, plan: CDPlan, in context: NSManagedObjectContext) -> CDPlanItem {
        let cdPlanItem = CDPlanItem(context: context)
        cdPlanItem.id = planItem.id
        cdPlanItem.plan = plan
        cdPlanItem.updateFromPlanItem(planItem)
        return cdPlanItem
    }
}