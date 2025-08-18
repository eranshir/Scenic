import SwiftUI
import UIKit

/// Unified photo view that loads both cached and remote photos
/// Handles local cached photos and Cloudinary URLs
struct UnifiedPhotoView: View {
    let photoIdentifier: String
    let targetSize: CGSize
    let contentMode: ContentMode
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadingError = false
    
    private var isRemoteURL: Bool {
        photoIdentifier.hasPrefix("http://") || photoIdentifier.hasPrefix("https://")
    }
    
    // Extract a cache key from Cloudinary URL or local identifier
    private var cacheKey: String {
        if isRemoteURL {
            // Extract UUID from Cloudinary URL if possible
            // Pattern: .../UUID_timestamp.jpg
            if let url = URL(string: photoIdentifier),
               let filename = url.lastPathComponent.split(separator: ".").first {
                let parts = filename.split(separator: "_")
                if parts.count >= 1 {
                    // Return the UUID part (before the underscore)
                    return String(parts[0])
                }
            }
            // Fallback: use full URL as key
            return photoIdentifier.replacingOccurrences(of: "/", with: "_")
                                 .replacingOccurrences(of: ":", with: "_")
                                 .replacingOccurrences(of: ".", with: "_")
        } else {
            return cleanPhotoIdentifier(photoIdentifier)
        }
    }
    
    init(photoIdentifier: String, targetSize: CGSize = CGSize(width: 400, height: 300), contentMode: ContentMode = .fill) {
        self.photoIdentifier = photoIdentifier
        self.targetSize = targetSize
        self.contentMode = contentMode
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.green.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    )
            } else {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color.gray.opacity(0.3), Color.secondary.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: loadingError ? "exclamationmark.triangle.fill" : "photo.fill")
                                .font(.system(size: min(targetSize.width, targetSize.height) * 0.2))
                                .foregroundColor(.white.opacity(0.8))
                            Text(loadingError ? "Failed to load" : "No image")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    )
            }
        }
        .task {
            await loadPhoto()
        }
    }
    
    private func loadPhoto() async {
        defer { isLoading = false }
        
        // Always check local cache first
        let photoCache = PhotoCacheService.shared
        let filename = "\(cacheKey).jpg"
        
        // Check if we have it in cache
        if photoCache.fileExists(filename: filename) {
            print("🔄 Found in cache, loading locally: \(cacheKey)")
            await loadCachedPhoto()
        } else if isRemoteURL {
            // Not in cache and it's a remote URL, download and cache it
            print("⬇️ Not in cache, downloading from Cloudinary: \(photoIdentifier)")
            await loadRemotePhotoAndCache()
        } else {
            // Local identifier but not in cache - try to load anyway
            print("🖼️ Loading local photo: \(photoIdentifier)")
            await loadCachedPhoto()
        }
    }
    
    private func loadCachedPhoto() async {
        let photoCache = PhotoCacheService.shared
        let filename = "\(cacheKey).jpg"
        
        let loadedImage = await photoCache.loadImage(from: filename, targetSize: targetSize)
        
        DispatchQueue.main.async {
            self.image = loadedImage
            self.loadingError = loadedImage == nil
            if loadedImage != nil {
                print("✅ Successfully loaded cached photo: \(self.cacheKey)")
            } else {
                print("❌ Failed to load cached photo: \(filename)")
            }
        }
    }
    
    private func loadRemotePhotoAndCache() async {
        guard let url = URL(string: photoIdentifier) else {
            print("❌ Invalid URL: \(photoIdentifier)")
            DispatchQueue.main.async {
                self.loadingError = true
            }
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let loadedImage = UIImage(data: data) {
                // Save to cache for future use
                let photoCache = PhotoCacheService.shared
                let filename = "\(cacheKey).jpg"
                
                if let imageData = loadedImage.jpegData(compressionQuality: 0.9) {
                    await photoCache.saveImage(imageData, filename: filename)
                    print("💾 Cached remote image: \(cacheKey)")
                }
                
                // Resize image for performance
                let resizedImage = resizeImage(loadedImage, targetSize: targetSize)
                
                DispatchQueue.main.async {
                    self.image = resizedImage
                    self.loadingError = false
                    print("✅ Successfully loaded and cached remote photo from: \(url)")
                }
            } else {
                throw NSError(domain: "UnifiedPhotoView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode image"])
            }
        } catch {
            print("❌ Failed to load remote photo: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.loadingError = true
            }
        }
    }
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        let newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
    
    private func cleanPhotoIdentifier(_ identifier: String) -> String {
        // Handle various identifier formats:
        // local_UUID -> UUID
        // photo_UUID -> UUID  
        // UUID -> UUID (already clean)
        
        if identifier.hasPrefix("local_") {
            return identifier.replacingOccurrences(of: "local_", with: "")
        } else if identifier.hasPrefix("photo_") {
            return identifier.replacingOccurrences(of: "photo_", with: "")
        } else {
            return identifier
        }
    }
}

/// Convenience view for thumbnails (120x90 default size)
struct UnifiedThumbnailView: View {
    let photoIdentifier: String
    
    var body: some View {
        UnifiedPhotoView(
            photoIdentifier: photoIdentifier,
            targetSize: CGSize(width: 120, height: 90),
            contentMode: .fill
        )
    }
}

/// Convenience view for large photos (800x600 default size)
struct UnifiedLargePhotoView: View {
    let photoIdentifier: String
    
    var body: some View {
        UnifiedPhotoView(
            photoIdentifier: photoIdentifier,
            targetSize: CGSize(width: 800, height: 600),
            contentMode: .fit
        )
    }
}