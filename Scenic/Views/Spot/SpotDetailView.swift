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
    
    // Computed property to check sync status
    private var isSynced: Bool {
        // Check if all media have Cloudinary URLs (not local_)
        let allMediaSynced = spot.media.allSatisfy { media in
            !media.url.hasPrefix("local_")
        }
        return spot.media.isEmpty || allMediaSynced
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title section at the top
            spotTitleSection
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            
            GeometryReader { geometry in
                let safeArea = geometry.safeAreaInsets
                let availableHeight = geometry.size.height - safeArea.top - safeArea.bottom
                
                VStack(spacing: 0) {
                    // Photos carousel - optimized for better balance
                    mediaCarousel
                        .frame(height: availableHeight * 0.5)
                    
                    // Bottom section - Access & Route with more space
                    accessRouteSection
                        .frame(height: availableHeight * 0.5)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(.container, edges: .bottom)
        .sheet(isPresented: $showingAddToPlan) {
            AddToPlanView(spot: spot)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [spot.title, "Check out this photo spot on Scenic!"])
        }
        .sheet(isPresented: $showingPhotoDetail) {
            ComprehensivePhotoDetailView(
                media: spot.media,
                selectedIndex: selectedPhotoIndex,
                onDismiss: { showingPhotoDetail = false }
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
        VStack {
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
                // Enhanced infinite carousel with proper implementation
                VStack(spacing: 8) {
                    // Main photo carousel with infinite scroll
                    InfinitePhotoCarousel(
                        media: spot.media,
                        selectedIndex: $selectedPhotoIndex,
                        onPhotoTap: { showingPhotoDetail = true }
                    )
                    
                    // Enhanced photo timing analysis
                    if let currentMedia = spot.media.indices.contains(selectedPhotoIndex) ? spot.media[selectedPhotoIndex] : nil,
                       let captureDate = currentMedia.captureTimeUTC ?? currentMedia.exifData?.dateTimeOriginal {
                        // Use photo's GPS location if available, otherwise use spot location
                        let photoLocation = {
                            if let lat = currentMedia.exifData?.gpsLatitude, 
                               let lng = currentMedia.exifData?.gpsLongitude {
                                return CLLocationCoordinate2D(latitude: lat, longitude: lng)
                            } else {
                                return spot.location
                            }
                        }()
                        
                        EnhancedPhotoTimingAnalysis(
                            captureDate: captureDate, 
                            location: photoLocation,
                            photoIndex: selectedPhotoIndex
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .id("\(selectedPhotoIndex)-\(captureDate)") // Force view refresh on photo change
                    }
                }
                .onAppear {
                    // Start with the first photo that has heading data
                    if let firstWithHeading = spot.media.firstIndex(where: { $0.exifData?.gpsDirection != nil }) {
                        selectedPhotoIndex = firstWithHeading
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    private var spotTitleSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(spot.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Sync status icon
                    Image(systemName: isSynced ? "checkmark.icloud.fill" : "icloud.and.arrow.up")
                        .font(.system(size: 18))
                        .foregroundColor(isSynced ? .green : .orange)
                        .symbolEffect(.pulse, isActive: !isSynced)
                        .help(isSynced ? "Synced to cloud" : "Not yet synced")
                }
                
                HStack(spacing: 8) {
                    Label(spot.difficulty.displayName, systemImage: spot.difficulty.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !spot.subjectTags.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(spot.subjectTags.prefix(3).joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private var accessRouteSection: some View {
        VStack(spacing: 0) {
            // Interactive map with both locations
            Map(initialPosition: .region(MKCoordinateRegion(
                center: isValidCoordinate(spot.location) ? spot.location : CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
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
    
    // MARK: - Photo Carousel Helpers
    
    // Sort media by heading for circular ordering
    private var sortedMedia: [Media] {
        let mediaWithHeading = spot.media.filter { $0.exifData?.gpsDirection != nil }
        let mediaWithoutHeading = spot.media.filter { $0.exifData?.gpsDirection == nil }
        
        // Sort media with heading by compass direction
        let sortedWithHeading = mediaWithHeading.sorted { media1, media2 in
            guard let heading1 = media1.exifData?.gpsDirection,
                  let heading2 = media2.exifData?.gpsDirection else { return false }
            return heading1 < heading2
        }
        
        // Append media without heading at the end
        return sortedWithHeading + mediaWithoutHeading
    }
    
    private var currentHeading: Float? {
        guard sortedMedia.indices.contains(selectedPhotoIndex) else { return nil }
        return sortedMedia[selectedPhotoIndex].exifData?.gpsDirection
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

// MARK: - Carousel Helper Views


struct CompactHeadingInfoView: View {
    let media: Media
    
    var body: some View {
        HStack {
            if let heading = media.exifData?.gpsDirection {
                Text("Heading:")
                    .font(.subheadline)
                Text("\(Int(heading))° \(compassDirection(for: heading))")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
            } else {
                Text("No heading data")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // EXIF info
            if let exif = media.exifData {
                HStack(spacing: 12) {
                    if let iso = exif.iso {
                        Text("ISO \(iso)")
                    }
                    if let aperture = exif.fNumber {
                        Text("f/\(String(format: "%.1f", aperture))")
                    }
                    if let shutter = exif.exposureTime {
                        Text(shutter)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func compassDirection(for heading: Float) -> String {
        switch heading {
        case 0..<22.5, 337.5...360: return "N"
        case 22.5..<67.5: return "NE"
        case 67.5..<112.5: return "E"
        case 112.5..<157.5: return "SE"
        case 157.5..<202.5: return "S"
        case 202.5..<247.5: return "SW"
        case 247.5..<292.5: return "W"
        case 292.5..<337.5: return "NW"
        default: return ""
        }
    }
}


// MARK: - Enhanced Photo Timing Analysis

struct EnhancedPhotoTimingAnalysis: View {
    let captureDate: Date
    let location: CLLocationCoordinate2D
    let photoIndex: Int
    
    @State private var sunSnapshot: SunSnapshot?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let snapshot = sunSnapshot {
                // First row: Date and Time
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                            .font(.caption2)
                        Text(captureDate, style: .date)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .foregroundColor(.blue)
                            .font(.caption2)
                        Text(captureDate, style: .time)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                }
                
                // Second row: Sun times and special periods
                HStack {
                    // Sunrise time
                    if let sunrise = snapshot.sunriseUTC {
                        HStack(spacing: 4) {
                            Image(systemName: "sunrise.fill")
                                .foregroundColor(.orange)
                                .font(.caption2)
                            Text(sunrise, style: .time)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }
                    
                    Spacer()
                    
                    // Golden/Blue hour indicator or relative timing
                    if isGoldenHour(captureDate: captureDate, snapshot: snapshot) {
                        HStack(spacing: 4) {
                            Image(systemName: "sun.max.fill")
                                .foregroundColor(.orange)
                                .font(.caption2)
                            Text("Golden Hour")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                    } else if isBlueHour(captureDate: captureDate, snapshot: snapshot) {
                        HStack(spacing: 4) {
                            Image(systemName: "moon.fill")
                                .foregroundColor(.blue)
                                .font(.caption2)
                            Text("Blue Hour")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                    } else if let event = snapshot.closestEvent, let minutes = snapshot.relativeMinutesToEvent {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.secondary)
                                .font(.caption2)
                            let timeDescription = minutes >= 0 ? "\(formatTimeInterval(minutes)) after" : "\(formatTimeInterval(minutes)) before"
                            Text("\(timeDescription) \(eventShortName(event))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Sunset time
                    if let sunset = snapshot.sunsetUTC {
                        HStack(spacing: 4) {
                            Text(sunset, style: .time)
                                .font(.caption2)
                                .fontWeight(.medium)
                            Image(systemName: "sunset.fill")
                                .foregroundColor(.orange)
                                .font(.caption2)
                        }
                    }
                }
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Calculating sun times...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .onAppear {
            calculateSunTimes()
        }
        .onChange(of: captureDate) { _, _ in
            calculateSunTimes()
        }
        .onChange(of: photoIndex) { _, _ in
            calculateSunTimes()
        }
    }
    
    private func calculateSunTimes() {
        // Calculate sun times based on date and location
        // This is a simplified calculation - a production app would use NOAA Solar Position Algorithm
        let calendar = Calendar.current
        
        // Get day of year for seasonal adjustment
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: captureDate) ?? 180
        let latitude = location.latitude
        
        // Simplified calculation for sunrise/sunset times
        // Base times adjusted by latitude and season
        let seasonalOffset = sin(Double(dayOfYear - 80) * .pi / 182.5) * 1.5 // hours variation
        let latitudeOffset = (latitude - 40) * 0.03 // hours per degree from 40°N
        
        // Base sunrise/sunset for 40°N latitude at equinox
        let baseSunriseHour = 6.0 - seasonalOffset + latitudeOffset
        let baseSunsetHour = 18.0 + seasonalOffset - latitudeOffset
        
        // Convert to actual times
        // Validate values before conversion to prevent crashes
        guard baseSunriseHour.isFinite && baseSunsetHour.isFinite else {
            print("⚠️ Invalid sun calculation results (NaN/Infinity), skipping")
            return
        }
        
        let sunriseHour = max(0, min(23, Int(baseSunriseHour.rounded())))
        let sunriseMinute = max(0, min(59, Int(abs(baseSunriseHour - Double(sunriseHour)) * 60)))
        let sunsetHour = max(0, min(23, Int(baseSunsetHour.rounded())))
        let sunsetMinute = max(0, min(59, Int(abs(baseSunsetHour - Double(sunsetHour)) * 60)))
        
        let sunrise = calendar.date(bySettingHour: sunriseHour, minute: sunriseMinute, second: 0, of: captureDate) ?? captureDate
        let sunset = calendar.date(bySettingHour: sunsetHour, minute: sunsetMinute, second: 0, of: captureDate) ?? captureDate
        
        // Golden hour: 1 hour before sunset to 30 min after
        let goldenHourStart = calendar.date(byAdding: .minute, value: -60, to: sunset) ?? sunset
        let goldenHourEnd = calendar.date(byAdding: .minute, value: 30, to: sunset) ?? sunset
        
        // Blue hour: sunset to 45 min after
        let blueHourStart = sunset
        let blueHourEnd = calendar.date(byAdding: .minute, value: 45, to: sunset) ?? sunset
        
        // Find closest solar event
        let events: [(SunSnapshot.SolarEvent, Date)] = [
            (.sunrise, sunrise),
            (.sunset, sunset),
            (.goldenHourStart, goldenHourStart),
            (.goldenHourEnd, goldenHourEnd),
            (.blueHourStart, blueHourStart),
            (.blueHourEnd, blueHourEnd)
        ]
        
        let closestEvent = events.min { abs($0.1.timeIntervalSince(captureDate)) < abs($1.1.timeIntervalSince(captureDate)) }
        let relativeMinutes = closestEvent.map { Int(captureDate.timeIntervalSince($0.1) / 60) }
        
        sunSnapshot = SunSnapshot(
            id: UUID(),
            spotId: UUID(),
            date: captureDate,
            sunriseUTC: sunrise,
            sunsetUTC: sunset,
            goldenHourStartUTC: goldenHourStart,
            goldenHourEndUTC: goldenHourEnd,
            blueHourStartUTC: blueHourStart,
            blueHourEndUTC: blueHourEnd,
            closestEvent: closestEvent?.0,
            relativeMinutesToEvent: relativeMinutes
        )
    }
    
    private func isGoldenHour(captureDate: Date, snapshot: SunSnapshot) -> Bool {
        guard let start = snapshot.goldenHourStartUTC,
              let end = snapshot.goldenHourEndUTC else { return false }
        return captureDate >= start && captureDate <= end
    }
    
    private func isBlueHour(captureDate: Date, snapshot: SunSnapshot) -> Bool {
        guard let start = snapshot.blueHourStartUTC,
              let end = snapshot.blueHourEndUTC else { return false }
        return captureDate >= start && captureDate <= end
    }
    
    private func eventShortName(_ event: SunSnapshot.SolarEvent) -> String {
        switch event {
        case .sunrise: return "sunrise"
        case .sunset: return "sunset"
        case .goldenHourStart: return "golden hour"
        case .goldenHourEnd: return "golden hour"
        case .blueHourStart: return "blue hour"
        case .blueHourEnd: return "blue hour"
        }
    }
    
    private func formatTimeInterval(_ minutes: Int) -> String {
        let absMinutes = abs(minutes)
        let hours = absMinutes / 60
        let remainingMinutes = absMinutes % 60
        
        if hours == 0 {
            return "\(remainingMinutes) minute\(remainingMinutes == 1 ? "" : "s")"
        } else if remainingMinutes == 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s") and \(remainingMinutes) minute\(remainingMinutes == 1 ? "" : "s")"
        }
    }
}

// MARK: - Compact Photo Timing Analysis

struct CompactPhotoTimingAnalysis: View {
    let captureDate: Date
    let location: CLLocationCoordinate2D
    
    @State private var sunSnapshot: SunSnapshot?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let snapshot = sunSnapshot {
                // Sun times and special periods in compact format
                HStack {
                    // Sunrise time
                    if let sunrise = snapshot.sunriseUTC {
                        HStack(spacing: 4) {
                            Image(systemName: "sunrise.fill")
                                .foregroundColor(.orange)
                                .font(.caption2)
                            Text(sunrise, style: .time)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }
                    
                    Spacer()
                    
                    // Golden/Blue hour indicator
                    if isGoldenHour(captureDate: captureDate, snapshot: snapshot) {
                        HStack(spacing: 4) {
                            Image(systemName: "sun.max.fill")
                                .foregroundColor(.orange)
                                .font(.caption2)
                            Text("Golden Hour")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                    } else if isBlueHour(captureDate: captureDate, snapshot: snapshot) {
                        HStack(spacing: 4) {
                            Image(systemName: "moon.fill")
                                .foregroundColor(.blue)
                                .font(.caption2)
                            Text("Blue Hour")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                    } else if let event = snapshot.closestEvent, let minutes = snapshot.relativeMinutesToEvent {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.secondary)
                                .font(.caption2)
                            let timeDescription = minutes >= 0 ? "\(formatTimeInterval(minutes)) after" : "\(formatTimeInterval(minutes)) before"
                            Text("\(timeDescription) \(eventShortName(event))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Sunset time
                    if let sunset = snapshot.sunsetUTC {
                        HStack(spacing: 4) {
                            Text(sunset, style: .time)
                                .font(.caption2)
                                .fontWeight(.medium)
                            Image(systemName: "sunset.fill")
                                .foregroundColor(.orange)
                                .font(.caption2)
                        }
                    }
                }
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Calculating sun times...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .onAppear {
            calculateSunTimes()
        }
    }
    
    private func calculateSunTimes() {
        // Calculate sun times based on date and location
        // This is a simplified calculation - a production app would use NOAA Solar Position Algorithm
        let calendar = Calendar.current
        
        // Get day of year for seasonal adjustment
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: captureDate) ?? 180
        let latitude = location.latitude
        
        // Simplified calculation for sunrise/sunset times
        // Base times adjusted by latitude and season
        let seasonalOffset = sin(Double(dayOfYear - 80) * .pi / 182.5) * 1.5 // hours variation
        let latitudeOffset = (latitude - 40) * 0.03 // hours per degree from 40°N
        
        // Base sunrise/sunset for 40°N latitude at equinox
        let baseSunriseHour = 6.0 - seasonalOffset + latitudeOffset
        let baseSunsetHour = 18.0 + seasonalOffset - latitudeOffset
        
        // Convert to actual times
        // Validate values before conversion to prevent crashes
        guard baseSunriseHour.isFinite && baseSunsetHour.isFinite else {
            print("⚠️ Invalid sun calculation results (NaN/Infinity), skipping")
            return
        }
        
        let sunriseHour = max(0, min(23, Int(baseSunriseHour.rounded())))
        let sunriseMinute = max(0, min(59, Int(abs(baseSunriseHour - Double(sunriseHour)) * 60)))
        let sunsetHour = max(0, min(23, Int(baseSunsetHour.rounded())))
        let sunsetMinute = max(0, min(59, Int(abs(baseSunsetHour - Double(sunsetHour)) * 60)))
        
        let sunrise = calendar.date(bySettingHour: sunriseHour, minute: sunriseMinute, second: 0, of: captureDate) ?? captureDate
        let sunset = calendar.date(bySettingHour: sunsetHour, minute: sunsetMinute, second: 0, of: captureDate) ?? captureDate
        
        // Golden hour: 1 hour before sunset to 30 min after
        let goldenHourStart = calendar.date(byAdding: .minute, value: -60, to: sunset) ?? sunset
        let goldenHourEnd = calendar.date(byAdding: .minute, value: 30, to: sunset) ?? sunset
        
        // Blue hour: sunset to 45 min after
        let blueHourStart = sunset
        let blueHourEnd = calendar.date(byAdding: .minute, value: 45, to: sunset) ?? sunset
        
        // Find closest solar event
        let events: [(SunSnapshot.SolarEvent, Date)] = [
            (.sunrise, sunrise),
            (.sunset, sunset),
            (.goldenHourStart, goldenHourStart),
            (.goldenHourEnd, goldenHourEnd),
            (.blueHourStart, blueHourStart),
            (.blueHourEnd, blueHourEnd)
        ]
        
        let closestEvent = events.min { abs($0.1.timeIntervalSince(captureDate)) < abs($1.1.timeIntervalSince(captureDate)) }
        let relativeMinutes = closestEvent.map { Int(captureDate.timeIntervalSince($0.1) / 60) }
        
        sunSnapshot = SunSnapshot(
            id: UUID(),
            spotId: UUID(),
            date: captureDate,
            sunriseUTC: sunrise,
            sunsetUTC: sunset,
            goldenHourStartUTC: goldenHourStart,
            goldenHourEndUTC: goldenHourEnd,
            blueHourStartUTC: blueHourStart,
            blueHourEndUTC: blueHourEnd,
            closestEvent: closestEvent?.0,
            relativeMinutesToEvent: relativeMinutes
        )
    }
    
    private func isGoldenHour(captureDate: Date, snapshot: SunSnapshot) -> Bool {
        guard let start = snapshot.goldenHourStartUTC,
              let end = snapshot.goldenHourEndUTC else { return false }
        return captureDate >= start && captureDate <= end
    }
    
    private func isBlueHour(captureDate: Date, snapshot: SunSnapshot) -> Bool {
        guard let start = snapshot.blueHourStartUTC,
              let end = snapshot.blueHourEndUTC else { return false }
        return captureDate >= start && captureDate <= end
    }
    
    private func eventShortName(_ event: SunSnapshot.SolarEvent) -> String {
        switch event {
        case .sunrise: return "sunrise"
        case .sunset: return "sunset"
        case .goldenHourStart: return "golden hour"
        case .goldenHourEnd: return "golden hour"
        case .blueHourStart: return "blue hour"
        case .blueHourEnd: return "blue hour"
        }
    }
    
    private func formatTimeInterval(_ minutes: Int) -> String {
        let absMinutes = abs(minutes)
        let hours = absMinutes / 60
        let remainingMinutes = absMinutes % 60
        
        if hours == 0 {
            return "\(remainingMinutes) minute\(remainingMinutes == 1 ? "" : "s")"
        } else if remainingMinutes == 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s") and \(remainingMinutes) minute\(remainingMinutes == 1 ? "" : "s")"
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
                        // Image with async loading
                        ZStack {
                            UnifiedPhotoView(
                                photoIdentifier: mediaItem.url,
                                targetSize: CGSize(width: 400, height: 300),
                                contentMode: .fill
                            )
                            
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
                .offset(x: calculateHStackOffset(centerOffset: centerOffset, itemWidth: itemWidth, itemSpacing: itemSpacing))
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
            .aspectRatio(4/3, contentMode: ContentMode.fit)
            
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
    
    private func calculateHStackOffset(centerOffset: CGFloat, itemWidth: CGFloat, itemSpacing: CGFloat) -> CGFloat {
        let baseOffsetFloat = CGFloat(baseOffset + currentIndex)
        let itemTotalWidth = itemWidth + itemSpacing
        return centerOffset - baseOffsetFloat * itemTotalWidth + dragOffset
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
            // Photo with async loading
            UnifiedLargePhotoView(photoIdentifier: currentPhoto.url)
                .aspectRatio(4/3, contentMode: ContentMode.fit)
            
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

// MARK: - Cached Photo Detail View
struct CachedPhotoDetailView: View {
    let cdMediaItems: [CDMedia]
    @State var selectedIndex: Int
    let spot: Spot
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var selectedTab = 0
    
    // Sort media by heading for consistency with gallery
    private var sortedCDMedia: [CDMedia] {
        let mediaWithHeading = cdMediaItems.filter { 
            $0.exifGpsDirection != -1 && !$0.exifGpsDirection.isNaN 
        }
        let mediaWithoutHeading = cdMediaItems.filter { 
            $0.exifGpsDirection == -1 || $0.exifGpsDirection.isNaN 
        }
        
        let sortedWithHeading = mediaWithHeading.sorted { cdMedia1, cdMedia2 in
            return cdMedia1.exifGpsDirection < cdMedia2.exifGpsDirection
        }
        
        return sortedWithHeading + mediaWithoutHeading
    }
    
    private var currentCDMedia: CDMedia {
        sortedCDMedia[safe: selectedIndex] ?? sortedCDMedia[0]
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let photoHeight = geometry.size.height * 0.6 // 60% for photo
                let detailHeight = geometry.size.height * 0.4 // 40% for details
                
                VStack(spacing: 0) {
                    // Full screen photo
                    cachedPhotoSection
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
                            Group {
                                switch selectedTab {
                                case 0:
                                    cachedDetailsTab
                                case 1:
                                    cachedCameraTab
                                case 2:
                                    cachedSunTab
                                case 3:
                                    cachedTipsTab
                                default:
                                    cachedDetailsTab
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .frame(height: detailHeight)
                        .background(Color(.systemBackground))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingShareSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: ["Check out this amazing photo spot on Scenic!", spot.title])
        }
    }
    
    private var cachedPhotoSection: some View {
        ZStack {
            // Photo with cached loading
            // TODO: Use CachedPhotoView once compilation issues are resolved
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    Text("Photo")
                        .foregroundColor(.gray)
                )
            .aspectRatio(4/3, contentMode: ContentMode.fit)
            
            // Navigation arrows if multiple photos
            if sortedCDMedia.count > 1 {
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedIndex = max(0, selectedIndex - 1)
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .disabled(selectedIndex == 0)
                    .opacity(selectedIndex == 0 ? 0.5 : 1.0)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedIndex = min(sortedCDMedia.count - 1, selectedIndex + 1)
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .disabled(selectedIndex == sortedCDMedia.count - 1)
                    .opacity(selectedIndex == sortedCDMedia.count - 1 ? 0.5 : 1.0)
                }
                .padding(.horizontal, 20)
            }
            
            // Photo counter
            if sortedCDMedia.count > 1 {
                VStack {
                    HStack {
                        Spacer()
                        Text("\(selectedIndex + 1) of \(sortedCDMedia.count)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(.trailing, 16)
                            .padding(.top, 16)
                    }
                    Spacer()
                }
            }
        }
    }
    
    private var cachedDetailsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let captureTime = currentCDMedia.captureTimeUTC {
                DetailRow(icon: "clock", title: "Captured", value: DateFormatter.photoDetail.string(from: captureTime))
            }
            
            if let filename = currentCDMedia.originalFilename {
                DetailRow(icon: "doc", title: "Filename", value: filename)
            }
            
            if let device = currentCDMedia.device {
                DetailRow(icon: "iphone", title: "Device", value: device)
            }
            
            Spacer()
        }
    }
    
    private var cachedCameraTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Camera info from EXIF data
            if let make = currentCDMedia.exifMake, let model = currentCDMedia.exifModel {
                DetailRow(icon: "camera", title: "Camera", value: "\(make) \(model)")
            }
            
            if let lens = currentCDMedia.exifLens {
                DetailRow(icon: "camera.macro", title: "Lens", value: lens)
            } else if let lens = currentCDMedia.lens {
                DetailRow(icon: "camera.macro", title: "Lens", value: lens)
                }
                
            if currentCDMedia.exifFocalLength > 0 {
                DetailRow(icon: "camera.viewfinder", title: "Focal Length", value: "\(Int(currentCDMedia.exifFocalLength))mm")
            }
                
            if currentCDMedia.exifFNumber > 0 {
                DetailRow(icon: "camera.aperture", title: "Aperture", value: "f/\(String(format: "%.1f", currentCDMedia.exifFNumber))")
            }
                
            if let exposureTime = currentCDMedia.exifExposureTime {
                DetailRow(icon: "timer", title: "Shutter", value: exposureTime)
            }
                
            if currentCDMedia.exifIso > 0 {
                DetailRow(icon: "camera.filters", title: "ISO", value: "\(currentCDMedia.exifIso)")
            }
            
            Spacer()
        }
    }
    
    private var cachedSunTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sun position calculations would go here")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private var cachedTipsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photography tips and location access information")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}


extension DateFormatter {
    static let photoDetail: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}


// MARK: - Cached Gallery Implementation
struct CachedSimpleHeadingGallery: View {
    let cdMediaItems: [CDMedia]
    let onPhotoTap: (Int) -> Void
    @State private var scrollOffset: CGFloat = 0
    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0
    
    // Sort media by heading for circular ordering
    private var sortedCDMedia: [CDMedia] {
        let mediaWithHeading = cdMediaItems.filter { 
            $0.exifGpsDirection != -1 && !$0.exifGpsDirection.isNaN 
        }
        let mediaWithoutHeading = cdMediaItems.filter { 
            $0.exifGpsDirection == -1 || $0.exifGpsDirection.isNaN 
        }
        
        // Sort media with heading by compass direction
        let sortedWithHeading = mediaWithHeading.sorted { cdMedia1, cdMedia2 in
            return cdMedia1.exifGpsDirection < cdMedia2.exifGpsDirection
        }
        
        // Append media without heading at the end
        return sortedWithHeading + mediaWithoutHeading
    }
    
    // Create infinite scroll effect by tripling the array
    private var infiniteCDMedia: [CDMedia] {
        guard !sortedCDMedia.isEmpty else { return [] }
        return sortedCDMedia + sortedCDMedia + sortedCDMedia
    }
    
    // Start from middle section to allow scrolling both directions
    private var baseOffset: Int {
        sortedCDMedia.count
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
                    ForEach(Array(infiniteCDMedia.enumerated()), id: \.element.id) { index, cdMediaItem in
                        // Image with cached loading
                        ZStack {
                            // TODO: Use CachedPhotoView once compilation issues are resolved
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Text("Photo")
                                        .foregroundColor(.gray)
                                )
                            
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
                                .transition(.opacity)
                                .animation(.easeInOut(duration: 0.3), value: currentIndex)
                            }
                        }
                        .frame(width: itemWidth)
                        .aspectRatio(4/3, contentMode: ContentMode.fit)
                        .clipped()
                        .onTapGesture {
                            let actualIndex = index % sortedCDMedia.count
                            onPhotoTap(actualIndex)
                        }
                    }
                }
                .offset(x: -CGFloat(baseOffset) * (itemWidth + itemSpacing) + centerOffset + scrollOffset + dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let itemTotalWidth = itemWidth + itemSpacing
                            let dragThreshold = itemTotalWidth * 0.3
                            
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                if value.translation.width > dragThreshold {
                                    // Swipe right - go to previous
                                    currentIndex = max(0, currentIndex - 1)
                                } else if value.translation.width < -dragThreshold {
                                    // Swipe left - go to next
                                    currentIndex = min(sortedCDMedia.count - 1, currentIndex + 1)
                                }
                                
                                scrollOffset = -CGFloat(currentIndex) * itemTotalWidth
                                dragOffset = 0
                            }
                        }
                )
            }
            
            // Bottom right: Compass indicator (if current photo has heading)
            if let currentCDMedia = getCurrentCDMedia(), 
               currentCDMedia.exifGpsDirection != -1 && !currentCDMedia.exifGpsDirection.isNaN {
                VStack(spacing: 4) {
                    Image(systemName: "location.north")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(Double(currentCDMedia.exifGpsDirection)))
                    
                    Text("\(Int(currentCDMedia.exifGpsDirection))°")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .padding(12)
                .background(.ultraThinMaterial.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()
            }
        }
        .onAppear {
            if !sortedCDMedia.isEmpty {
                withAnimation(.easeOut(duration: 0.5)) {
                    scrollOffset = 0 // Start at the first image
                }
            }
        }
    }
    
    private func getCurrentCDMedia() -> CDMedia? {
        guard currentIndex >= 0 && currentIndex < sortedCDMedia.count else { return nil }
        return sortedCDMedia[currentIndex]
    }
}

// Simple photo detail view for full-screen display



// MARK: - Infinite Photo Carousel

struct InfinitePhotoCarousel: View {
    let media: [Media]
    @Binding var selectedIndex: Int
    let onPhotoTap: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var internalIndex: Int = 0
    @State private var isAnimating = false
    
    // Create infinite scroll by tripling the array
    private var infiniteMedia: [Media] {
        guard !media.isEmpty else { return [] }
        return media + media + media
    }
    
    // Start from middle section for infinite scroll effect
    private var centerOffset: Int { media.count }
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            
            if media.count == 1 {
                // Single photo - no carousel behavior
                let itemWidth = screenWidth * 0.85  // Keep same width as carousel
                
                HStack {
                    Spacer()
                    CarouselPhotoItem(
                        mediaItem: media[0],
                        isCenterItem: true,
                        itemWidth: itemWidth,
                        sideItemWidth: itemWidth * 0.2,
                        selectedIndex: 0,
                        onTap: {
                            onPhotoTap()
                        }
                    )
                    Spacer()
                }
            } else {
                // Multiple photos - use full carousel
                let itemWidth = screenWidth * 0.85  // Slightly smaller to ensure full visibility
                let itemSpacing: CGFloat = 10  // Spacing between photos
                let totalItemWidth = itemWidth + itemSpacing
                
                HStack(spacing: itemSpacing) {
                    ForEach(Array(infiniteMedia.enumerated()), id: \.offset) { index, mediaItem in
                        let realIndex = index % media.count
                        let isCenterItem = index == internalIndex
                        
                        CarouselPhotoItem(
                            mediaItem: mediaItem,
                            isCenterItem: isCenterItem,
                            itemWidth: itemWidth,
                            sideItemWidth: itemWidth * 0.2,
                            selectedIndex: realIndex,
                            onTap: {
                                if isCenterItem {
                                    onPhotoTap()
                                } else {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        moveToIndex(index)
                                    }
                                }
                            }
                        )
                    }
                }
                .offset(x: calculateOffset(screenWidth: screenWidth, itemWidth: totalItemWidth))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isAnimating {
                                dragOffset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            if !isAnimating {
                                handleDragEnd(value: value, itemWidth: totalItemWidth)
                            }
                        }
                )
            }
        }
        .onAppear {
            if media.count == 1 {
                // Single photo - always use index 0
                selectedIndex = 0
                internalIndex = 0
            } else {
                // Multiple photos - start with first photo that has heading data, or just the first photo
                if let firstWithHeading = media.firstIndex(where: { $0.exifData?.gpsDirection != nil }) {
                    internalIndex = centerOffset + firstWithHeading
                    selectedIndex = firstWithHeading
                } else {
                    internalIndex = centerOffset
                    selectedIndex = 0
                }
            }
        }
        .onChange(of: selectedIndex) { oldValue, newValue in
            // Only update internal index when external selectedIndex changes from outside
            // and we're not already animating (skip for single photos)
            if media.count > 1 && !isAnimating && oldValue != newValue {
                // Check if we should take the shortest path
                let currentRealIndex = internalIndex % media.count
                let normalizedCurrent = currentRealIndex < 0 ? currentRealIndex + media.count : currentRealIndex
                
                if normalizedCurrent != newValue {
                    // External change, update to match
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        // Keep the current position in the triple array but adjust for the new index
                        let offset = newValue - normalizedCurrent
                        internalIndex += offset
                    }
                }
            }
        }
    }
    
    private func calculateOffset(screenWidth: CGFloat, itemWidth: CGFloat) -> CGFloat {
        guard !media.isEmpty else { return 0 }
        
        let screenCenterX = screenWidth / 2
        let itemCenterOffset = itemWidth / 2
        let selectedItemPosition = CGFloat(internalIndex) * itemWidth
        return screenCenterX - itemCenterOffset - selectedItemPosition + dragOffset
    }
    
    private func handleDragEnd(value: DragGesture.Value, itemWidth: CGFloat) {
        let threshold: CGFloat = 50
        let translationX = value.translation.width
        
        isAnimating = true
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            if translationX > threshold {
                // Swipe right - go to previous
                internalIndex -= 1
            } else if translationX < -threshold {
                // Swipe left - go to next
                internalIndex += 1
            }
            dragOffset = 0
        }
        
        // Update the binding and reset position if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isAnimating = false
            
            // Calculate the real index with proper negative handling
            var realIndex = internalIndex % media.count
            if realIndex < 0 {
                realIndex += media.count
            }
            selectedIndex = realIndex
            
            // Smart reset: only reset if we're at the edges of our triple array
            // and ensure we don't trigger animation during reset
            if internalIndex < centerOffset {
                // We've moved into the left copy
                internalIndex = internalIndex + media.count
            } else if internalIndex >= centerOffset + media.count {
                // We've moved into the right copy
                internalIndex = internalIndex - media.count
            }
        }
    }
    
    private func moveToIndex(_ index: Int) {
        isAnimating = true
        internalIndex = index
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isAnimating = false
            
            // Calculate the real index
            var realIndex = index % media.count
            if realIndex < 0 {
                realIndex += media.count
            }
            selectedIndex = realIndex
            
            // Smart reset without animation
            if internalIndex < centerOffset {
                internalIndex = internalIndex + media.count
            } else if internalIndex >= centerOffset + media.count {
                internalIndex = internalIndex - media.count
            }
        }
    }
}

// MARK: - Carousel Photo Item Component

struct CarouselPhotoItem: View {
    let mediaItem: Media
    let isCenterItem: Bool
    let itemWidth: CGFloat
    let sideItemWidth: CGFloat
    let selectedIndex: Int
    let onTap: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Photo from cached system only
                UnifiedPhotoView(
                    photoIdentifier: mediaItem.url,
                    targetSize: CGSize(width: 400, height: 400),
                    contentMode: .fill
                )
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipShape(RoundedRectangle(cornerRadius: isCenterItem ? 12 : 10))
                
                // Compass rose overlay on center item only
                if isCenterItem, let heading = mediaItem.exifData?.gpsDirection {
                    CompassOverlay(heading: heading)
                }
            }
        }
        .frame(width: itemWidth, height: .infinity)
        .scaleEffect(isCenterItem ? 1.0 : 0.9)
        .opacity(isCenterItem ? 1.0 : 0.7)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedIndex)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Compass Overlay Component

struct CompassOverlay: View {
    let heading: Float
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 2) {
                    // Mini compass rose
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                            .frame(width: 32, height: 32)
                        
                        // North indicator
                        Text("N")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .offset(y: -13)
                        
                        // Heading arrow
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.blue)
                            .frame(width: 2, height: 14)
                            .offset(y: -7)
                            .rotationEffect(.degrees(Double(heading)))
                            .animation(.easeInOut(duration: 0.3), value: heading)
                        
                        // Center dot
                        Circle()
                            .fill(Color.white)
                            .frame(width: 3, height: 3)
                    }
                    
                    // Heading value
                    Text("\(Int(heading))°")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(8)
                .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
        }
        .padding(12)
    }
}

// MARK: - Comprehensive Photo Detail View

struct ComprehensivePhotoDetailView: View {
    let media: [Media]
    @State var selectedIndex: Int
    let onDismiss: () -> Void
    @State private var selectedTab = 0
    @State private var showingFullScreenPhoto = false
    
    private var currentMedia: Media? {
        guard media.indices.contains(selectedIndex) else { return nil }
        return media[selectedIndex]
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Full-screen photo at the top
                GeometryReader { geometry in
                    if let current = currentMedia {
                        ZStack {
                            UnifiedPhotoView(
                                photoIdentifier: current.url,
                                targetSize: CGSize(width: geometry.size.width, height: geometry.size.height),
                                contentMode: .fit
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black)
                            .onTapGesture {
                                showingFullScreenPhoto = true
                            }
                            
                            // Navigation overlay for multiple photos
                            if media.count > 1 {
                                HStack {
                                    if selectedIndex > 0 {
                                        Button(action: { 
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                selectedIndex -= 1 
                                            }
                                        }) {
                                            Image(systemName: "chevron.left.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.white)
                                                .background(Circle().fill(.black.opacity(0.3)))
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedIndex < media.count - 1 {
                                        Button(action: { 
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                selectedIndex += 1 
                                            }
                                        }) {
                                            Image(systemName: "chevron.right.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.white)
                                                .background(Circle().fill(.black.opacity(0.3)))
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                            
                            // Full screen button overlay
                            VStack {
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        showingFullScreenPhoto = true
                                    }) {
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .padding(12)
                                            .background(.ultraThinMaterial)
                                            .clipShape(Circle())
                                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                    }
                                    .padding(.top, 16)
                                    .padding(.trailing, 16)
                                }
                                Spacer()
                            }
                            
                            // Compass overlay if heading available
                            if let heading = current.exifData?.gpsDirection {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        CompassOverlay(heading: heading)
                                            .padding(16)
                                    }
                                }
                            }
                        }
                    } else {
                        Rectangle()
                            .fill(Color.gray)
                            .overlay(
                                Text("No photo available")
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(height: 250)
                
                // Tab selector and content
                VStack(spacing: 0) {
                    // Photo count indicator for multiple photos
                    if media.count > 1 {
                        HStack {
                            Text("\(selectedIndex + 1) of \(media.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            Spacer()
                        }
                    }
                    
                    // Tab selector
                    Picker("Section", selection: $selectedTab) {
                        Text("Details").tag(0)
                        Text("Camera").tag(1)  
                        Text("Settings").tag(2)
                        Text("Tips").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    
                    // Tab content
                    ScrollView {
                        Group {
                            switch selectedTab {
                            case 0:
                                photoDetailsSection
                            case 1:
                                cameraDetailsSection
                            case 2:
                                photographySettingsSection
                            case 3:
                                photographerTipsSection
                            default:
                                EmptyView()
                            }
                        }
                        .padding()
                    }
                    .frame(maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Photo Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingFullScreenPhoto) {
            FullScreenPhotoView(
                media: media,
                selectedIndex: $selectedIndex,
                onDismiss: { showingFullScreenPhoto = false }
            )
        }
    }
    
    // MARK: - Photo Details Section
    
    private var photoDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let current = currentMedia {
                // Photo timing and metadata
                PhotoMetadataCard(media: current)
                
                // Timing analysis
                if let captureDate = current.captureTimeUTC ?? current.exifData?.dateTimeOriginal,
                   let exif = current.exifData,
                   let lat = exif.gpsLatitude,
                   let lng = exif.gpsLongitude {
                    TimingAnalysisCard(captureDate: captureDate, location: CLLocationCoordinate2D(latitude: lat, longitude: lng))
                }
                
                // Location information
                if let exif = current.exifData, 
                   let lat = exif.gpsLatitude, 
                   let lng = exif.gpsLongitude {
                    LocationCard(latitude: lat, longitude: lng, heading: exif.gpsDirection)
                }
            }
        }
    }
    
    // MARK: - Camera Details Section
    
    private var cameraDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let current = currentMedia {
                CameraInfoCard(media: current)
            } else {
                Text("No camera information available")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
    
    // MARK: - Photography Settings Section
    
    private var photographySettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let current = currentMedia, let exif = current.exifData {
                CameraSettingsCard(exifData: exif)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Camera Settings")
                        .font(.headline)
                    
                    Text("No EXIF data available for this photo. Settings information was not embedded or has been removed during processing.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Photographer Tips Section
    
    private var photographerTipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Photographer Tips")
                .font(.headline)
            
            // Show user-submitted tips or empty state
            if hasUserTips {
                VStack(alignment: .leading, spacing: 12) {
                    // Best time to shoot tip (if provided by user)
                    if let bestTimeNotes = getUserBestTimeNotes() {
                        TipCard(
                            icon: "sun.max",
                            title: "Best Time to Shoot",
                            content: bestTimeNotes
                        )
                    }
                    
                    // Equipment tips (if provided by user)
                    if let equipmentTips = getUserEquipmentTips() {
                        TipCard(
                            icon: "camera",
                            title: "Recommended Equipment",
                            content: equipmentTips
                        )
                    }
                    
                    // Composition tips (if provided by user)
                    if let compositionTips = getUserCompositionTips() {
                        TipCard(
                            icon: "viewfinder",
                            title: "Composition Tips",
                            content: compositionTips
                        )
                    }
                    
                    // Seasonal notes (if provided by user)
                    if let seasonalNotes = getUserSeasonalNotes() {
                        TipCard(
                            icon: "leaf",
                            title: "Seasonal Notes",
                            content: seasonalNotes
                        )
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("No tips available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("The photographer hasn't shared any tips for this photo yet.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    // Helper methods for user-submitted tips (placeholder - would come from spot data)
    private var hasUserTips: Bool {
        return getUserBestTimeNotes() != nil || 
               getUserEquipmentTips() != nil || 
               getUserCompositionTips() != nil || 
               getUserSeasonalNotes() != nil
    }
    
    private func getUserBestTimeNotes() -> String? {
        // TODO: Get from spot data - spot.bestTimeNotes
        return nil
    }
    
    private func getUserEquipmentTips() -> String? {
        // TODO: Get from spot data - spot.equipmentTips
        return nil
    }
    
    private func getUserCompositionTips() -> String? {
        // TODO: Get from spot data - spot.compositionTips
        return nil
    }
    
    private func getUserSeasonalNotes() -> String? {
        // TODO: Get from spot data - spot.seasonalNotes
        return nil
    }
}

// MARK: - Supporting Photo Detail Components

struct PhotoMetadataCard: View {
    let media: Media
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photo Information")
                .font(.headline)
            
            VStack(spacing: 8) {
                if let captureDate = media.captureTimeUTC ?? media.exifData?.dateTimeOriginal {
                    CopyableMetadataRow(label: "Captured", value: captureDate.formatted(date: .abbreviated, time: .shortened))
                }
                
                if let width = media.exifData?.width, let height = media.exifData?.height {
                    CopyableMetadataRow(label: "Resolution", value: "\(width) × \(height)")
                }
                
                if let device = media.device {
                    CopyableMetadataRow(label: "Device", value: device)
                }
                
                if let attribution = media.attributionText {
                    CopyableMetadataRow(label: "Attribution", value: attribution)
                }
                
                if let license = media.licenseType {
                    CopyableMetadataRow(label: "License", value: license)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

struct TimingAnalysisCard: View {
    let captureDate: Date
    let location: CLLocationCoordinate2D
    
    @State private var sunSnapshot: SunSnapshot?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photo Timing")
                .font(.headline)
            
            VStack(spacing: 8) {
                // Date and Time
                HStack {
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            Text(captureDate, style: .date)
                                .fontWeight(.medium)
                        }
                        .font(.footnote)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                            Text(captureDate, style: .time)
                                .fontWeight(.medium)
                        }
                        .font(.footnote)
                    }
                }
                
                Divider()
                
                if let snapshot = sunSnapshot {
                    // Sun times
                    HStack {
                        if let sunrise = snapshot.sunriseUTC {
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: "sunrise.fill")
                                        .foregroundColor(.orange)
                                    Text("Sunrise")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(sunrise, style: .time)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        Spacer()
                        
                        if let sunset = snapshot.sunsetUTC {
                            VStack(alignment: .trailing) {
                                HStack {
                                    Text("Sunset")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Image(systemName: "sunset.fill")
                                        .foregroundColor(.orange)
                                }
                                Text(sunset, style: .time)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    
                    // Relative timing and special periods
                    VStack(alignment: .leading, spacing: 4) {
                        // Golden/Blue hour indicator
                        if isGoldenHour(captureDate: captureDate, snapshot: snapshot) {
                            HStack {
                                Image(systemName: "sun.max.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Golden Hour")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                                Spacer()
                            }
                        } else if isBlueHour(captureDate: captureDate, snapshot: snapshot) {
                            HStack {
                                Image(systemName: "moon.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("Blue Hour")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                        }
                        
                        // Relative timing to closest sun event
                        if let relativeText = getRelativeTimingText(snapshot: snapshot) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text(relativeText)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    }
                } else {
                    // Loading state
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Calculating sun times...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .onAppear {
            calculateSunTimes()
        }
    }
    
    private func calculateSunTimes() {
        // Calculate sun times based on date and location
        // This is a simplified calculation - a production app would use NOAA Solar Position Algorithm
        let calendar = Calendar.current
        
        // Get day of year for seasonal adjustment
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: captureDate) ?? 180
        let latitude = location.latitude
        
        // Simplified calculation for sunrise/sunset times
        // Base times adjusted by latitude and season
        let seasonalOffset = sin(Double(dayOfYear - 80) * .pi / 182.5) * 1.5 // hours variation
        let latitudeOffset = (latitude - 40) * 0.03 // hours per degree from 40°N
        
        // Base sunrise/sunset for 40°N latitude at equinox
        let baseSunriseHour = 6.0 - seasonalOffset + latitudeOffset
        let baseSunsetHour = 18.0 + seasonalOffset - latitudeOffset
        
        // Convert to actual times
        // Validate values before conversion to prevent crashes
        guard baseSunriseHour.isFinite && baseSunsetHour.isFinite else {
            print("⚠️ Invalid sun calculation results (NaN/Infinity), skipping")
            return
        }
        
        let sunriseHour = max(0, min(23, Int(baseSunriseHour.rounded())))
        let sunriseMinute = max(0, min(59, Int(abs(baseSunriseHour - Double(sunriseHour)) * 60)))
        let sunsetHour = max(0, min(23, Int(baseSunsetHour.rounded())))
        let sunsetMinute = max(0, min(59, Int(abs(baseSunsetHour - Double(sunsetHour)) * 60)))
        
        let sunrise = calendar.date(bySettingHour: sunriseHour, minute: sunriseMinute, second: 0, of: captureDate) ?? captureDate
        let sunset = calendar.date(bySettingHour: sunsetHour, minute: sunsetMinute, second: 0, of: captureDate) ?? captureDate
        
        // Golden hour: 1 hour before sunset to 30 min after
        let goldenHourStart = calendar.date(byAdding: .minute, value: -60, to: sunset) ?? sunset
        let goldenHourEnd = calendar.date(byAdding: .minute, value: 30, to: sunset) ?? sunset
        
        // Blue hour: sunset to 45 min after
        let blueHourStart = sunset
        let blueHourEnd = calendar.date(byAdding: .minute, value: 45, to: sunset) ?? sunset
        
        // Find closest solar event
        let events: [(SunSnapshot.SolarEvent, Date)] = [
            (.sunrise, sunrise),
            (.sunset, sunset),
            (.goldenHourStart, goldenHourStart),
            (.goldenHourEnd, goldenHourEnd),
            (.blueHourStart, blueHourStart),
            (.blueHourEnd, blueHourEnd)
        ]
        
        let closestEvent = events.min { abs($0.1.timeIntervalSince(captureDate)) < abs($1.1.timeIntervalSince(captureDate)) }
        let relativeMinutes = closestEvent.map { Int(captureDate.timeIntervalSince($0.1) / 60) }
        
        sunSnapshot = SunSnapshot(
            id: UUID(),
            spotId: UUID(),
            date: captureDate,
            sunriseUTC: sunrise,
            sunsetUTC: sunset,
            goldenHourStartUTC: goldenHourStart,
            goldenHourEndUTC: goldenHourEnd,
            blueHourStartUTC: blueHourStart,
            blueHourEndUTC: blueHourEnd,
            closestEvent: closestEvent?.0,
            relativeMinutesToEvent: relativeMinutes
        )
    }
    
    private func isGoldenHour(captureDate: Date, snapshot: SunSnapshot) -> Bool {
        guard let start = snapshot.goldenHourStartUTC,
              let end = snapshot.goldenHourEndUTC else { return false }
        return captureDate >= start && captureDate <= end
    }
    
    private func isBlueHour(captureDate: Date, snapshot: SunSnapshot) -> Bool {
        guard let start = snapshot.blueHourStartUTC,
              let end = snapshot.blueHourEndUTC else { return false }
        return captureDate >= start && captureDate <= end
    }
    
    private func getRelativeTimingText(snapshot: SunSnapshot) -> String? {
        // Find closest between sunrise and sunset only
        guard let sunrise = snapshot.sunriseUTC,
              let sunset = snapshot.sunsetUTC else { return nil }
        
        let timeToSunrise = abs(captureDate.timeIntervalSince(sunrise))
        let timeToSunset = abs(captureDate.timeIntervalSince(sunset))
        
        if timeToSunrise < timeToSunset {
            // Closer to sunrise
            let minutes = Int(captureDate.timeIntervalSince(sunrise) / 60)
            if minutes >= 0 {
                return "\(formatTimeInterval(minutes)) after sunrise"
            } else {
                return "\(formatTimeInterval(minutes)) before sunrise"
            }
        } else {
            // Closer to sunset
            let minutes = Int(captureDate.timeIntervalSince(sunset) / 60)
            if minutes >= 0 {
                return "\(formatTimeInterval(minutes)) after sunset"
            } else {
                return "\(formatTimeInterval(minutes)) before sunset"
            }
        }
    }
    
    private func formatTimeInterval(_ minutes: Int) -> String {
        let absMinutes = abs(minutes)
        let hours = absMinutes / 60
        let remainingMinutes = absMinutes % 60
        
        if hours == 0 {
            return "\(remainingMinutes) minute\(remainingMinutes == 1 ? "" : "s")"
        } else if remainingMinutes == 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s") and \(remainingMinutes) minute\(remainingMinutes == 1 ? "" : "s")"
        }
    }
}

struct LocationCard: View {
    let latitude: Double
    let longitude: Double
    let heading: Float?
    
    @State private var showingNavigationOptions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)
            
            VStack(spacing: 8) {
                CopyableMetadataRow(label: "Coordinates", value: String(format: "%.6f, %.6f", latitude, longitude))
                
                if let heading = heading {
                    CopyableMetadataRow(label: "Camera Direction", value: "\(Int(heading))°")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Mini map preview with navigation
            Map(initialPosition: .region(MKCoordinateRegion(
                center: isValidCoordinate(CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) ? 
                    CLLocationCoordinate2D(latitude: latitude, longitude: longitude) : 
                    CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))) {
                Marker("Photo Location", coordinate: isValidCoordinate(CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) ? 
                    CLLocationCoordinate2D(latitude: latitude, longitude: longitude) : 
                    CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194))
                    .tint(.green)
            }
            .frame(height: 150)
            .cornerRadius(10)
            .onTapGesture {
                showingNavigationOptions = true
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
    }
    
    private func openInAppleMaps() {
        let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: location))
        mapItem.name = "Photo Location"
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
    
    private func openInGoogleMaps() {
        let urlString = "comgooglemaps://?daddr=\(latitude),\(longitude)&directionsmode=driving"
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // Fallback to web
            let webUrlString = "https://maps.google.com/maps?daddr=\(latitude),\(longitude)"
            if let webUrl = URL(string: webUrlString) {
                UIApplication.shared.open(webUrl)
            }
        }
    }
    
    private func openInWaze() {
        let urlString = "waze://?ll=\(latitude),\(longitude)&navigate=yes"
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // Fallback to web
            let webUrlString = "https://waze.com/ul?ll=\(latitude),\(longitude)&navigate=yes"
            if let webUrl = URL(string: webUrlString) {
                UIApplication.shared.open(webUrl)
            }
        }
    }
}

struct CameraInfoCard: View {
    let media: Media
    
    private var hasAnyData: Bool {
        return media.exifData?.make != nil ||
               media.exifData?.model != nil ||
               media.lens != nil ||
               media.exifData?.lens != nil ||
               media.exifData?.software != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera & Lens")
                .font(.headline)
            
            if hasAnyData {
                VStack(spacing: 8) {
                    if let make = media.exifData?.make {
                        CopyableMetadataRow(label: "Make", value: make)
                    }
                    
                    if let model = media.exifData?.model {
                        CopyableMetadataRow(label: "Model", value: model)
                    }
                    
                    if let lens = media.lens ?? media.exifData?.lens {
                        CopyableMetadataRow(label: "Lens", value: lens)
                    }
                    
                    if let software = media.exifData?.software {
                        CopyableMetadataRow(label: "Software", value: software)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            } else {
                Text("No Camera & Lens information for this photo")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
        }
    }
}

struct CameraSettingsCard: View {
    let exifData: ExifData
    
    private var hasAnyData: Bool {
        return exifData.focalLength != nil ||
               exifData.fNumber != nil ||
               exifData.exposureTime != nil ||
               exifData.iso != nil ||
               exifData.colorSpace != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera Settings")
                .font(.headline)
            
            if hasAnyData {
                VStack(spacing: 8) {
                    if let focalLength = exifData.focalLength {
                        CopyableMetadataRow(label: "Focal Length", value: "\(Int(focalLength))mm")
                    }
                    
                    if let aperture = exifData.fNumber {
                        CopyableMetadataRow(label: "Aperture", value: "f/\(aperture)")
                    }
                    
                    if let exposureTime = exifData.exposureTime {
                        CopyableMetadataRow(label: "Shutter Speed", value: exposureTime)
                    }
                    
                    if let iso = exifData.iso {
                        CopyableMetadataRow(label: "ISO", value: String(iso))
                    }
                    
                    if let colorSpace = exifData.colorSpace {
                        CopyableMetadataRow(label: "Color Space", value: colorSpace)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            } else {
                Text("No Camera Settings information for this photo")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
        }
    }
}

struct TipCard: View {
    let icon: String
    let title: String
    let content: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(content)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct MetadataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.footnote)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.footnote)
                .fontWeight(.medium)
            
            Spacer()
        }
    }
}

struct CopyableMetadataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.footnote)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.footnote)
                .fontWeight(.medium)
                .textSelection(.enabled)
            
            Spacer()
        }
    }
}

// MARK: - Full Screen Photo View

struct FullScreenPhotoView: View {
    let media: [Media]
    @Binding var selectedIndex: Int
    let onDismiss: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var dragVelocity: CGFloat = 0
    @State private var currentZoomScale: CGFloat = 1.0
    @State private var savedZoomScale: CGFloat = 1.0
    @State private var currentOffset: CGSize = .zero
    @State private var savedOffset: CGSize = .zero
    
    private var currentMedia: Media? {
        guard media.indices.contains(selectedIndex) else { return nil }
        return media[selectedIndex]
    }
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            if currentMedia != nil {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(media.enumerated()), id: \.offset) { index, mediaItem in
                        GeometryReader { geometry in
                            ZoomablePhotoView(
                                photoIdentifier: mediaItem.url,
                                geometry: geometry,
                                currentZoomScale: index == selectedIndex ? $currentZoomScale : .constant(1.0),
                                savedZoomScale: index == selectedIndex ? $savedZoomScale : .constant(1.0),
                                currentOffset: index == selectedIndex ? $currentOffset : .constant(.zero),
                                savedOffset: index == selectedIndex ? $savedOffset : .constant(.zero),
                                onTap: {
                                    // Double tap to toggle zoom
                                    withAnimation(.spring()) {
                                        if currentZoomScale > 1.5 {
                                            currentZoomScale = 1.0
                                            savedZoomScale = 1.0
                                            currentOffset = .zero
                                            savedOffset = .zero
                                        } else {
                                            currentZoomScale = 2.5
                                            savedZoomScale = 2.5
                                        }
                                    }
                                },
                                onDismiss: onDismiss
                            )
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .ignoresSafeArea()
                // Reset zoom when changing photos
                .onChange(of: selectedIndex) { _, _ in
                    currentZoomScale = 1.0
                    savedZoomScale = 1.0
                    currentOffset = .zero
                    savedOffset = .zero
                }
            }
            
            // Top overlay with controls
            VStack {
                HStack {
                    // Close button
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    .padding(.leading, 20)
                    
                    Spacer()
                    
                    // Photo counter
                    if media.count > 1 {
                        Text("\(selectedIndex + 1) of \(media.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                }
                .padding(.top, 20)
                
                Spacer()
            }
            
            // Bottom overlay with photo info (optional)
            if let current = currentMedia, let heading = current.exifData?.gpsDirection {
                VStack {
                    Spacer()
                    HStack {
                        // Minimal compass indicator
                        HStack(spacing: 8) {
                            Image(systemName: "location.north")
                                .font(.caption)
                                .foregroundColor(.white)
                                .rotationEffect(.degrees(Double(heading)))
                            
                            Text("\(Int(heading))°")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Zoomable Photo View

struct ZoomablePhotoView: View {
    let photoIdentifier: String
    let geometry: GeometryProxy
    @Binding var currentZoomScale: CGFloat
    @Binding var savedZoomScale: CGFloat
    @Binding var currentOffset: CGSize
    @Binding var savedOffset: CGSize
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    
    var body: some View {
        UnifiedPhotoView(
            photoIdentifier: photoIdentifier,
            targetSize: CGSize(width: geometry.size.width, height: geometry.size.height),
            contentMode: .fit
        )
        .scaleEffect(currentZoomScale)
        .offset(currentOffset)
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    let delta = value / savedZoomScale
                    currentZoomScale = min(max(savedZoomScale * delta, minScale), maxScale)
                }
                .onEnded { _ in
                    savedZoomScale = currentZoomScale
                    
                    // Snap back to min scale if close
                    if currentZoomScale < 1.2 {
                        withAnimation(.spring()) {
                            currentZoomScale = minScale
                            savedZoomScale = minScale
                            currentOffset = .zero
                            savedOffset = .zero
                        }
                    }
                }
        )
        .simultaneousGesture(
            // Drag gesture only works when zoomed in
            DragGesture()
                .onChanged { value in
                    if currentZoomScale > 1.0 {
                        currentOffset = CGSize(
                            width: savedOffset.width + value.translation.width,
                            height: savedOffset.height + value.translation.height
                        )
                    }
                }
                .onEnded { _ in
                    savedOffset = currentOffset
                    
                    // Limit panning bounds
                    withAnimation(.spring()) {
                        let maxOffset = geometry.size.width * (currentZoomScale - 1) / 2
                        let maxOffsetY = geometry.size.height * (currentZoomScale - 1) / 2
                        
                        currentOffset.width = min(max(currentOffset.width, -maxOffset), maxOffset)
                        currentOffset.height = min(max(currentOffset.height, -maxOffsetY), maxOffsetY)
                        savedOffset = currentOffset
                    }
                }
        )
        .onTapGesture(count: 2) {
            onTap()
        }
        .onTapGesture(count: 1) {
            // Single tap to show/hide controls or dismiss if zoomed out
            if currentZoomScale == 1.0 {
                onDismiss()
            }
        }
    }
}

// MARK: - Helper Functions

private func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
    return !coordinate.latitude.isNaN && 
           !coordinate.longitude.isNaN && 
           coordinate.latitude.isFinite && 
           coordinate.longitude.isFinite &&
           abs(coordinate.latitude) <= 90 && 
           abs(coordinate.longitude) <= 180
}

#Preview {
    NavigationStack {
        SpotDetailView(spot: mockSpots[0])
            .environmentObject(AppState())
    }
}