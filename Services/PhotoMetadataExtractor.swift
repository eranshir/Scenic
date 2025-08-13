import Foundation
import SwiftUI
import Photos
import PhotosUI
import CoreLocation
import ImageIO
import UniformTypeIdentifiers

struct ExtractedPhotoMetadata {
    var location: CLLocationCoordinate2D?
    var altitude: Double?
    var heading: Double?
    var captureDate: Date?
    
    // Camera & Lens
    var cameraMake: String?
    var cameraModel: String?
    var lensModel: String?
    
    // Exposure Settings
    var focalLength: Float?
    var focalLengthIn35mm: Float?
    var aperture: Float?
    var shutterSpeed: String?
    var iso: Int?
    
    // Image Properties
    var width: Int?
    var height: Int?
    var colorSpace: String?
    var bitDepth: Int?
    
    // Additional Data
    var software: String?
    var flash: Bool?
    var whiteBalance: String?
    var meteringMode: String?
    var exposureMode: String?
    var exposureBias: Float?
    
    // Video specific
    var duration: TimeInterval?
    var frameRate: Float?
    var videoCodec: String?
    
    // Computed properties
    var megapixels: Double? {
        guard let w = width, let h = height else { return nil }
        return Double(w * h) / 1_000_000
    }
    
    var aspectRatio: String? {
        guard let w = width, let h = height else { return nil }
        let gcd = greatestCommonDivisor(w, h)
        return "\(w/gcd):\(h/gcd)"
    }
    
    private func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
        let remainder = a % b
        return remainder == 0 ? b : greatestCommonDivisor(b, remainder)
    }
}

class PhotoMetadataExtractor: ObservableObject {
    
    func extractMetadata(from item: PhotosPickerItem) async throws -> ExtractedPhotoMetadata {
        var metadata = ExtractedPhotoMetadata()
        
        // Try to get the asset
        if let assetIdentifier = item.itemIdentifier {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
            if let asset = fetchResult.firstObject {
                // Extract basic metadata from PHAsset
                metadata.location = asset.location?.coordinate
                metadata.altitude = asset.location?.altitude
                metadata.heading = asset.location?.course
                metadata.captureDate = asset.creationDate
                metadata.duration = asset.duration
                
                // Get detailed EXIF data
                let exifData = await extractDetailedEXIF(from: asset)
                // Merge the EXIF data into our metadata
                metadata.aperture = exifData.aperture ?? metadata.aperture
                metadata.shutterSpeed = exifData.shutterSpeed ?? metadata.shutterSpeed
                metadata.iso = exifData.iso ?? metadata.iso
                metadata.focalLength = exifData.focalLength ?? metadata.focalLength
                metadata.focalLengthIn35mm = exifData.focalLengthIn35mm ?? metadata.focalLengthIn35mm
                metadata.flash = exifData.flash ?? metadata.flash
                metadata.whiteBalance = exifData.whiteBalance ?? metadata.whiteBalance
                metadata.meteringMode = exifData.meteringMode ?? metadata.meteringMode
                metadata.exposureMode = exifData.exposureMode ?? metadata.exposureMode
                metadata.exposureBias = exifData.exposureBias ?? metadata.exposureBias
                metadata.cameraMake = exifData.cameraMake ?? metadata.cameraMake
                metadata.cameraModel = exifData.cameraModel ?? metadata.cameraModel
                metadata.lensModel = exifData.lensModel ?? metadata.lensModel
                metadata.software = exifData.software ?? metadata.software
                metadata.width = exifData.width ?? metadata.width
                metadata.height = exifData.height ?? metadata.height
                metadata.colorSpace = exifData.colorSpace ?? metadata.colorSpace
                metadata.bitDepth = exifData.bitDepth ?? metadata.bitDepth
            }
        }
        
        // Also try to extract from the image data directly
        if let data = try? await item.loadTransferable(type: Data.self) {
            extractEXIFFromData(data, into: &metadata)
        }
        
        return metadata
    }
    
    private func extractDetailedEXIF(from asset: PHAsset) async -> ExtractedPhotoMetadata {
        var metadata = ExtractedPhotoMetadata()
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = true
        
        return await withCheckedContinuation { continuation in
            asset.requestContentEditingInput(with: options) { input, _ in
                guard let input = input,
                      let url = input.fullSizeImageURL else {
                    continuation.resume(returning: metadata)
                    return
                }
                
                if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                   let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
                    
                    // EXIF Dictionary
                    if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                        metadata.aperture = exif[kCGImagePropertyExifFNumber as String] as? Float
                        metadata.shutterSpeed = self.formatShutterSpeed(exif[kCGImagePropertyExifExposureTime as String])
                        metadata.iso = (exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int])?.first
                        metadata.focalLength = exif[kCGImagePropertyExifFocalLength as String] as? Float
                        metadata.focalLengthIn35mm = exif[kCGImagePropertyExifFocalLenIn35mmFilm as String] as? Float
                        metadata.flash = (exif[kCGImagePropertyExifFlash as String] as? Int) ?? 0 > 0
                        metadata.whiteBalance = self.parseWhiteBalance(exif[kCGImagePropertyExifWhiteBalance as String])
                        metadata.meteringMode = self.parseMeteringMode(exif[kCGImagePropertyExifMeteringMode as String])
                        metadata.exposureMode = self.parseExposureMode(exif[kCGImagePropertyExifExposureMode as String])
                        metadata.exposureBias = exif[kCGImagePropertyExifExposureBiasValue as String] as? Float
                    }
                    
                    // TIFF Dictionary
                    if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                        metadata.cameraMake = tiff[kCGImagePropertyTIFFMake as String] as? String
                        metadata.cameraModel = tiff[kCGImagePropertyTIFFModel as String] as? String
                        metadata.software = tiff[kCGImagePropertyTIFFSoftware as String] as? String
                    }
                    
                    // Lens info from EXIF Aux
                    if let exifAux = properties["{ExifAux}"] as? [String: Any] {
                        metadata.lensModel = exifAux["LensModel"] as? String
                    }
                    
                    // Image dimensions
                    metadata.width = properties[kCGImagePropertyPixelWidth as String] as? Int
                    metadata.height = properties[kCGImagePropertyPixelHeight as String] as? Int
                    metadata.colorSpace = properties[kCGImagePropertyColorModel as String] as? String
                    metadata.bitDepth = properties[kCGImagePropertyDepth as String] as? Int
                }
                
                continuation.resume(returning: metadata)
            }
        }
    }
    
    private func extractEXIFFromData(_ data: Data, into metadata: inout ExtractedPhotoMetadata) {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return
        }
        
        // GPS Dictionary
        if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            if let latitude = gps[kCGImagePropertyGPSLatitude as String] as? Double,
               let latitudeRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String,
               let longitude = gps[kCGImagePropertyGPSLongitude as String] as? Double,
               let longitudeRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String {
                
                let lat = latitudeRef == "S" ? -latitude : latitude
                let lon = longitudeRef == "W" ? -longitude : longitude
                metadata.location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            
            metadata.altitude = gps[kCGImagePropertyGPSAltitude as String] as? Double
            metadata.heading = gps[kCGImagePropertyGPSImgDirection as String] as? Double
        }
    }
    
    private func formatShutterSpeed(_ value: Any?) -> String? {
        guard let exposureTime = value as? Double else { return nil }
        
        if exposureTime < 1 {
            let denominator = Int(1 / exposureTime)
            return "1/\(denominator)"
        } else {
            return "\(Int(exposureTime))s"
        }
    }
    
    private func parseWhiteBalance(_ value: Any?) -> String? {
        guard let wb = value as? Int else { return nil }
        switch wb {
        case 0: return "Auto"
        case 1: return "Manual"
        default: return "Custom"
        }
    }
    
    private func parseMeteringMode(_ value: Any?) -> String? {
        guard let mode = value as? Int else { return nil }
        switch mode {
        case 1: return "Average"
        case 2: return "Center-weighted"
        case 3: return "Spot"
        case 4: return "Multi-spot"
        case 5: return "Pattern"
        case 6: return "Partial"
        default: return "Unknown"
        }
    }
    
    private func parseExposureMode(_ value: Any?) -> String? {
        guard let mode = value as? Int else { return nil }
        switch mode {
        case 0: return "Auto"
        case 1: return "Manual"
        case 2: return "Auto bracket"
        default: return "Unknown"
        }
    }
}