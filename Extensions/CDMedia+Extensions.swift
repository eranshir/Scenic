import Foundation
import CoreData

extension CDMedia {
    
    func toMedia() -> Media {
        let exifData = ExifData(
            make: self.exifMake,
            model: self.exifModel,
            lens: self.exifLens,
            focalLength: self.exifFocalLength == -1 ? nil : self.exifFocalLength,
            fNumber: self.exifFNumber == -1 ? nil : self.exifFNumber,
            exposureTime: self.exifExposureTime,
            iso: self.exifIso == -1 ? nil : Int(self.exifIso),
            dateTimeOriginal: self.exifDateTimeOriginal,
            gpsLatitude: self.exifGpsLatitude == 0 ? nil : self.exifGpsLatitude,
            gpsLongitude: self.exifGpsLongitude == 0 ? nil : self.exifGpsLongitude,
            gpsAltitude: self.exifGpsAltitude == 0 ? nil : self.exifGpsAltitude,
            gpsDirection: self.exifGpsDirection == -1 ? nil : self.exifGpsDirection,
            width: self.exifWidth == -1 ? nil : Int(self.exifWidth),
            height: self.exifHeight == -1 ? nil : Int(self.exifHeight),
            colorSpace: self.exifColorSpace,
            software: self.exifSoftware
        )
        
        return Media(
            id: self.id ?? UUID(),
            spotId: self.spot?.id,
            userId: self.userId ?? UUID(),
            type: Media.MediaType(rawValue: self.type ?? "photo") ?? .photo,
            url: self.url ?? "",
            thumbnailUrl: self.thumbnailUrl,
            captureTimeUTC: self.captureTimeUTC,
            exifData: exifData,
            device: self.device,
            lens: self.lens,
            focalLengthMM: self.focalLengthMM == -1 ? nil : self.focalLengthMM,
            aperture: self.aperture == -1 ? nil : self.aperture,
            shutterSpeed: self.shutterSpeed,
            iso: self.iso == -1 ? nil : Int(self.iso),
            resolutionWidth: self.resolutionWidth == -1 ? nil : Int(self.resolutionWidth),
            resolutionHeight: self.resolutionHeight == -1 ? nil : Int(self.resolutionHeight),
            presets: parseStringArray(self.presetsString ?? "[]"),
            filters: parseStringArray(self.filtersString ?? "[]"),
            headingFromExif: self.headingFromExif,
            originalFilename: self.originalFilename,
            createdAt: self.createdAt ?? Date()
        )
    }
    
    static func fromMedia(_ media: Media, in context: NSManagedObjectContext) -> CDMedia {
        let cdMedia = CDMedia(context: context)
        cdMedia.updateFromMedia(media)
        return cdMedia
    }
    
    func updateFromMedia(_ media: Media) {
        self.id = media.id
        self.userId = media.userId
        self.type = media.type.rawValue
        self.url = media.url
        self.thumbnailUrl = media.thumbnailUrl
        self.captureTimeUTC = media.captureTimeUTC
        self.device = media.device
        self.lens = media.lens
        self.focalLengthMM = media.focalLengthMM ?? -1
        self.aperture = media.aperture ?? -1
        self.shutterSpeed = media.shutterSpeed
        self.iso = Int32(media.iso ?? -1)
        self.resolutionWidth = Int32(media.resolutionWidth ?? -1)
        self.resolutionHeight = Int32(media.resolutionHeight ?? -1)
        self.presetsString = encodeStringArray(media.presets)
        self.filtersString = encodeStringArray(media.filters)
        self.headingFromExif = media.headingFromExif
        self.originalFilename = media.originalFilename
        self.createdAt = media.createdAt
        
        // EXIF data
        if let exif = media.exifData {
            self.exifMake = exif.make
            self.exifModel = exif.model
            self.exifLens = exif.lens
            self.exifFocalLength = exif.focalLength ?? -1
            self.exifFNumber = exif.fNumber ?? -1
            self.exifExposureTime = exif.exposureTime
            self.exifIso = Int32(exif.iso ?? -1)
            self.exifDateTimeOriginal = exif.dateTimeOriginal
            self.exifGpsLatitude = exif.gpsLatitude ?? 0
            self.exifGpsLongitude = exif.gpsLongitude ?? 0
            self.exifGpsAltitude = exif.gpsAltitude ?? 0
            self.exifGpsDirection = exif.gpsDirection ?? -1
            self.exifWidth = Int32(exif.width ?? -1)
            self.exifHeight = Int32(exif.height ?? -1)
            self.exifColorSpace = exif.colorSpace
            self.exifSoftware = exif.software
        }
        
        // Local-first properties
        self.isDownloaded = true
        self.thumbnailDownloaded = true
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