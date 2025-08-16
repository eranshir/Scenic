import Foundation
import CoreData
import CoreLocation

@objc(CDAccessInfo)
public class CDAccessInfo: NSManagedObject {
    
}

extension CDAccessInfo {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDAccessInfo> {
        return NSFetchRequest<CDAccessInfo>(entityName: "CDAccessInfo")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var parkingLatitude: Double // NaN means nil
    @NSManaged public var parkingLongitude: Double // NaN means nil
    @NSManaged public var routePolyline: String?
    @NSManaged public var hazardsString: String // JSON encoded array
    @NSManaged public var feesString: String // JSON encoded array
    @NSManaged public var accessNotes: String?
    @NSManaged public var estimatedWalkingMinutes: Int16 // -1 means nil
    
    // Relationships
    @NSManaged public var spot: CDSpot?
}

extension CDAccessInfo {
    var parkingLocation: CLLocationCoordinate2D? {
        get {
            guard !parkingLatitude.isNaN && !parkingLongitude.isNaN else { return nil }
            return CLLocationCoordinate2D(latitude: parkingLatitude, longitude: parkingLongitude)
        }
        set {
            if let location = newValue {
                parkingLatitude = location.latitude
                parkingLongitude = location.longitude
            } else {
                parkingLatitude = Double.nan
                parkingLongitude = Double.nan
            }
        }
    }
    
    var estimatedWalkingMinutesOptional: Int? {
        get {
            estimatedWalkingMinutes == -1 ? nil : Int(estimatedWalkingMinutes)
        }
        set {
            estimatedWalkingMinutes = Int16(newValue ?? -1)
        }
    }
    
    var hazards: [String] {
        get {
            guard !hazardsString.isEmpty,
                  let data = hazardsString.data(using: .utf8),
                  let hazards = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return hazards
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                hazardsString = string
            } else {
                hazardsString = "[]"
            }
        }
    }
    
    var fees: [String] {
        get {
            guard !feesString.isEmpty,
                  let data = feesString.data(using: .utf8),
                  let fees = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return fees
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                feesString = string
            } else {
                feesString = "[]"
            }
        }
    }
    
    
    
}