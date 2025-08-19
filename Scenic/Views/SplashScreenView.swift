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
        // First, let's see what files are actually in the cache
        print("🖼️ === DEBUGGING SPLASH SCREEN PHOTO LOADING ===")
        PhotoCacheService.shared.listCachedFiles()
        
        // Get all cached photos from Core Data
        let cachedMedia = spotDataService.getAllCachedMedia()
        print("🖼️ SplashScreen: Found \(cachedMedia.count) total cached media from Core Data")
        
        // Debug: Print some sample URLs
        for (index, media) in cachedMedia.prefix(5).enumerated() {
            print("🖼️ Sample media \(index): URL=\(media.url), ID=\(media.id)")
        }
        
        // Instead of filtering, let's just try to use any cached media and see what happens
        if !cachedMedia.isEmpty {
            // Pick a random photo
            let randomIndex = Int.random(in: 0..<cachedMedia.count)
            let selectedMedia = cachedMedia[randomIndex]
            
            // Try different identifier formats
            let identifierOptions = [
                selectedMedia.id.uuidString, // Just the UUID
                "\(selectedMedia.id.uuidString).jpg", // UUID with .jpg
                selectedMedia.url, // Original URL
                selectedMedia.url.replacingOccurrences(of: ".jpg", with: ""), // Remove .jpg if present
            ]
            
            // Test each option to see which files exist
            print("🖼️ Testing identifier options for media ID \(selectedMedia.id):")
            for (index, option) in identifierOptions.enumerated() {
                let filename = option.contains("://") ? "\(selectedMedia.id.uuidString).jpg" : "\(option).jpg"
                let exists = PhotoCacheService.shared.fileExists(filename: filename)
                print("🖼️   Option \(index): '\(option)' -> filename '\(filename)' exists: \(exists)")
                
                if exists && randomPhoto == nil {
                    randomPhoto = option
                    print("🖼️ ✅ Selected option \(index) as random photo identifier: \(option)")
                }
            }
            
            // Fallback: just use the UUID
            if randomPhoto == nil {
                randomPhoto = selectedMedia.id.uuidString
                print("🖼️ 🔄 Fallback: using UUID as identifier: \(selectedMedia.id.uuidString)")
            }
            
        } else {
            print("🖼️ ❌ No cached media found in Core Data")
        }
        
        print("🖼️ === END DEBUGGING ===")
    }
}

#Preview {
    SplashScreenView()
        .environmentObject(SpotDataService())
}