import Foundation

struct Media: Identifiable, Codable {
    let id: UUID
    var spotId: UUID?
    var userId: UUID
    var type: MediaType
    var url: String
    var thumbnailUrl: String?
    var captureTimeUTC: Date?
    var exifData: ExifData?
    var device: String?
    var lens: String?
    var focalLengthMM: Float?
    var aperture: Float?
    var shutterSpeed: String?
    var iso: Int?
    var resolutionWidth: Int?
    var resolutionHeight: Int?
    var presets: [String]
    var filters: [String]
    var headingFromExif: Bool
    var originalFilename: String?
    var createdAt: Date
    
    enum MediaType: String, Codable {
        case photo
        case video
        case live
    }
}

struct ExifData: Codable {
    var make: String?
    var model: String?
    var lens: String?
    var focalLength: Float?
    var fNumber: Float?
    var exposureTime: String?
    var iso: Int?
    var dateTimeOriginal: Date?
    var gpsLatitude: Double?
    var gpsLongitude: Double?
    var gpsAltitude: Double?
    var gpsDirection: Float?
    var width: Int?
    var height: Int?
    var colorSpace: String?
    var software: String?
}