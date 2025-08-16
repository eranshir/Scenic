import Foundation

struct SunSnapshot: Codable {
    let id: UUID
    var spotId: UUID
    var date: Date
    var sunriseUTC: Date?
    var sunsetUTC: Date?
    var goldenHourStartUTC: Date?
    var goldenHourEndUTC: Date?
    var blueHourStartUTC: Date?
    var blueHourEndUTC: Date?
    var closestEvent: SolarEvent?
    var relativeMinutesToEvent: Int?
    
    enum SolarEvent: String, Codable {
        case sunrise
        case sunset
        case goldenHourStart
        case goldenHourEnd
        case blueHourStart
        case blueHourEnd
        
        var displayName: String {
            switch self {
            case .sunrise: return "Sunrise"
            case .sunset: return "Sunset"
            case .goldenHourStart: return "Golden Hour Start"
            case .goldenHourEnd: return "Golden Hour End"
            case .blueHourStart: return "Blue Hour Start"
            case .blueHourEnd: return "Blue Hour End"
            }
        }
    }
    
    var isGoldenHour: Bool {
        guard let start = goldenHourStartUTC,
              let end = goldenHourEndUTC else { return false }
        let now = Date()
        return now >= start && now <= end
    }
    
    var isBlueHour: Bool {
        guard let start = blueHourStartUTC,
              let end = blueHourEndUTC else { return false }
        let now = Date()
        return now >= start && now <= end
    }
}