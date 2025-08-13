import SwiftUI
import MapKit
import UIKit
import CoreLocation

struct SpotDetailView: View {
    let spot: Spot
    @EnvironmentObject var appState: AppState
    @State private var showingShareSheet = false
    @State private var showingAddToPlan = false
    @State private var showingPhotoDetail = false
    @State private var selectedPhotoIndex = 0
    @State private var showingNavigationOptions = false
    @State private var selectedLocation: CLLocationCoordinate2D?
    
    var body: some View {
        GeometryReader { geometry in
            let safeArea = geometry.safeAreaInsets
            let availableHeight = geometry.size.height - safeArea.top - safeArea.bottom
            
            VStack(spacing: 0) {
                // Top Half - Photos and Title (proportional height)
                VStack(spacing: 0) {
                    mediaCarousel
                    headerSection
                        .padding()
                }
                .frame(height: availableHeight * 0.5)
                
                // Bottom Half - Access & Route Section
                accessRouteSection
                    .frame(height: availableHeight * 0.5)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(.container, edges: .bottom)
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
        .sheet(isPresented: $showingPhotoDetail) {
            PhotoDetailView(
                media: spot.media, 
                selectedIndex: selectedPhotoIndex,
                spot: spot
            )
        }
        .confirmationDialog("Navigate to Location", isPresented: $showingNavigationOptions, titleVisibility: .visible) {
            Button("Apple Maps") {
                openInAppleMaps()
            }
            Button("Google Maps") {
                openInGoogleMaps()
            }
            Button("Waze") {
                openInWaze()
            }
        } message: {
            Text("Choose your preferred navigation app")
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
                // Heading-based circular gallery with tap support
                SimpleHeadingGallery(
                    media: spot.media,
                    onPhotoTap: { index in
                        selectedPhotoIndex = index
                        showingPhotoDetail = true
                    }
                )
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(spot.title)
                .font(.largeTitle)
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var accessRouteSection: some View {
        VStack(spacing: 0) {
            // Interactive map with both locations
            Map(initialPosition: .region(MKCoordinateRegion(
                center: spot.location,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))) {
                // Spot marker
                Marker("Photo Spot", coordinate: spot.location)
                    .tint(.green)
                
                // Parking marker (if available)
                if let parkingLocation = spot.accessInfo?.parkingLocation {
                    Marker("Parking", coordinate: parkingLocation)
                        .tint(.blue)
                }
            }
            .frame(maxHeight: .infinity)
            .onTapGesture {
                // Default to spot location when map is tapped
                selectedLocation = spot.location
                showingNavigationOptions = true
            }
        }
        .background(Color(.systemBackground))
    }
    
    
    private func openInAppleMaps() {
        guard let location = selectedLocation else { return }
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: location))
        mapItem.name = spot.title
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
    
    private func openInGoogleMaps() {
        guard let location = selectedLocation else { return }
        let urlString = "comgooglemaps://?daddr=\(location.latitude),\(location.longitude)&directionsmode=driving"
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // Fallback to web
            let webUrlString = "https://maps.google.com/maps?daddr=\(location.latitude),\(location.longitude)"
            if let webUrl = URL(string: webUrlString) {
                UIApplication.shared.open(webUrl)
            }
        }
    }
    
    private func openInWaze() {
        guard let location = selectedLocation else { return }
        let urlString = "waze://?ll=\(location.latitude),\(location.longitude)&navigate=yes"
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // Fallback to web
            let webUrlString = "https://waze.com/ul?ll=\(location.latitude),\(location.longitude)&navigate=yes"
            if let webUrl = URL(string: webUrlString) {
                UIApplication.shared.open(webUrl)
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
    let onPhotoTap: (Int) -> Void
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
                            
                            // Tap indicator overlay (subtle)
                            if index == (baseOffset + currentIndex) {
                                VStack {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "hand.tap.fill")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                            .padding(8)
                                            .background(.ultraThinMaterial)
                                            .clipShape(Circle())
                                    }
                                    Spacer()
                                }
                                .padding(12)
                            }
                        }
                        .frame(width: itemWidth)
                        .clipped()
                        .cornerRadius(16)
                        .scaleEffect(index == (baseOffset + currentIndex) ? 1.0 : 0.9)
                        .opacity(index == (baseOffset + currentIndex) ? 1.0 : 0.7)
                        .animation(.easeInOut(duration: 0.3), value: currentIndex)
                        .onTapGesture {
                            if index == (baseOffset + currentIndex) {
                                // Calculate the real index in the original media array
                                let realIndex = currentIndex % sortedMedia.count
                                let adjustedIndex = realIndex < 0 ? realIndex + sortedMedia.count : realIndex
                                onPhotoTap(adjustedIndex)
                            }
                        }
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

struct PhotoDetailView: View {
    let media: [Media]
    @State var selectedIndex: Int
    let spot: Spot
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var selectedTab = 0
    
    private var currentPhoto: Media {
        media[safe: selectedIndex] ?? media[0]
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let photoHeight = geometry.size.height * 0.6 // 60% for photo
                let detailHeight = geometry.size.height * 0.4 // 40% for details
                
                VStack(spacing: 0) {
                    // Full screen photo
                    photoSection
                        .frame(height: photoHeight)
                    
                    // Tabbed details section
                    VStack(spacing: 0) {
                        // Tab selector
                        HStack(spacing: 0) {
                            TabButton(title: "Details", isSelected: selectedTab == 0) {
                                selectedTab = 0
                            }
                            TabButton(title: "Camera", isSelected: selectedTab == 1) {
                                selectedTab = 1
                            }
                            TabButton(title: "Sun", isSelected: selectedTab == 2) {
                                selectedTab = 2
                            }
                            TabButton(title: "Tips", isSelected: selectedTab == 3) {
                                selectedTab = 3
                            }
                        }
                        .background(Color(.systemGray6))
                        
                        // Tab content
                        ScrollView {
                            VStack(spacing: 16) {
                                switch selectedTab {
                                case 0:
                                    photographyDetailsSection
                                case 1:
                                    cameraSettingsSection
                                case 2:
                                    sunTimingSection
                                case 3:
                                    tipsSection
                                default:
                                    photographyDetailsSection
                                }
                                
                                photographerSection
                            }
                            .padding()
                        }
                        .frame(height: detailHeight - 50) // Subtract tab height
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { showingShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [currentPhoto.url, "Amazing photo from \(spot.title) on Scenic!"])
        }
    }
    
    private var photoSection: some View {
        ZStack {
            // Photo
            if let uiImage = UIImage(named: currentPhoto.url) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(4/3, contentMode: .fit)
                    .overlay(
                        VStack {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text(currentPhoto.url)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    )
            }
            
            // Navigation arrows if multiple photos
            if media.count > 1 {
                HStack {
                    Button(action: previousPhoto) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.8))
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .disabled(selectedIndex == 0)
                    
                    Spacer()
                    
                    Button(action: nextPhoto) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.8))
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .disabled(selectedIndex == media.count - 1)
                }
                .padding()
            }
        }
    }
    
    private var photographyDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Photo Details", icon: "info.circle.fill")
            
            VStack(spacing: 8) {
                // Capture date and time - using mock data for now
                DetailRow(
                    icon: "calendar",
                    title: "Captured",
                    value: "Monday, August 12, 2025"
                )
                
                DetailRow(
                    icon: "clock",
                    title: "Local Time",
                    value: "5:30 PM"
                )
                
                // GPS heading
                if let heading = currentPhoto.exifData?.gpsDirection {
                    DetailRow(
                        icon: "safari",
                        title: "Direction",
                        value: "\(Int(heading))° (\(compassDirection(heading)))"
                    )
                }
                
                // GPS coordinates - using spot location as fallback
                DetailRow(
                    icon: "location.fill",
                    title: "GPS Location",
                    value: String(format: "%.6f, %.6f", spot.location.latitude, spot.location.longitude)
                )
            }
        }
    }
    
    private var sunTimingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Sun & Light Conditions", icon: "sun.max.fill")
            
            VStack(spacing: 8) {
                // Mock sun timing data - in real app would calculate based on date/location
                DetailRow(
                    icon: "sunrise.fill",
                    title: "Sunrise",
                    value: "6:42 AM"
                )
                
                DetailRow(
                    icon: "sunset.fill",
                    title: "Sunset",
                    value: "7:18 PM"
                )
                
                DetailRow(
                    icon: "sun.max",
                    title: "Golden Hour",
                    value: "6:42 - 7:30 AM, 6:30 - 7:18 PM"
                )
                
                DetailRow(
                    icon: "moon.stars",
                    title: "Blue Hour",
                    value: "6:10 - 6:42 AM, 7:18 - 7:50 PM"
                )
                
                // Time relative to sunset/sunrise
                DetailRow(
                    icon: "clock.arrow.2.circlepath",
                    title: "Photo Timing",
                    value: "2h 15m before sunset" // Mock calculation
                )
            }
        }
    }
    
    private var cameraSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Camera & Settings", icon: "camera.fill")
            
            VStack(spacing: 8) {
                // Camera info - using mock data for now  
                DetailRow(
                    icon: "camera",
                    title: "Camera",
                    value: "Canon EOS R5"
                )
                
                DetailRow(
                    icon: "camera.aperture",
                    title: "Lens",
                    value: "RF 24-70mm f/2.8L IS USM"
                )
                
                // Camera settings in a row of badges
                HStack(spacing: 8) {
                    SettingBadge(label: "35mm")
                    SettingBadge(label: "f/8.0")
                    SettingBadge(label: "ISO 100")
                    SettingBadge(label: "1/125s")
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Photography Tips", icon: "lightbulb.fill")
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Best captured during golden hour for warm, soft lighting. Use a tripod for sharp details and consider graduated ND filters to balance the exposure between sky and foreground.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                // Mock tips - in real app these would come from the photographer
                VStack(alignment: .leading, spacing: 4) {
                    Label("Arrive 30 minutes before golden hour", systemImage: "clock")
                        .font(.caption)
                    Label("Bring graduated ND filters", systemImage: "camera.filters")
                        .font(.caption)
                    Label("Focus on hyperfocal distance", systemImage: "target")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
    }
    
    private var photographerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text("@photographer")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Explorer • 247 spots shared")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Text("Follow")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
            }
            
            // License information
            HStack {
                Image(systemName: "doc.text")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Licensed under CC-BY-NC")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func previousPhoto() {
        if selectedIndex > 0 {
            selectedIndex -= 1
        }
    }
    
    private func nextPhoto() {
        if selectedIndex < media.count - 1 {
            selectedIndex += 1
        }
    }
    
    private func formatCaptureDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
    
    private func formatLocalTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func compassDirection(_ heading: Float) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((heading + 22.5) / 45.0) % 8
        return directions[index]
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(title)
                .font(.footnote)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.footnote)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct SettingBadge: View {
    let label: String
    
    var body: some View {
        Text(label)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray5))
            .cornerRadius(6)
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.green : Color.clear)
        }
    }
}

// Safe array access extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        SpotDetailView(spot: mockSpots[0])
            .environmentObject(AppState())
    }
}