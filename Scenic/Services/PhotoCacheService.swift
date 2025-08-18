import Foundation
import SwiftUI
import Photos
import UIKit
import AVFoundation

@MainActor
class PhotoCacheService: ObservableObject {
    static let shared = PhotoCacheService()
    
    private let fileManager = FileManager.default
    private let imageCache = NSCache<NSString, UIImage>()
    private let cacheDirectory: URL
    
    init() {
        // Create cache directory in Documents/PhotoCache
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("PhotoCache", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Configure memory cache
        imageCache.countLimit = 50
        imageCache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }
    
    // MARK: - Cache Management
    
    func cachePhoto(from asset: PHAsset, mediaId: UUID) async -> String? {
        let filename = "\(mediaId.uuidString).jpg"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        // Check if already cached
        if fileManager.fileExists(atPath: fileURL.path) {
            return filename
        }
        
        // Load full resolution image from Photos
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                guard let image = image,
                      let data = image.jpegData(compressionQuality: 0.9) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                do {
                    try data.write(to: fileURL)
                    continuation.resume(returning: filename)
                } catch {
                    print("Failed to cache photo: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func cacheVideo(from asset: PHAsset, mediaId: UUID) async -> String? {
        let filename = "\(mediaId.uuidString).mov"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        // Check if already cached
        if fileManager.fileExists(atPath: fileURL.path) {
            return filename
        }
        
        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, audioMix, info in
                guard let urlAsset = avAsset as? AVURLAsset else {
                    continuation.resume(returning: nil)
                    return
                }
                
                do {
                    let data = try Data(contentsOf: urlAsset.url)
                    try data.write(to: fileURL)
                    continuation.resume(returning: filename)
                } catch {
                    print("Failed to cache video: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func cacheThumbnail(from asset: PHAsset, mediaId: UUID) async -> String? {
        let filename = "\(mediaId.uuidString)_thumb.jpg"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        // Check if already cached
        if fileManager.fileExists(atPath: fileURL.path) {
            return filename
        }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast
        
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 300, height: 300),
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard let image = image,
                      let data = image.jpegData(compressionQuality: 0.7) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                do {
                    try data.write(to: fileURL)
                    continuation.resume(returning: filename)
                } catch {
                    print("Failed to cache thumbnail: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // MARK: - Direct Image Data Caching
    
    func cacheImageData(_ imageData: Data, mediaId: UUID, isVideo: Bool) async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let fileExtension = isVideo ? "mp4" : "jpg"
                let filename = "\(mediaId.uuidString).\(fileExtension)"
                let fileURL = self.cacheDirectory.appendingPathComponent(filename)
                
                do {
                    try imageData.write(to: fileURL)
                    print("✅ Cached image data to: \(filename)")
                    continuation.resume(returning: filename)
                } catch {
                    print("❌ Failed to cache image data: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func cacheImageAsThumbnail(_ image: UIImage, mediaId: UUID) async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Create thumbnail
                let thumbnailSize = CGSize(width: 150, height: 150)
                let thumbnailImage = image.preparingThumbnail(of: thumbnailSize) ?? image
                
                guard let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.7) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let filename = "\(mediaId.uuidString)_thumb.jpg"
                let fileURL = self.cacheDirectory.appendingPathComponent(filename)
                
                do {
                    try thumbnailData.write(to: fileURL)
                    print("✅ Cached thumbnail to: \(filename)")
                    continuation.resume(returning: filename)
                } catch {
                    print("❌ Failed to cache thumbnail: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // MARK: - Saving to Cache
    
    func saveImage(_ imageData: Data, filename: String) async {
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        do {
            try imageData.write(to: fileURL)
            print("💾 Saved image to cache: \(filename)")
        } catch {
            print("❌ Failed to save image to cache: \(error)")
        }
    }
    
    // MARK: - Loading from Cache
    
    func loadImage(from filename: String, targetSize: CGSize = CGSize(width: 400, height: 400)) async -> UIImage? {
        let cacheKey = "\(filename)_\(Int(targetSize.width))x\(Int(targetSize.height))"
        
        // Check memory cache first
        if let cachedImage = imageCache.object(forKey: cacheKey as NSString) {
            return cachedImage
        }
        
        // Load from disk
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let data = try? Data(contentsOf: fileURL),
                      let image = UIImage(data: data) else {
                    DispatchQueue.main.async {
                        continuation.resume(returning: nil)
                    }
                    return
                }
                
                // Resize image on main actor and cache
                DispatchQueue.main.async {
                    let resizedImage = self.resizeImage(image, to: targetSize)
                    let cacheKeyNS = cacheKey as NSString
                    
                    // Cache in memory
                    self.imageCache.setObject(resizedImage, forKey: cacheKeyNS, cost: Int(resizedImage.size.width * resizedImage.size.height * 4))
                    continuation.resume(returning: resizedImage)
                }
            }
        }
    }
    
    func loadThumbnail(from filename: String) async -> UIImage? {
        // For thumbnails, use the thumbnail filename if available, otherwise resize the main image
        let thumbnailFilename = filename.replacingOccurrences(of: ".jpg", with: "_thumb.jpg")
        let thumbnailURL = cacheDirectory.appendingPathComponent(thumbnailFilename)
        
        if fileManager.fileExists(atPath: thumbnailURL.path) {
            return await loadImage(from: thumbnailFilename, targetSize: CGSize(width: 150, height: 150))
        } else {
            return await loadImage(from: filename, targetSize: CGSize(width: 150, height: 150))
        }
    }
    
    // MARK: - Remote Media Caching
    
    func downloadAndCache(from url: String, mediaId: UUID, isVideo: Bool = false) async -> String? {
        guard let downloadURL = URL(string: url) else { return nil }
        
        let fileExtension = isVideo ? "mov" : "jpg"
        let filename = "\(mediaId.uuidString).\(fileExtension)"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        // Check if already cached
        if fileManager.fileExists(atPath: fileURL.path) {
            return filename
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: downloadURL)
            try data.write(to: fileURL)
            return filename
        } catch {
            print("Failed to download and cache media: \(error)")
            return nil
        }
    }
    
    func downloadAndCacheThumbnail(from url: String, mediaId: UUID) async -> String? {
        guard let downloadURL = URL(string: url) else { return nil }
        
        let filename = "\(mediaId.uuidString)_thumb.jpg"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        // Check if already cached
        if fileManager.fileExists(atPath: fileURL.path) {
            return filename
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: downloadURL)
            try data.write(to: fileURL)
            return filename
        } catch {
            print("Failed to download and cache thumbnail: \(error)")
            return nil
        }
    }
    
    // MARK: - Utility Methods
    
    private func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, UIScreen.main.scale)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    func fileExists(filename: String) -> Bool {
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    func getFileURL(for filename: String) -> URL {
        return cacheDirectory.appendingPathComponent(filename)
    }
    
    func clearCache() {
        imageCache.removeAllObjects()
        
        // Optionally clear disk cache too
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in contents {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            print("Failed to clear disk cache: \(error)")
        }
    }
    
    func getCacheSize() -> UInt64 {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            return contents.reduce(0) { total, fileURL in
                let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return total + UInt64(fileSize)
            }
        } catch {
            return 0
        }
    }
    
    func listCachedFiles() {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            print("📁 Cache directory contains \(contents.count) files:")
            for fileURL in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let fileName = fileURL.lastPathComponent
                let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                print("   📄 \(fileName) (\(fileSize) bytes)")
            }
        } catch {
            print("❌ Failed to list cached files: \(error)")
        }
    }
}