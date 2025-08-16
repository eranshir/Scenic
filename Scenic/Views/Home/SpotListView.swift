import SwiftUI
import CoreLocation

struct SpotListView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var spotDataService: SpotDataService
    @State private var navigateToSpot: Spot?
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    // Sort spots by newest first (reverse chronological)
                    ForEach(sortedSpots) { spot in
                        NavigationLink(destination: SpotDetailView(spot: spot)) {
                            DiscoverFeedCard(
                                spot: spot,
                                screenSize: geometry.size
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .ignoresSafeArea(edges: .horizontal)
            .background(Color.black)
        }
    }
    
    private var sortedSpots: [Spot] {
        // Use actual spots from Core Data, sorted by creation date (newest first)
        let spots = spotDataService.spots.isEmpty ? mockSpots : spotDataService.spots
        return spots.sorted { spot1, spot2 in
            // Sort by createdAt (newest first)
            return spot1.createdAt > spot2.createdAt
        }
    }
}

struct DiscoverFeedCard: View {
    let spot: Spot
    let screenSize: CGSize
    @State private var imageOpacity: Double = 0
    
    // Calculate dynamic height based on aspect ratio
    private var cardHeight: CGFloat {
        // Make cards taller for more immersive experience
        // Vary height slightly based on spot to create visual interest
        let baseHeight = screenSize.height * 0.75 // 75% of screen height
        let variation = Double(spot.title.hashValue % 100) / 100.0 * 50
        return baseHeight + variation
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background photo - full bleed
            if let firstMedia = spot.media.first {
                UnifiedPhotoView(
                    photoIdentifier: firstMedia.url,
                    targetSize: CGSize(width: screenSize.width, height: cardHeight),
                    contentMode: .fill
                )
                .frame(width: screenSize.width, height: cardHeight)
                .clipped()
                .opacity(imageOpacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.3)) {
                        imageOpacity = 1
                    }
                }
            } else {
                // Fallback gradient
                LinearGradient(
                    colors: [
                        Color(hue: Double(spot.title.hashValue % 360) / 360.0, saturation: 0.7, brightness: 0.6),
                        Color.black.opacity(0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: screenSize.width, height: cardHeight)
                .overlay(
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.2))
                )
            }
            
            // Vignette overlay for better text readability
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.5),
                    .init(color: .black.opacity(0.3), location: 0.7),
                    .init(color: .black.opacity(0.6), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: screenSize.width, height: cardHeight)
            
            // Content overlay
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                
                // Main content area
                VStack(alignment: .leading, spacing: 8) {
                    // Tags and metadata row
                    HStack(alignment: .center, spacing: 8) {
                        // Location badge
                        if let locality = spot.locality ?? spot.administrativeArea ?? spot.country {
                            Label(locality, systemImage: "location.fill")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial.opacity(0.8), in: Capsule())
                        }
                        
                        // Time indicator if golden/blue hour
                        if let timing = getOptimalTiming(for: spot) {
                            Label(timing, systemImage: "sun.max.fill")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial.opacity(0.8), in: Capsule())
                        }
                        
                        Spacer()
                        
                        // Engagement indicators
                        if spot.voteCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.caption)
                                Text("\(spot.voteCount)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial.opacity(0.8), in: Capsule())
                        }
                    }
                    
                    // Title
                    Text(spot.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .lineLimit(2)
                    
                    // Show creation info
                    HStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.caption)
                        Text("Explorer")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white.opacity(0.8))
                    
                    // Tags
                    if !spot.subjectTags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(spot.subjectTags.prefix(3), id: \.self) { tag in
                                Text("#\(tag.lowercased())")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }
                    
                    // Date added
                    Text(formatRelativeDate(spot.createdAt))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(width: screenSize.width, height: cardHeight)
        .contentShape(Rectangle())
    }
    
    private func getOptimalTiming(for spot: Spot) -> String? {
        // Check sun snapshot for optimal timing
        if let sunSnapshot = spot.sunSnapshot {
            // Check if spot was captured during golden or blue hour
            if sunSnapshot.goldenHourStartUTC != nil || sunSnapshot.goldenHourEndUTC != nil {
                return "Golden Hour"
            } else if sunSnapshot.blueHourStartUTC != nil || sunSnapshot.blueHourEndUTC != nil {
                return "Blue Hour"
            }
        }
        return nil
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        SpotListView()
            .environmentObject(AppState())
            .environmentObject(SpotDataService())
    }
}