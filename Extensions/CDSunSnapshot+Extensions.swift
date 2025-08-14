import Foundation
import CoreData

extension CDSunSnapshot {
    
    func toSunSnapshot() -> SunSnapshot {
        return SunSnapshot(
            id: self.id ?? UUID(),
            spotId: self.spot?.id ?? UUID(),
            date: self.date ?? Date(),
            sunriseUTC: self.sunriseUTC,
            sunsetUTC: self.sunsetUTC,
            goldenHourStartUTC: self.goldenHourStartUTC,
            goldenHourEndUTC: self.goldenHourEndUTC,
            blueHourStartUTC: self.blueHourStartUTC,
            blueHourEndUTC: self.blueHourEndUTC,
            closestEvent: self.closestEventString.flatMap { SunSnapshot.SolarEvent(rawValue: $0) },
            relativeMinutesToEvent: self.relativeMinutesToEvent == Int32(Int.max) ? nil : Int(self.relativeMinutesToEvent)
        )
    }
    
    static func fromSunSnapshot(_ sunSnapshot: SunSnapshot, in context: NSManagedObjectContext) -> CDSunSnapshot {
        let cdSunSnapshot = CDSunSnapshot(context: context)
        cdSunSnapshot.updateFromSunSnapshot(sunSnapshot)
        return cdSunSnapshot
    }
    
    func updateFromSunSnapshot(_ sunSnapshot: SunSnapshot) {
        self.id = sunSnapshot.id
        self.date = sunSnapshot.date
        self.sunriseUTC = sunSnapshot.sunriseUTC
        self.sunsetUTC = sunSnapshot.sunsetUTC
        self.goldenHourStartUTC = sunSnapshot.goldenHourStartUTC
        self.goldenHourEndUTC = sunSnapshot.goldenHourEndUTC
        self.blueHourStartUTC = sunSnapshot.blueHourStartUTC
        self.blueHourEndUTC = sunSnapshot.blueHourEndUTC
        self.closestEventString = sunSnapshot.closestEvent?.rawValue
        self.relativeMinutesToEvent = Int32(sunSnapshot.relativeMinutesToEvent ?? Int.max)
    }
}