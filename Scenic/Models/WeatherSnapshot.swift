import Foundation

struct WeatherSnapshot: Codable {
    let id: UUID
    var spotId: UUID
    var timeUTC: Date
    var source: String?
    var temperatureCelsius: Double?
    var windSpeedMPS: Double?
    var cloudCoveragePercent: Int?
    var precipitationMM: Double?
    var visibilityMeters: Int?
    var conditionCode: String?
    var conditionDescription: String?
    var humidity: Int?
    var pressure: Double?
    
    var temperatureFahrenheit: Double? {
        guard let celsius = temperatureCelsius else { return nil }
        return celsius * 9/5 + 32
    }
    
    var windSpeedMPH: Double? {
        guard let mps = windSpeedMPS else { return nil }
        return mps * 2.237
    }
    
    var weatherIcon: String {
        guard let code = conditionCode else { return "questionmark.circle" }
        switch code {
        case "clear": return "sun.max.fill"
        case "partly_cloudy": return "cloud.sun.fill"
        case "cloudy": return "cloud.fill"
        case "overcast": return "smoke.fill"
        case "rain": return "cloud.rain.fill"
        case "snow": return "cloud.snow.fill"
        case "fog": return "cloud.fog.fill"
        case "thunderstorm": return "cloud.bolt.rain.fill"
        default: return "cloud"
        }
    }
}