import Foundation
import CoreData
import CoreLocation

extension CDSpot {
    
    func toSpot() -> Spot {
        // Load media from CoreData relationship
        print("🔍 CDSpot.toSpot() - Converting spot '\(self.title ?? "Unknown")' with media count: \(self.media?.count ?? 0)")
        let mediaArray: [Media] = (self.media?.allObjects as? [CDMedia])?.map { cdMedia in
            print("🎬 Converting CDMedia with URL: \(cdMedia.url ?? "no URL")")
            return cdMedia.toMedia()
        } ?? []
        print("✅ Converted to \(mediaArray.count) media items")
        
        return Spot(
            id: self.id ?? UUID(),
            title: self.title ?? "",
            location: CLLocationCoordinate2D(
                latitude: self.latitude,
                longitude: self.longitude
            ),
            headingDegrees: self.headingDegrees == -1 ? nil : Int(self.headingDegrees),
            elevationMeters: self.elevationMeters == -1 ? nil : Int(self.elevationMeters),
            subjectTags: parseTagsString(self.subjectTagsString ?? "[]"),
            difficulty: Spot.Difficulty(rawValue: Int(self.difficulty)) ?? .moderate,
            createdBy: self.createdBy ?? UUID(),
            privacy: Spot.Privacy(rawValue: self.privacy ?? "public") ?? .publicSpot,
            license: self.license ?? "CC-BY-NC",
            status: Spot.SpotStatus(rawValue: self.status ?? "active") ?? .active,
            createdAt: self.createdAt ?? Date(),
            updatedAt: self.updatedAt ?? Date(),
            country: self.country,
            countryCode: self.countryCode,
            administrativeArea: self.administrativeArea,
            subAdministrativeArea: self.subAdministrativeArea,
            locality: self.locality,
            subLocality: self.subLocality,
            thoroughfare: self.thoroughfare,
            subThoroughfare: self.subThoroughfare,
            postalCode: self.postalCode,
            locationName: self.locationName,
            areasOfInterest: decodeAreasOfInterest(self.areasOfInterestString),
            media: mediaArray,
            sunSnapshot: self.sunSnapshot?.toSunSnapshot(),
            weatherSnapshot: self.weatherSnapshot?.toWeatherSnapshot(),
            accessInfo: self.accessInfo?.toAccessInfo(),
            comments: [],
            voteCount: Int(self.voteCount)
        )
    }
    
    static func fromSpot(_ spot: Spot, in context: NSManagedObjectContext) -> CDSpot {
        let cdSpot = CDSpot(context: context)
        cdSpot.updateFromSpot(spot)
        return cdSpot
    }
    
    func updateFromSpot(_ spot: Spot) {
        self.id = spot.id
        self.title = spot.title
        self.latitude = spot.location.latitude
        self.longitude = spot.location.longitude
        self.headingDegrees = Int16(spot.headingDegrees ?? -1)
        self.elevationMeters = Int16(spot.elevationMeters ?? -1)
        self.subjectTagsString = encodeTagsArray(spot.subjectTags)
        self.difficulty = Int16(spot.difficulty.rawValue)
        self.createdBy = spot.createdBy
        self.privacy = spot.privacy.rawValue
        self.license = spot.license
        self.status = spot.status.rawValue
        self.createdAt = spot.createdAt
        self.updatedAt = spot.updatedAt
        self.voteCount = Int32(spot.voteCount)
        
        // Location metadata from reverse geocoding
        self.country = spot.country
        self.countryCode = spot.countryCode
        self.administrativeArea = spot.administrativeArea
        self.subAdministrativeArea = spot.subAdministrativeArea
        self.locality = spot.locality
        self.subLocality = spot.subLocality
        self.thoroughfare = spot.thoroughfare
        self.subThoroughfare = spot.subThoroughfare
        self.postalCode = spot.postalCode
        self.locationName = spot.locationName
        self.areasOfInterestString = encodeAreasOfInterest(spot.areasOfInterest)
        
        // Local-first properties
        if self.isLocalOnly == false {
            // This is a server spot, preserve cache settings
        } else {
            self.isLocalOnly = true
            self.isPublished = false
        }
    }
    
    private func parseTagsString(_ tagsString: String) -> [String] {
        guard let data = tagsString.data(using: .utf8),
              let tags = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return tags
    }
    
    private func encodeTagsArray(_ tags: [String]) -> String {
        guard let data = try? JSONEncoder().encode(tags),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
    
    private func encodeAreasOfInterest(_ areas: [String]?) -> String? {
        guard let areas = areas, !areas.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(areas),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
    
    private func decodeAreasOfInterest(_ areasString: String?) -> [String]? {
        guard let areasString = areasString,
              !areasString.isEmpty,
              let data = areasString.data(using: .utf8),
              let areas = try? JSONDecoder().decode([String].self, from: data),
              !areas.isEmpty else {
            return nil
        }
        return areas
    }
}