import Foundation
import SwiftUI
import Photos
import UIKit

// SwiftUI view for loading photos asynchronously
struct AsyncPhotoView: View {
    let photoIdentifier: String
    let targetSize: CGSize
    let contentMode: ContentMode
    
    @State private var image: UIImage?
    @State private var isLoading = true
    
    init(photoIdentifier: String, targetSize: CGSize = CGSize(width: 400, height: 400), contentMode: ContentMode = .fill) {
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
                // Fallback placeholder
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color.gray.opacity(0.3), Color.secondary.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white.opacity(0.8))
                            Text("Photo unavailable")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    )
            }
        }
        .task {
            await loadPhotoInternal()
        }
    }
    
    @available(*, deprecated, message: "AsyncPhotoView uses legacy string-based loading")
    private func loadPhoto() async {
        await loadPhotoInternal()
    }
    
    private func loadPhotoInternal() async {
        // Legacy string-based loading - should eventually be replaced with CDMedia-based approach
        let loadedImage = await PhotoLoader.shared.loadImage(from: photoIdentifier, targetSize: targetSize)
        
        await MainActor.run {
            self.image = loadedImage
            self.isLoading = false
        }
    }
}