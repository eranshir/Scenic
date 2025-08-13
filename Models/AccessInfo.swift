import Foundation
import CoreLocation

struct AccessInfo: Codable {
    let id: UUID
    var spotId: UUID
    var parkingLocation: CLLocationCoordinate2D?
    var routePolyline: String?
    var routeDistanceMeters: Int?
    var routeElevationGainMeters: Int?
    var routeDifficulty: Spot.Difficulty?
    var hazards: [String]
    var fees: [String]
    var notes: String?
    var estimatedHikingTimeMinutes: Int?
    
    var routeDistanceMiles: Double? {
        guard let meters = routeDistanceMeters else { return nil }
        return Double(meters) / 1609.34
    }
    
    var routeElevationGainFeet: Double? {
        guard let meters = routeElevationGainMeters else { return nil }
        return Double(meters) * 3.281
    }
    
    var formattedHikingTime: String? {
        guard let minutes = estimatedHikingTimeMinutes else { return nil }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}