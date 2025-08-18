import Foundation
import CoreData
import CoreLocation

@objc(CDSpot)
public class CDSpot: NSManagedObject {
    
}

extension CDSpot {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDSpot> {
        return NSFetchRequest<CDSpot>(entityName: "CDSpot")
    }
    
    // Basic Properties
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    
    // Sync Properties (need to be added to Core Data model in Xcode)
    // @NSManaged public var remoteId: UUID?
    // @NSManaged public var syncedAt: Date?
    @NSManaged public var headingDegrees: Int16 // -1 means nil
    @NSManaged public var elevationMeters: Int16 // -1 means nil
    @NSManaged public var difficulty: Int16
    @NSManaged public var privacy: String
    @NSManaged public var license: String
    @NSManaged public var status: String
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var subjectTagsString: String // JSON encoded array
    
    // Location metadata from reverse geocoding
    @NSManaged public var country: String?
    @NSManaged public var countryCode: String?
    @NSManaged public var administrativeArea: String?
    @NSManaged public var subAdministrativeArea: String?
    @NSManaged public var locality: String?
    @NSManaged public var subLocality: String?
    @NSManaged public var thoroughfare: String?
    @NSManaged public var subThoroughfare: String?
    @NSManaged public var postalCode: String?
    @NSManaged public var locationName: String?
    @NSManaged public var areasOfInterestString: String?
    
    // Server Sync Properties
    @NSManaged public var serverSpotId: String? // nil if not published to server
    @NSManaged public var isPublished: Bool
    @NSManaged public var lastSynced: Date?
    @NSManaged public var cacheExpiry: Date?
    @NSManaged public var isLocalOnly: Bool // true for user's own spots, false for cached server spots
    
    // User Properties
    @NSManaged public var createdBy: UUID
    @NSManaged public var voteCount: Int32
    
    // Relationships
    @NSManaged public var media: NSSet?
    @NSManaged public var sunSnapshot: CDSunSnapshot?
    @NSManaged public var weatherSnapshot: CDWeatherSnapshot?
    @NSManaged public var accessInfo: CDAccessInfo?
    @NSManaged public var comments: NSSet?
}

// MARK: - Computed Properties
extension CDSpot {
    var location: CLLocationCoordinate2D {
        get {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }
    
    var headingDegreesOptional: Int? {
        get {
            headingDegrees == -1 ? nil : Int(headingDegrees)
        }
        set {
            headingDegrees = Int16(newValue ?? -1)
        }
    }
    
    var elevationMetersOptional: Int? {
        get {
            elevationMeters == -1 ? nil : Int(elevationMeters)
        }
        set {
            elevationMeters = Int16(newValue ?? -1)
        }
    }
    
    var subjectTags: [String] {
        get {
            guard !subjectTagsString.isEmpty,
                  let data = subjectTagsString.data(using: .utf8),
                  let tags = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return tags
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                subjectTagsString = string
            } else {
                subjectTagsString = "[]"
            }
        }
    }
    
    var areasOfInterest: [String]? {
        get {
            guard let areasString = areasOfInterestString,
                  !areasString.isEmpty,
                  let data = areasString.data(using: .utf8),
                  let areas = try? JSONDecoder().decode([String].self, from: data) else {
                return nil
            }
            return areas.isEmpty ? nil : areas
        }
        set {
            if let newValue = newValue,
               !newValue.isEmpty,
               let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                areasOfInterestString = string
            } else {
                areasOfInterestString = nil
            }
        }
    }
    
    var difficultyEnum: Spot.Difficulty {
        get {
            Spot.Difficulty(rawValue: Int(difficulty)) ?? .moderate
        }
        set {
            difficulty = Int16(newValue.rawValue)
        }
    }
    
    var privacyEnum: Spot.Privacy {
        get {
            Spot.Privacy(rawValue: privacy) ?? .publicSpot
        }
        set {
            privacy = newValue.rawValue
        }
    }
    
    var statusEnum: Spot.SpotStatus {
        get {
            Spot.SpotStatus(rawValue: status) ?? .active
        }
        set {
            status = newValue.rawValue
        }
    }
    
    var mediaArray: [CDMedia] {
        (media?.allObjects as? [CDMedia]) ?? []
    }
    
    var commentsArray: [CDComment] {
        (comments?.allObjects as? [CDComment]) ?? []
    }
}

// MARK: - Core Data Generated accessors for media
extension CDSpot {
    @objc(addMediaObject:)
    @NSManaged public func addToMedia(_ value: CDMedia)

    @objc(removeMediaObject:)
    @NSManaged public func removeFromMedia(_ value: CDMedia)

    @objc(addMedia:)
    @NSManaged public func addToMedia(_ values: NSSet)

    @objc(removeMedia:)
    @NSManaged public func removeFromMedia(_ values: NSSet)
}

// MARK: - Core Data Generated accessors for comments
extension CDSpot {
    @objc(addCommentsObject:)
    @NSManaged public func addToComments(_ value: CDComment)

    @objc(removeCommentsObject:)
    @NSManaged public func removeFromComments(_ value: CDComment)

    @objc(addComments:)
    @NSManaged public func addToComments(_ values: NSSet)

    @objc(removeComments:)
    @NSManaged public func removeFromComments(_ values: NSSet)
}

// MARK: - Conversion Methods
extension CDSpot {
    func toSpot() -> Spot {
        // Debug: Check CoreData location fields for Palo Alto
        if title.contains("Palo Alto") {
            print("🗺️ DEBUG: CDSpot.toSpot() - Raw CoreData values for '\(title)':")
            print("  CDSpot.country: '\(country ?? "nil")'")
            print("  CDSpot.countryCode: '\(countryCode ?? "nil")'")
            print("  CDSpot.administrativeArea: '\(administrativeArea ?? "nil")'")
            print("  CDSpot.locality: '\(locality ?? "nil")'")
            print("  CDSpot.locationName: '\(locationName ?? "nil")'")
        }
        
        return Spot(
            id: id,
            title: title,
            location: location,
            headingDegrees: headingDegreesOptional,
            elevationMeters: elevationMetersOptional,
            subjectTags: subjectTags,
            difficulty: difficultyEnum,
            createdBy: createdBy,
            privacy: privacyEnum,
            license: license,
            status: statusEnum,
            createdAt: createdAt,
            updatedAt: updatedAt,
            country: country,
            countryCode: countryCode,
            administrativeArea: administrativeArea,
            subAdministrativeArea: subAdministrativeArea,
            locality: locality,
            subLocality: subLocality,
            thoroughfare: thoroughfare,
            subThoroughfare: subThoroughfare,
            postalCode: postalCode,
            locationName: locationName,
            areasOfInterest: areasOfInterest,
            media: mediaArray.map { $0.toMedia() },
            sunSnapshot: sunSnapshot?.toSunSnapshot(),
            weatherSnapshot: weatherSnapshot?.toWeatherSnapshot(),
            accessInfo: accessInfo?.toAccessInfo(),
            comments: commentsArray.map { $0.toComment() },
            voteCount: Int(voteCount)
        )
    }
    
    func updateFromSpot(_ spot: Spot) {
        // Don't update id - that should never change
        title = spot.title
        location = spot.location
        headingDegreesOptional = spot.headingDegrees
        elevationMetersOptional = spot.elevationMeters
        subjectTags = spot.subjectTags
        difficultyEnum = spot.difficulty
        createdBy = spot.createdBy
        privacyEnum = spot.privacy
        license = spot.license
        statusEnum = spot.status
        createdAt = spot.createdAt
        updatedAt = spot.updatedAt
        
        // Location metadata from reverse geocoding
        country = spot.country
        countryCode = spot.countryCode
        administrativeArea = spot.administrativeArea
        subAdministrativeArea = spot.subAdministrativeArea
        locality = spot.locality
        subLocality = spot.subLocality
        thoroughfare = spot.thoroughfare
        subThoroughfare = spot.subThoroughfare
        postalCode = spot.postalCode
        locationName = spot.locationName
        areasOfInterest = spot.areasOfInterest
        voteCount = Int32(spot.voteCount)
        
    }
    
    static func fromSpot(_ spot: Spot, in context: NSManagedObjectContext) -> CDSpot {
        let cdSpot = CDSpot(context: context)
        cdSpot.id = spot.id
        cdSpot.updateFromSpot(spot)
        cdSpot.isLocalOnly = true
        cdSpot.isPublished = false
        return cdSpot
    }
}