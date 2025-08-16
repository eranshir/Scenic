import Foundation
import CoreData

@objc(CDMedia)
public class CDMedia: NSManagedObject {
    
}

extension CDMedia {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDMedia> {
        return NSFetchRequest<CDMedia>(entityName: "CDMedia")
    }
    
    // Basic Properties
    @NSManaged public var id: UUID
    @NSManaged public var userId: UUID
    @NSManaged public var type: String
    @NSManaged public var url: String
    @NSManaged public var thumbnailUrl: String?
    @NSManaged public var captureTimeUTC: Date?
    @NSManaged public var device: String?
    @NSManaged public var lens: String?
    @NSManaged public var focalLengthMM: Float // -1 means nil
    @NSManaged public var aperture: Float // -1 means nil
    @NSManaged public var shutterSpeed: String?
    @NSManaged public var iso: Int32 // -1 means nil
    @NSManaged public var resolutionWidth: Int32 // -1 means nil
    @NSManaged public var resolutionHeight: Int32 // -1 means nil
    @NSManaged public var presetsString: String // JSON encoded array
    @NSManaged public var filtersString: String // JSON encoded array
    @NSManaged public var headingFromExif: Bool
    @NSManaged public var originalFilename: String?
    @NSManaged public var createdAt: Date
    
    // EXIF Data (embedded)
    @NSManaged public var exifMake: String?
    @NSManaged public var exifModel: String?
    @NSManaged public var exifLens: String?
    @NSManaged public var exifFocalLength: Float // -1 means nil
    @NSManaged public var exifFNumber: Float // -1 means nil
    @NSManaged public var exifExposureTime: String?
    @NSManaged public var exifIso: Int32 // -1 means nil
    @NSManaged public var exifDateTimeOriginal: Date?
    @NSManaged public var exifGpsLatitude: Double // NaN means nil
    @NSManaged public var exifGpsLongitude: Double // NaN means nil
    @NSManaged public var exifGpsAltitude: Double // NaN means nil
    @NSManaged public var exifGpsDirection: Float // -1 means nil
    @NSManaged public var exifWidth: Int32 // -1 means nil
    @NSManaged public var exifHeight: Int32 // -1 means nil
    @NSManaged public var exifColorSpace: String?
    @NSManaged public var exifSoftware: String?
    
    // Server Sync Properties
    @NSManaged public var serverMediaId: String?
    @NSManaged public var localFilePath: String? // Path to locally cached file
    @NSManaged public var isDownloaded: Bool // Whether full resolution is cached locally
    @NSManaged public var thumbnailDownloaded: Bool // Whether thumbnail is cached locally
    @NSManaged public var lastSynced: Date?
    
    // Relationships
    @NSManaged public var spot: CDSpot?
}

// MARK: - Computed Properties
extension CDMedia {
    var mediaType: Media.MediaType {
        get {
            Media.MediaType(rawValue: type) ?? .photo
        }
        set {
            type = newValue.rawValue
        }
    }
    
    var focalLengthMMOptional: Float? {
        get {
            focalLengthMM == -1 ? nil : focalLengthMM
        }
        set {
            focalLengthMM = newValue ?? -1
        }
    }
    
    var apertureOptional: Float? {
        get {
            aperture == -1 ? nil : aperture
        }
        set {
            aperture = newValue ?? -1
        }
    }
    
    var isoOptional: Int? {
        get {
            iso == -1 ? nil : Int(iso)
        }
        set {
            iso = Int32(newValue ?? -1)
        }
    }
    
    var resolutionWidthOptional: Int? {
        get {
            resolutionWidth == -1 ? nil : Int(resolutionWidth)
        }
        set {
            resolutionWidth = Int32(newValue ?? -1)
        }
    }
    
    var resolutionHeightOptional: Int? {
        get {
            resolutionHeight == -1 ? nil : Int(resolutionHeight)
        }
        set {
            resolutionHeight = Int32(newValue ?? -1)
        }
    }
    
    var presets: [String] {
        get {
            guard !presetsString.isEmpty,
                  let data = presetsString.data(using: .utf8),
                  let presets = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return presets
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                presetsString = string
            } else {
                presetsString = "[]"
            }
        }
    }
    
    var filters: [String] {
        get {
            guard !filtersString.isEmpty,
                  let data = filtersString.data(using: .utf8),
                  let filters = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return filters
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                filtersString = string
            } else {
                filtersString = "[]"
            }
        }
    }
    
    var exifData: ExifData? {
        // Only return ExifData if we have some actual data
        guard exifMake != nil || exifModel != nil || exifGpsDirection != -1 else {
            return nil
        }
        
        return ExifData(
            make: exifMake,
            model: exifModel,
            lens: exifLens,
            focalLength: exifFocalLength == -1 ? nil : exifFocalLength,
            fNumber: exifFNumber == -1 ? nil : exifFNumber,
            exposureTime: exifExposureTime,
            iso: exifIso == -1 ? nil : Int(exifIso),
            dateTimeOriginal: exifDateTimeOriginal,
            gpsLatitude: exifGpsLatitude.isNaN ? nil : exifGpsLatitude,
            gpsLongitude: exifGpsLongitude.isNaN ? nil : exifGpsLongitude,
            gpsAltitude: exifGpsAltitude.isNaN ? nil : exifGpsAltitude,
            gpsDirection: exifGpsDirection == -1 ? nil : exifGpsDirection,
            width: exifWidth == -1 ? nil : Int(exifWidth),
            height: exifHeight == -1 ? nil : Int(exifHeight),
            colorSpace: exifColorSpace,
            software: exifSoftware
        )
    }
    
    func setExifData(_ exifData: ExifData?) {
        guard let exifData = exifData else {
            // Clear all EXIF data
            exifMake = nil
            exifModel = nil
            exifLens = nil
            exifFocalLength = -1
            exifFNumber = -1
            exifExposureTime = nil
            exifIso = -1
            exifDateTimeOriginal = nil
            exifGpsLatitude = Double.nan
            exifGpsLongitude = Double.nan
            exifGpsAltitude = Double.nan
            exifGpsDirection = -1
            exifWidth = -1
            exifHeight = -1
            exifColorSpace = nil
            exifSoftware = nil
            return
        }
        
        exifMake = exifData.make
        exifModel = exifData.model
        exifLens = exifData.lens
        exifFocalLength = exifData.focalLength ?? -1
        exifFNumber = exifData.fNumber ?? -1
        exifExposureTime = exifData.exposureTime
        exifIso = Int32(exifData.iso ?? -1)
        exifDateTimeOriginal = exifData.dateTimeOriginal
        exifGpsLatitude = exifData.gpsLatitude ?? Double.nan
        exifGpsLongitude = exifData.gpsLongitude ?? Double.nan
        exifGpsAltitude = exifData.gpsAltitude ?? Double.nan
        exifGpsDirection = exifData.gpsDirection ?? -1
        exifWidth = Int32(exifData.width ?? -1)
        exifHeight = Int32(exifData.height ?? -1)
        exifColorSpace = exifData.colorSpace
        exifSoftware = exifData.software
    }
}

