import Foundation
import CoreData

@objc(CDWeatherSnapshot)
public class CDWeatherSnapshot: NSManagedObject {
    
}

extension CDWeatherSnapshot {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDWeatherSnapshot> {
        return NSFetchRequest<CDWeatherSnapshot>(entityName: "CDWeatherSnapshot")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var timeUTC: Date
    @NSManaged public var source: String?
    @NSManaged public var temperatureCelsius: Double // Double.nan means nil
    @NSManaged public var windSpeedMPS: Double // Double.nan means nil
    @NSManaged public var cloudCoveragePercent: Int32 // -1 means nil
    @NSManaged public var precipitationMM: Double // Double.nan means nil
    @NSManaged public var visibilityMeters: Int32 // -1 means nil
    @NSManaged public var conditionCode: String?
    @NSManaged public var conditionDescription: String?
    @NSManaged public var humidity: Int32 // -1 means nil
    @NSManaged public var pressure: Double // Double.nan means nil
    
    // Relationships
    @NSManaged public var spot: CDSpot?
}

extension CDWeatherSnapshot {
    var temperatureCelsiusOptional: Double? {
        get {
            temperatureCelsius.isNaN ? nil : temperatureCelsius
        }
        set {
            temperatureCelsius = newValue ?? Double.nan
        }
    }
    
    var windSpeedMPSOptional: Double? {
        get {
            windSpeedMPS.isNaN ? nil : windSpeedMPS
        }
        set {
            windSpeedMPS = newValue ?? Double.nan
        }
    }
    
    var cloudCoveragePercentOptional: Int? {
        get {
            cloudCoveragePercent == -1 ? nil : Int(cloudCoveragePercent)
        }
        set {
            cloudCoveragePercent = Int32(newValue ?? -1)
        }
    }
    
    var precipitationMMOptional: Double? {
        get {
            precipitationMM.isNaN ? nil : precipitationMM
        }
        set {
            precipitationMM = newValue ?? Double.nan
        }
    }
    
    var visibilityMetersOptional: Int? {
        get {
            visibilityMeters == -1 ? nil : Int(visibilityMeters)
        }
        set {
            visibilityMeters = Int32(newValue ?? -1)
        }
    }
    
    var humidityOptional: Int? {
        get {
            humidity == -1 ? nil : Int(humidity)
        }
        set {
            humidity = Int32(newValue ?? -1)
        }
    }
    
    var pressureOptional: Double? {
        get {
            pressure.isNaN ? nil : pressure
        }
        set {
            pressure = newValue ?? Double.nan
        }
    }
    
    func toWeatherSnapshot() -> WeatherSnapshot {
        WeatherSnapshot(
            id: id,
            spotId: spot?.id ?? UUID(),
            timeUTC: timeUTC,
            source: source,
            temperatureCelsius: temperatureCelsiusOptional,
            windSpeedMPS: windSpeedMPSOptional,
            cloudCoveragePercent: cloudCoveragePercentOptional,
            precipitationMM: precipitationMMOptional,
            visibilityMeters: visibilityMetersOptional,
            conditionCode: conditionCode,
            conditionDescription: conditionDescription,
            humidity: humidityOptional,
            pressure: pressureOptional
        )
    }
    
    func updateFromWeatherSnapshot(_ weatherSnapshot: WeatherSnapshot) {
        id = weatherSnapshot.id
        timeUTC = weatherSnapshot.timeUTC
        source = weatherSnapshot.source
        temperatureCelsiusOptional = weatherSnapshot.temperatureCelsius
        windSpeedMPSOptional = weatherSnapshot.windSpeedMPS
        cloudCoveragePercentOptional = weatherSnapshot.cloudCoveragePercent
        precipitationMMOptional = weatherSnapshot.precipitationMM
        visibilityMetersOptional = weatherSnapshot.visibilityMeters
        conditionCode = weatherSnapshot.conditionCode
        conditionDescription = weatherSnapshot.conditionDescription
        humidityOptional = weatherSnapshot.humidity
        pressureOptional = weatherSnapshot.pressure
    }
    
    static func fromWeatherSnapshot(_ weatherSnapshot: WeatherSnapshot, in context: NSManagedObjectContext) -> CDWeatherSnapshot {
        let cdWeatherSnapshot = CDWeatherSnapshot(context: context)
        cdWeatherSnapshot.updateFromWeatherSnapshot(weatherSnapshot)
        return cdWeatherSnapshot
    }
}