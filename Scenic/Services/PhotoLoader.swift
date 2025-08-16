import Foundation
import SwiftUI
import Photos
import PhotosUI
import UIKit
import CoreData

@MainActor
class PhotoLoader: ObservableObject {
    static let shared = PhotoLoader()
    
    private let imageManager = PHImageManager.default()
    private let photoCache = PhotoCacheService.shared
    
    // MARK: - Loading from CDMedia
    
    func loadImage(from cdMedia: CDMedia, targetSize: CGSize = CGSize(width: 400, height: 400)) async -> UIImage? {
        // If we have a local cached file, load from there
        if let localFilePath = cdMedia.localFilePath, cdMedia.isDownloaded {
            return await photoCache.loadImage(from: localFilePath, targetSize: targetSize)
        }
        
        // If we have a server URL, try to download and cache
        if !cdMedia.url.isEmpty {
            if let filename = await photoCache.downloadAndCache(from: cdMedia.url, mediaId: cdMedia.id, isVideo: cdMedia.type == "video") {
                // Update Core Data with cached filename
                cdMedia.localFilePath = filename
                cdMedia.isDownloaded = true
                try? cdMedia.managedObjectContext?.save()
                
                return await photoCache.loadImage(from: filename, targetSize: targetSize)
            }
        }
        
        return nil
    }
    
    func loadThumbnail(from cdMedia: CDMedia) async -> UIImage? {
        // Check if we have a cached thumbnail
        if let localFilePath = cdMedia.localFilePath, cdMedia.thumbnailDownloaded {
            return await photoCache.loadThumbnail(from: localFilePath)
        }
        
        // If we have a thumbnail URL, download it
        if let thumbnailUrl = cdMedia.thumbnailUrl, !thumbnailUrl.isEmpty {
            if let filename = await photoCache.downloadAndCacheThumbnail(from: thumbnailUrl, mediaId: cdMedia.id) {
                // Update Core Data
                cdMedia.thumbnailDownloaded = true
                try? cdMedia.managedObjectContext?.save()
                
                return await photoCache.loadImage(from: filename, targetSize: CGSize(width: 150, height: 150))
            }
        }
        
        // Fallback to loading and resizing the main image
        return await loadImage(from: cdMedia, targetSize: CGSize(width: 150, height: 150))
    }
    
    // MARK: - Caching from Photos Library (for new uploads)
    
    func cacheFromPhotoLibrary(asset: PHAsset, cdMedia: CDMedia) async -> Bool {
        let isVideo = asset.mediaType == .video
        
        // Cache the full resolution media
        let filename: String?
        if isVideo {
            filename = await photoCache.cacheVideo(from: asset, mediaId: cdMedia.id)
        } else {
            filename = await photoCache.cachePhoto(from: asset, mediaId: cdMedia.id)
        }
        
        guard let filename = filename else {
            print("Failed to cache media for ID: \(cdMedia.id.uuidString)")
            return false
        }
        
        // Cache thumbnail
        let thumbnailFilename = await photoCache.cacheThumbnail(from: asset, mediaId: cdMedia.id)
        
        // Update Core Data
        cdMedia.localFilePath = filename
        cdMedia.isDownloaded = true
        cdMedia.thumbnailDownloaded = thumbnailFilename != nil
        
        do {
            try cdMedia.managedObjectContext?.save()
            print("Successfully cached media: \(filename)")
            return true
        } catch {
            print("Failed to save cached media info to Core Data: \(error)")
            return false
        }
    }
    
    // MARK: - Caching from PhotosPicker
    
    func cacheFromPhotosPicker(item: PhotosPickerItem, cdMedia: CDMedia) async -> Bool {
        print("📥 Starting to cache from PhotosPicker item")
        
        // Load the photo data from PhotosPicker
        guard let photoData = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: photoData) else {
            print("❌ Could not load image data from PhotosPicker item")
            return false
        }
        
        print("✅ Loaded image data from PhotosPicker: \(photoData.count) bytes")
        
        // Generate filename and cache the image
        let mediaId = cdMedia.id
        
        let filename = await photoCache.cacheImageData(photoData, mediaId: mediaId, isVideo: false)
        guard let cachedFilename = filename else {
            print("❌ Failed to cache image data")
            return false
        }
        
        // Cache thumbnail as well
        let thumbnailFilename = await photoCache.cacheImageAsThumbnail(image, mediaId: mediaId)
        
        // Update Core Data with cache info
        cdMedia.localFilePath = cachedFilename
        cdMedia.isDownloaded = true
        cdMedia.thumbnailDownloaded = thumbnailFilename != nil
        
        do {
            try cdMedia.managedObjectContext?.save()
            print("✅ Updated CDMedia with cache information")
            return true
        } catch {
            print("❌ Failed to save CDMedia cache info: \(error)")
            return false
        }
    }
    
    // MARK: - Legacy support for identifier-based loading (deprecated)
    
    @available(*, deprecated, message: "Use loadImage(from cdMedia:) instead")
    func loadImage(from identifier: String, targetSize: CGSize = CGSize(width: 400, height: 400)) async -> UIImage? {
        // This method is kept for backward compatibility but should be phased out
        return await withCheckedContinuation { continuation in
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            
            guard let asset = fetchResult.firstObject else {
                continuation.resume(returning: nil)
                return
            }
            
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast
            
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                continuation.resume(returning: image)
            }
        }
    }
    
    @available(*, deprecated, message: "Use loadThumbnail(from cdMedia:) instead")
    func loadThumbnail(from identifier: String) async -> UIImage? {
        return await loadImage(from: identifier, targetSize: CGSize(width: 150, height: 150))
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        photoCache.clearCache()
    }
    
    func getCacheSize() -> UInt64 {
        return photoCache.getCacheSize()
    }
}

