import Foundation
import SwiftUI
import CoreData

// SwiftUI view for loading photos from CDMedia using the cache system
struct CachedPhotoView: View {
    let cdMedia: CDMedia
    let targetSize: CGSize
    let contentMode: ContentMode
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadingError = false
    
    init(cdMedia: CDMedia, targetSize: CGSize = CGSize(width: 400, height: 400), contentMode: ContentMode = .fill) {
        self.cdMedia = cdMedia
        self.targetSize = targetSize
        self.contentMode = contentMode
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
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
                // Fallback placeholder for failed loads
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color.gray.opacity(0.3), Color.secondary.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: loadingError ? "exclamationmark.triangle.fill" : "photo.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white.opacity(0.8))
                            Text(loadingError ? "Failed to load" : "Photo unavailable")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    )
            }
        }
        .task {
            await loadPhoto()
        }
        .onChange(of: cdMedia.localFilePath) { _, _ in
            // Reload when local file path changes (e.g., after caching)
            Task {
                await loadPhoto()
            }
        }
    }
    
    private func loadPhoto() async {
        defer { isLoading = false }
        
        image = await PhotoLoader.shared.loadImage(from: cdMedia, targetSize: targetSize)
        loadingError = image == nil
    }
}

// Convenience view for thumbnails
struct CachedThumbnailView: View {
    let cdMedia: CDMedia
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadingError = false
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if isLoading {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.6)
                    )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: loadingError ? "exclamationmark.triangle" : "photo")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    )
            }
        }
        .task {
            await loadThumbnail()
        }
        .onChange(of: cdMedia.localFilePath) { _, _ in
            Task {
                await loadThumbnail()
            }
        }
    }
    
    private func loadThumbnail() async {
        defer { isLoading = false }
        
        image = await PhotoLoader.shared.loadThumbnail(from: cdMedia)
        loadingError = image == nil
    }
}