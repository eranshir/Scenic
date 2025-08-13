import SwiftUI

struct SpotListView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) { // Minimal spacing between cells
                ForEach(mockSpots) { spot in
                    NavigationLink(destination: SpotDetailView(spot: spot)) {
                        SpotListCard(spot: spot)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .background(Color.black) // Dark background to show minimal spacing
    }
}

struct SpotListCard: View {
    let spot: Spot
    
    var body: some View {
        ZStack {
            // Full-screen photo background
            SpotPhotoBackground(spot: spot)
            
            // Metadata overlay
            SpotMetadataOverlay(spot: spot)
        }
        .frame(height: 300) // Fixed height for consistent feed
        .clipped() // No rounded corners
    }
}

struct SpotPhotoBackground: View {
    let spot: Spot
    
    var body: some View {
        Group {
            if let firstMedia = spot.media.first,
               let uiImage = UIImage(named: firstMedia.url) {
                // Use actual photo if available
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Fallback gradient with spot-specific colors
                LinearGradient(
                    colors: gradientColors(for: spot),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    // Subtle pattern overlay
                    VStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.3))
                        Text("📍")
                            .font(.system(size: 20))
                    }
                )
            }
        }
    }
    
    private func gradientColors(for spot: Spot) -> [Color] {
        // Generate unique colors based on spot characteristics
        let hue = Double(spot.title.hashValue % 360) / 360.0
        return [
            Color(hue: hue, saturation: 0.6, brightness: 0.8),
            Color(hue: hue + 0.1, saturation: 0.7, brightness: 0.6),
            Color(hue: hue + 0.2, saturation: 0.5, brightness: 0.4)
        ]
    }
}

struct SpotMetadataOverlay: View {
    let spot: Spot
    
    var body: some View {
        VStack {
            // Top overlay - Tags
            HStack {
                HStack(spacing: 6) {
                    ForEach(spot.subjectTags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                            .foregroundColor(.white)
                    }
                }
                Spacer()
                
                // Engagement stats
                HStack(spacing: 12) {
                    HStack(spacing: 3) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                        Text("\(spot.voteCount)")
                            .font(.caption.bold())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    
                    if !spot.comments.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "message.fill")
                                .font(.caption)
                            Text("\(spot.comments.count)")
                                .font(.caption.bold())
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            Spacer()
            
            // Bottom overlay - Title and details
            VStack(alignment: .leading, spacing: 8) {
                Text(spot.title)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                
                HStack {
                    Label(spot.difficulty.displayName, systemImage: "figure.hiking")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                    
                    // Sun times if available
                    if let snapshot = spot.sunSnapshot {
                        HStack(spacing: 8) {
                            if let sunrise = snapshot.sunriseUTC {
                                HStack(spacing: 2) {
                                    Image(systemName: "sunrise.fill")
                                        .font(.caption)
                                    Text(formatTime(sunrise))
                                        .font(.caption.bold())
                                }
                                .foregroundColor(.orange)
                            }
                            if let sunset = snapshot.sunsetUTC {
                                HStack(spacing: 2) {
                                    Image(systemName: "sunset.fill")
                                        .font(.caption)
                                    Text(formatTime(sunset))
                                        .font(.caption.bold())
                                }
                                .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        SpotListView()
            .environmentObject(AppState())
    }
}