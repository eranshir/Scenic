import Foundation
import CoreData

extension CDWeatherSnapshot {
    
    func toWeatherSnapshot() -> WeatherSnapshot {
        return WeatherSnapshot(
            id: self.id ?? UUID(),
            spotId: self.spot?.id ?? UUID(),
            timeUTC: self.timeUTC ?? Date(),
            temperatureCelsius: self.temperatureCelsius == 0 ? nil : self.temperatureCelsius,
            humidity: self.humidity == -1 ? nil : Int(self.humidity),
            precipitationMM: self.precipitationMM == 0 ? nil : self.precipitationMM,
            windSpeedMPS: self.windSpeedMPS == 0 ? nil : self.windSpeedMPS,
            pressure: self.pressure == 0 ? nil : self.pressure,
            visibilityMeters: self.visibilityMeters == -1 ? nil : Int(self.visibilityMeters),
            cloudCoveragePercent: self.cloudCoveragePercent == -1 ? nil : Int(self.cloudCoveragePercent),
            conditionCode: self.conditionCode,
            conditionDescription: self.conditionDescription,
            source: self.source ?? "unknown"
        )
    }
    
    static func fromWeatherSnapshot(_ weatherSnapshot: WeatherSnapshot, in context: NSManagedObjectContext) -> CDWeatherSnapshot {
        let cdWeatherSnapshot = CDWeatherSnapshot(context: context)
        cdWeatherSnapshot.updateFromWeatherSnapshot(weatherSnapshot)
        return cdWeatherSnapshot
    }
    
    func updateFromWeatherSnapshot(_ weatherSnapshot: WeatherSnapshot) {
        self.id = weatherSnapshot.id
        self.timeUTC = weatherSnapshot.timeUTC
        self.temperatureCelsius = weatherSnapshot.temperatureCelsius ?? 0
        self.humidity = Int32(weatherSnapshot.humidity ?? -1)
        self.precipitationMM = weatherSnapshot.precipitationMM ?? 0
        self.windSpeedMPS = weatherSnapshot.windSpeedMPS ?? 0
        self.pressure = weatherSnapshot.pressure ?? 0
        self.visibilityMeters = Int32(weatherSnapshot.visibilityMeters ?? -1)
        self.cloudCoveragePercent = Int32(weatherSnapshot.cloudCoveragePercent ?? -1)
        self.conditionCode = weatherSnapshot.conditionCode
        self.conditionDescription = weatherSnapshot.conditionDescription
        self.source = weatherSnapshot.source
    }
}