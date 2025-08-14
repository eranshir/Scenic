import Foundation
import CoreData

@objc(CDSunSnapshot)
public class CDSunSnapshot: NSManagedObject {
    
}

extension CDSunSnapshot {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDSunSnapshot> {
        return NSFetchRequest<CDSunSnapshot>(entityName: "CDSunSnapshot")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var date: Date
    @NSManaged public var sunriseUTC: Date?
    @NSManaged public var sunsetUTC: Date?
    @NSManaged public var goldenHourStartUTC: Date?
    @NSManaged public var goldenHourEndUTC: Date?
    @NSManaged public var blueHourStartUTC: Date?
    @NSManaged public var blueHourEndUTC: Date?
    @NSManaged public var closestEventString: String?
    @NSManaged public var relativeMinutesToEvent: Int32 // Int32.max means nil
    
    // Relationships
    @NSManaged public var spot: CDSpot?
}

extension CDSunSnapshot {
    var closestEvent: SunSnapshot.SolarEvent? {
        get {
            guard let eventString = closestEventString else { return nil }
            return SunSnapshot.SolarEvent(rawValue: eventString)
        }
        set {
            closestEventString = newValue?.rawValue
        }
    }
    
    var relativeMinutesToEventOptional: Int? {
        get {
            relativeMinutesToEvent == Int32.max ? nil : Int(relativeMinutesToEvent)
        }
        set {
            relativeMinutesToEvent = Int32(newValue ?? Int32.max)
        }
    }
    
    func toSunSnapshot() -> SunSnapshot {
        SunSnapshot(
            id: id,
            spotId: spot?.id ?? UUID(),
            date: date,
            sunriseUTC: sunriseUTC,
            sunsetUTC: sunsetUTC,
            goldenHourStartUTC: goldenHourStartUTC,
            goldenHourEndUTC: goldenHourEndUTC,
            blueHourStartUTC: blueHourStartUTC,
            blueHourEndUTC: blueHourEndUTC,
            closestEvent: closestEvent,
            relativeMinutesToEvent: relativeMinutesToEventOptional
        )
    }
    
    func updateFromSunSnapshot(_ sunSnapshot: SunSnapshot) {
        id = sunSnapshot.id
        date = sunSnapshot.date
        sunriseUTC = sunSnapshot.sunriseUTC
        sunsetUTC = sunSnapshot.sunsetUTC
        goldenHourStartUTC = sunSnapshot.goldenHourStartUTC
        goldenHourEndUTC = sunSnapshot.goldenHourEndUTC
        blueHourStartUTC = sunSnapshot.blueHourStartUTC
        blueHourEndUTC = sunSnapshot.blueHourEndUTC
        closestEvent = sunSnapshot.closestEvent
        relativeMinutesToEventOptional = sunSnapshot.relativeMinutesToEvent
    }
    
    static func fromSunSnapshot(_ sunSnapshot: SunSnapshot, in context: NSManagedObjectContext) -> CDSunSnapshot {
        let cdSunSnapshot = CDSunSnapshot(context: context)
        cdSunSnapshot.updateFromSunSnapshot(sunSnapshot)
        return cdSunSnapshot
    }
}