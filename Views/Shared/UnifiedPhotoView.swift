import SwiftUI
import UIKit

/// Unified photo view that loads cached photos only
/// All photos are stored in the local cache system
struct UnifiedPhotoView: View {
    let photoIdentifier: String
    let targetSize: CGSize
    let contentMode: ContentMode
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadingError = false
    
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
        
        print("🖼️ Loading cached photo: \(photoIdentifier)")
        
        let photoCache = PhotoCacheService.shared
        let cleanedIdentifier = cleanPhotoIdentifier(photoIdentifier)
        let filename = "\(cleanedIdentifier).jpg"
        
        // Check if file exists first
        let fileExists = photoCache.fileExists(filename: filename)
        print("🔍 File exists check for \(filename): \(fileExists)")
        
        let loadedImage = await photoCache.loadImage(from: filename, targetSize: targetSize)
        
        DispatchQueue.main.async {
            self.image = loadedImage
            self.loadingError = loadedImage == nil
            if loadedImage != nil {
                print("✅ Successfully loaded cached photo: \(cleanedIdentifier)")
            } else {
                print("❌ Failed to load cached photo: \(filename) (file exists: \(fileExists))")
            }
        }
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