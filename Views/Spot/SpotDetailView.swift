import SwiftUI
import MapKit

struct SpotDetailView: View {
    let spot: Spot
    @EnvironmentObject var appState: AppState
    @State private var showingShareSheet = false
    @State private var showingAddToPlan = false
    @State private var selectedTab = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                mediaCarousel
                
                VStack(spacing: 16) {
                    headerSection
                    sunWeatherSection
                    locationSection
                    exifSection
                    accessSection
                    commentsSection
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: { showingAddToPlan = true }) {
                        Image(systemName: "calendar.badge.plus")
                    }
                    
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddToPlan) {
            AddToPlanView(spot: spot)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [spot.title, "Check out this photo spot on Scenic!"])
        }
    }
    
    private var mediaCarousel: some View {
        Group {
            if spot.media.isEmpty {
                // Fallback for spots without media
                ZStack {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color.green.opacity(0.3), Color.blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.5))
                        Text("No photos available")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.headline)
                    }
                }
            } else {
                // Heading-based circular gallery
                SimpleHeadingGallery(media: spot.media)
            }
        }
        .frame(height: 400)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(spot.title)
                .font(.largeTitle)
                .bold()
            
            HStack {
                ForEach(spot.subjectTags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                }
            }
            
            HStack {
                Button(action: {}) {
                    HStack {
                        Image(systemName: "arrow.up")
                        Text("\(spot.voteCount)")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: {}) {
                    HStack {
                        Image(systemName: "bookmark")
                        Text("Save")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text("@photographer")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Explorer")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var sunWeatherSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Light & Weather", icon: "sun.max.fill")
            
            SunTimesWidget()
            
            WeatherWidget()
        }
    }
    
    private var locationSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Location", icon: "location.fill")
            
            Map(initialPosition: .region(MKCoordinateRegion(
                center: spot.location,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))) {
                Marker(spot.title, coordinate: spot.location)
                    .tint(.green)
            }
            .frame(height: 200)
            .cornerRadius(12)
            .allowsHitTesting(false)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("GPS Coordinates")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(spot.location.latitude, specifier: "%.6f"), \(spot.location.longitude, specifier: "%.6f")")
                        .font(.footnote)
                        .fontDesign(.monospaced)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "doc.on.doc")
                }
                
                Button(action: {}) {
                    Image(systemName: "location.north.line.fill")
                        .rotationEffect(.degrees(Double(spot.headingDegrees ?? 0)))
                }
            }
            
            if let heading = spot.headingDegrees {
                HStack {
                    Image(systemName: "safari")
                    Text("Heading: \(heading)°")
                        .font(.caption)
                    Spacer()
                }
            }
            
            if let elevation = spot.elevationMeters {
                HStack {
                    Image(systemName: "arrow.up.and.down")
                    Text("Elevation: \(elevation)m")
                        .font(.caption)
                    Spacer()
                }
            }
        }
    }
    
    private var exifSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Camera Settings", icon: "camera.fill")
            
            ExifDataView()
        }
    }
    
    private var accessSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Access & Route", icon: "figure.hiking")
            
            AccessInfoView(difficulty: spot.difficulty)
        }
    }
    
    private var commentsSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Comments", icon: "message.fill")
            
            if spot.comments.isEmpty {
                Text("No comments yet. Be the first!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(spot.comments) { comment in
                    CommentRow(comment: comment)
                }
            }
            
            Button(action: {}) {
                HStack {
                    Image(systemName: "plus.message.fill")
                    Text("Add Comment")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.green)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SimpleHeadingGallery: View {
    let media: [Media]
    @State private var scrollOffset: CGFloat = 0
    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0
    
    // Sort media by heading for circular ordering
    private var sortedMedia: [Media] {
        let mediaWithHeading = media.filter { $0.exifData?.gpsDirection != nil }
        let mediaWithoutHeading = media.filter { $0.exifData?.gpsDirection == nil }
        
        // Sort media with heading by compass direction
        let sortedWithHeading = mediaWithHeading.sorted { media1, media2 in
            guard let heading1 = media1.exifData?.gpsDirection,
                  let heading2 = media2.exifData?.gpsDirection else { return false }
            return heading1 < heading2
        }
        
        // Append media without heading at the end
        return sortedWithHeading + mediaWithoutHeading
    }
    
    // Create extended array for infinite scrolling: [...prev, current array, next...]
    private var infiniteMedia: [Media] {
        guard !sortedMedia.isEmpty else { return [] }
        return sortedMedia + sortedMedia + sortedMedia // Triple the array
    }
    
    // Start from middle section to allow scrolling both directions
    private var baseOffset: Int {
        sortedMedia.count
    }
    
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main gallery - horizontal scroll with partial photos visible
            GeometryReader { geometry in
                let screenWidth = geometry.size.width
                let itemWidth = screenWidth * 0.85 // 85% of screen width to show adjacent photos
                let itemSpacing: CGFloat = 1 // Minimal spacing between photos
                let centerOffset = (screenWidth - itemWidth) / 2
                
                HStack(spacing: itemSpacing) {
                    ForEach(Array(infiniteMedia.enumerated()), id: \.offset) { index, mediaItem in
                        // Image with fallback
                        ZStack {
                            // Try to load image, fallback to placeholder
                            if let uiImage = UIImage(named: mediaItem.url) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                // Fallback placeholder with gradient and image info
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.3),
                                        Color.green.opacity(0.3),
                                        Color.purple.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo.fill")
                                            .font(.system(size: 30))
                                            .foregroundColor(.white)
                                        Text(mediaItem.url)
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.center)
                                        if let heading = mediaItem.exifData?.gpsDirection {
                                            Text("\(Int(heading))°")
                                                .font(.title2.bold())
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding()
                                )
                            }
                        }
                        .frame(width: itemWidth)
                        .clipped()
                        .cornerRadius(16)
                        .scaleEffect(index == (baseOffset + currentIndex) ? 1.0 : 0.9)
                        .opacity(index == (baseOffset + currentIndex) ? 1.0 : 0.7)
                        .animation(.easeInOut(duration: 0.3), value: currentIndex)
                    }
                }
                .offset(x: centerOffset - CGFloat(baseOffset + currentIndex) * (itemWidth + itemSpacing) + dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let threshold: CGFloat = itemWidth * 0.25
                            
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if value.translation.width > threshold {
                                    // Swipe right - go to previous
                                    currentIndex -= 1
                                } else if value.translation.width < -threshold {
                                    // Swipe left - go to next  
                                    currentIndex += 1
                                }
                                dragOffset = 0
                            }
                            
                            // Reset to center section when we get too far from it
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                resetToCenterIfNeeded()
                            }
                        }
                )
            }
            .aspectRatio(4/3, contentMode: .fit)
            
            // Small compass rose in bottom right corner
            if let currentHeading = currentHeading {
                CompactCompassRose(heading: currentHeading)
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            // Start with the first photo that has heading data, or first photo if none have heading
            if let firstWithHeading = sortedMedia.firstIndex(where: { $0.exifData?.gpsDirection != nil }) {
                currentIndex = firstWithHeading
            }
        }
    }
    
    private var currentHeading: Float? {
        let realIndex = currentIndex % sortedMedia.count
        let adjustedIndex = realIndex < 0 ? realIndex + sortedMedia.count : realIndex
        guard adjustedIndex >= 0 && adjustedIndex < sortedMedia.count else { return nil }
        return sortedMedia[adjustedIndex].exifData?.gpsDirection
    }
    
    private func resetToCenterIfNeeded() {
        // If we're too far from center, reset without animation
        if currentIndex < -sortedMedia.count / 2 || currentIndex > sortedMedia.count + sortedMedia.count / 2 {
            let normalizedIndex = currentIndex % sortedMedia.count
            let adjustedIndex = normalizedIndex < 0 ? normalizedIndex + sortedMedia.count : normalizedIndex
            currentIndex = adjustedIndex
        }
    }
}

struct CompactCompassRose: View {
    let heading: Float
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 60, height: 60)
            
            // Compass ring
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                .frame(width: 50, height: 50)
            
            // Cardinal directions (N, E, S, W)
            ForEach(["N", "E", "S", "W"], id: \.self) { direction in
                Text(direction)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .offset(y: -22)
                    .rotationEffect(.degrees(rotationForDirection(direction)))
            }
            
            // Heading needle
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.red)
                .frame(width: 2, height: 18)
                .offset(y: -9)
                .rotationEffect(.degrees(Double(heading)))
                .animation(.easeInOut(duration: 0.3), value: heading)
            
            // Center dot
            Circle()
                .fill(Color.white)
                .frame(width: 3, height: 3)
            
            // Heading text below compass
            Text("\(Int(heading))°")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .offset(y: 35)
        }
    }
    
    private func rotationForDirection(_ direction: String) -> Double {
        switch direction {
        case "N": return 0
        case "E": return 90
        case "S": return 180
        case "W": return 270
        default: return 0
        }
    }
}

#Preview {
    NavigationStack {
        SpotDetailView(spot: mockSpots[0])
            .environmentObject(AppState())
    }
}