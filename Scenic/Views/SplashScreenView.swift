import SwiftUI
import CoreData

struct SplashScreenView: View {
    @State private var randomPhoto: String?
    @State private var showContent = false
    @EnvironmentObject var spotDataService: SpotDataService
    
    var body: some View {
        ZStack {
            // Background photo
            if let photoURL = randomPhoto {
                UnifiedPhotoView(
                    photoIdentifier: photoURL,
                    targetSize: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height),
                    contentMode: .fill
                )
                .ignoresSafeArea(.all) // Extend into ALL safe areas including notch and home indicator
                .clipped()
                .frame(
                    width: UIScreen.main.bounds.width,
                    height: UIScreen.main.bounds.height
                )
            } else {
                // Fallback gradient background
                LinearGradient(
                    gradient: Gradient(colors: [.green.opacity(0.8), .blue.opacity(0.6)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea(.all) // Extend into ALL safe areas
                .frame(
                    width: UIScreen.main.bounds.width,
                    height: UIScreen.main.bounds.height
                )
            }
            
            // Dark overlay for better text readability
            Color.black.opacity(0.3)
                .ignoresSafeArea(.all)
            
            // Scenic logo text
            VStack {
                Spacer()
                
                Text("Scenic")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 2, y: 2)
                    .scaleEffect(showContent ? 1.0 : 0.8)
                    .opacity(showContent ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.6), value: showContent)
                
                Text("Live Deliberately")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
                    .opacity(showContent ? 1.0 : 0.0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(.easeInOut(duration: 0.6).delay(0.2), value: showContent)
                
                Spacer()
            }
        }
        .onAppear {
            loadRandomPhoto()
            
            // Start animations
            withAnimation {
                showContent = true
            }
        }
    }
    
    private func loadRandomPhoto() {
        print("🖼️ === SPLASH SCREEN: LOADING RANDOM PHOTO ===")
        
        // Get ALL cached photo files directly from PhotoCacheService (not just spot-associated ones)
        let allCachedPhotos = PhotoCacheService.shared.getAllCachedPhotoFilenames()
        print("🖼️ Found \(allCachedPhotos.count) total cached photos from PhotoCacheService")
        
        if !allCachedPhotos.isEmpty {
            // Pick a random photo from ALL cached photos
            let randomIndex = Int.random(in: 0..<allCachedPhotos.count)
            let selectedFilename = allCachedPhotos[randomIndex]
            
            // Convert filename to identifier (remove .jpg extension for UnifiedPhotoView)
            let photoIdentifier = selectedFilename.replacingOccurrences(of: ".jpg", with: "")
                                                  .replacingOccurrences(of: ".jpeg", with: "")
                                                  .replacingOccurrences(of: ".png", with: "")
            
            randomPhoto = photoIdentifier
            print("🖼️ ✅ Selected random photo: '\(selectedFilename)' -> identifier: '\(photoIdentifier)'")
            
            // Debug: Show some sample filenames
            print("🖼️ Sample cached photos:")
            for (index, filename) in allCachedPhotos.prefix(5).enumerated() {
                print("🖼️   \(index): \(filename)")
            }
            
        } else {
            print("🖼️ ❌ No cached photos found in PhotoCacheService")
            // Still check Core Data as fallback
            let cachedMedia = spotDataService.getAllCachedMedia()
            print("🖼️ Fallback: Found \(cachedMedia.count) cached media from Core Data")
            
            if !cachedMedia.isEmpty {
                let randomIndex = Int.random(in: 0..<cachedMedia.count)
                let selectedMedia = cachedMedia[randomIndex]
                randomPhoto = selectedMedia.id.uuidString
                print("🖼️ 🔄 Using Core Data fallback: \(selectedMedia.id.uuidString)")
            }
        }
        
        print("🖼️ === END SPLASH SCREEN PHOTO LOADING ===")
    }
}

#Preview {
    SplashScreenView()
        .environmentObject(SpotDataService())
}