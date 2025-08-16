import Foundation
import CoreData
import CoreLocation

extension CDAccessInfo {
    
    func toAccessInfo() -> AccessInfo {
        let parkingLocation = (self.parkingLatitude != 0 || self.parkingLongitude != 0) ? 
            CLLocationCoordinate2D(latitude: self.parkingLatitude, longitude: self.parkingLongitude) : nil
        
        return AccessInfo(
            id: self.id,
            spotId: self.spot?.id ?? UUID(),
            parkingLocation: parkingLocation,
            routePolyline: self.routePolyline,
            routeDistanceMeters: nil,
            routeElevationGainMeters: nil,
            routeDifficulty: nil,
            hazards: parseStringArray(self.hazardsString),
            fees: parseStringArray(self.feesString),
            notes: self.accessNotes,
            estimatedHikingTimeMinutes: self.estimatedWalkingMinutes == -1 ? nil : Int(self.estimatedWalkingMinutes)
        )
    }
    
    static func fromAccessInfo(_ accessInfo: AccessInfo, in context: NSManagedObjectContext) -> CDAccessInfo {
        let cdAccessInfo = CDAccessInfo(context: context)
        cdAccessInfo.updateFromAccessInfo(accessInfo)
        return cdAccessInfo
    }
    
    func updateFromAccessInfo(_ accessInfo: AccessInfo) {
        self.id = accessInfo.id
        
        if let parking = accessInfo.parkingLocation {
            self.parkingLatitude = parking.latitude
            self.parkingLongitude = parking.longitude
        } else {
            self.parkingLatitude = 0
            self.parkingLongitude = 0
        }
        
        self.routePolyline = accessInfo.routePolyline
        self.hazardsString = encodeStringArray(accessInfo.hazards)
        self.feesString = encodeStringArray(accessInfo.fees)
        self.accessNotes = accessInfo.notes
        self.estimatedWalkingMinutes = Int16(accessInfo.estimatedHikingTimeMinutes ?? -1)
    }
    
    private func parseStringArray(_ string: String) -> [String] {
        guard let data = string.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }
    
    private func encodeStringArray(_ array: [String]) -> String {
        guard let data = try? JSONEncoder().encode(array),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}