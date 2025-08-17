import Foundation
import UIKit
import Cloudinary

/// Manages Cloudinary media uploads and transformations
@MainActor
class CloudinaryManager: ObservableObject {
    static let shared = CloudinaryManager()
    
    private let cloudinary: CLDCloudinary
    private let uploadPreset = "scenic_mobile"
    private let maxFileSize: Int64 = 50 * 1024 * 1024 // 50MB
    
    private init() {
        let config = CLDConfiguration(
            cloudName: "scenic-app",
            apiKey: "398184757632917",
            apiSecret: "hGE5Yo3UDcd4qXKgPOqtFUIpXcA", // Note: In production, use server-side uploads
            secure: true
        )
        cloudinary = CLDCloudinary(configuration: config)
    }
    
    // MARK: - Upload Functions
    
    /// Upload image to Cloudinary
    func uploadImage(
        _ image: UIImage,
        spotId: String,
        progress: ((Double) -> Void)? = nil
    ) async throws -> CloudinaryUploadResult {
        
        // Validate file size
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw CloudinaryError.invalidImage
        }
        
        if imageData.count > maxFileSize {
            throw CloudinaryError.fileTooLarge
        }
        
        // Generate unique public ID
        let timestamp = Int(Date().timeIntervalSince1970)
        let publicId = "spots/\(spotId)/\(UUID().uuidString)_\(timestamp)"
        
        return try await withCheckedThrowingContinuation { continuation in
            cloudinary.createUploader().upload(
                data: imageData,
                uploadPreset: uploadPreset,
                params: CLDUploadRequestParams()
                    .setPublicId(publicId)
                    .setFolder("scenic/spots/\(spotId)")
                    .setTags(["scenic", "spot:\(spotId)", "mobile"])
                    .setResourceType(.image)
                    .setColors(true)
                    .setFaces(true)
                    .setMediaMetadata(true)
                    .setPhash(true),
                progress: { progressData in
                    let percentage = Double(progressData.completedUnitCount) / Double(progressData.totalUnitCount)
                    progress?(percentage)
                },
                completionHandler: { result, error in
                    if let error = error {
                        continuation.resume(throwing: CloudinaryError.uploadFailed(error.localizedDescription))
                    } else if let result = result {
                        let uploadResult = CloudinaryUploadResult(
                            publicId: result.publicId ?? "",
                            url: result.url ?? "",
                            secureUrl: result.secureUrl ?? "",
                            width: result.width ?? 0,
                            height: result.height ?? 0,
                            format: result.format ?? "",
                            resourceType: result.resourceType ?? "",
                            bytes: 0, // Not available in SDK
                            etag: "", // Not available in SDK
                            signature: result.signature ?? "",
                            version: Int(result.version ?? "0") ?? 0,
                            thumbnailUrl: self.generateThumbnailUrl(publicId: result.publicId ?? ""),
                            cardUrl: self.generateCardUrl(publicId: result.publicId ?? ""),
                            optimizedUrl: self.generateOptimizedUrl(publicId: result.publicId ?? "")
                        )
                        continuation.resume(returning: uploadResult)
                    } else {
                        continuation.resume(throwing: CloudinaryError.unknownError)
                    }
                }
            )
        }
    }
    
    // MARK: - URL Generation
    
    /// Generate thumbnail URL (150x150)
    func generateThumbnailUrl(publicId: String) -> String {
        return cloudinary.createUrl()
            .setTransformation(CLDTransformation()
                .setWidth(150)
                .setHeight(150)
                .setCrop(.thumb)
                .setGravity(.auto)
                .setQuality("auto")
                .setFetchFormat("auto"))
            .generate(publicId) ?? ""
    }
    
    /// Generate card URL (400x300)
    func generateCardUrl(publicId: String) -> String {
        return cloudinary.createUrl()
            .setTransformation(CLDTransformation()
                .setWidth(400)
                .setHeight(300)
                .setCrop(.fill)
                .setGravity(.auto)
                .setQuality("auto"))
            .generate(publicId) ?? ""
    }
    
    /// Generate optimized URL (auto everything)
    func generateOptimizedUrl(publicId: String) -> String {
        return cloudinary.createUrl()
            .setTransformation(CLDTransformation()
                .setQuality("auto")
                .setFetchFormat("auto")
                .setDpr("auto")
                .setFlags(["progressive", "immutable_cache"]))
            .generate(publicId) ?? ""
    }
    
    /// Generate responsive URL for different screen sizes
    func generateResponsiveUrl(publicId: String, width: Int) -> String {
        return cloudinary.createUrl()
            .setTransformation(CLDTransformation()
                .setWidth(width)
                .setCrop(.scale)
                .setQuality("auto")
                .setFetchFormat("auto")
                .setDpr("auto"))
            .generate(publicId) ?? ""
    }
    
    // MARK: - Helper Functions
    
    /// Validate image before upload
    func validateImage(_ image: UIImage) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            return false
        }
        return data.count <= maxFileSize
    }
    
    /// Compress image if needed
    func compressImage(_ image: UIImage, maxSizeMB: Double = 10) -> UIImage? {
        let maxSize = maxSizeMB * 1024 * 1024
        var compression: CGFloat = 1.0
        var imageData = image.jpegData(compressionQuality: compression)
        
        while let data = imageData, Double(data.count) > maxSize && compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }
        
        if let data = imageData {
            return UIImage(data: data)
        }
        return nil
    }
}

// MARK: - Data Models

struct CloudinaryUploadResult {
    let publicId: String
    let url: String
    let secureUrl: String
    let width: Int
    let height: Int
    let format: String
    let resourceType: String
    let bytes: Int
    let etag: String
    let signature: String
    let version: Int
    
    // Generated URLs
    let thumbnailUrl: String?
    let cardUrl: String?
    let optimizedUrl: String?
}

// MARK: - Errors

enum CloudinaryError: LocalizedError {
    case invalidImage
    case fileTooLarge
    case uploadFailed(String)
    case unknownError
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .fileTooLarge:
            return "File size exceeds 50MB limit"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .unknownError:
            return "An unknown error occurred"
        case .notImplemented:
            return "This feature requires server-side implementation"
        }
    }
}