import SwiftUI
import PhotosUI
import Photos
import CoreLocation
import MapKit

struct AddSpotView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedMedia: [PhotosPickerItem] = []
    @State private var extractedMetadata: [ExtractedPhotoMetadata] = []
    @State private var currentStep = AddSpotStep.selectMedia
    @State private var spotData = NewSpotData()
    @StateObject private var metadataExtractor = PhotoMetadataExtractor()
    
    enum AddSpotStep {
        case selectMedia
        case identifySpot
        case confirmMetadata
        case addRoute
        case publish
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                
                Group {
                    switch currentStep {
                    case .selectMedia:
                        MediaPickerStep(
                            selectedMedia: $selectedMedia,
                            onNext: {
                                Task {
                                    await extractMetadata()
                                    currentStep = .identifySpot
                                }
                            }
                        )
                    case .identifySpot:
                        SpotIdentificationStep(
                            spotData: $spotData,
                            extractedMetadata: extractedMetadata,
                            onNext: {
                                currentStep = .confirmMetadata
                            },
                            onBack: {
                                currentStep = .selectMedia
                            }
                        )
                    case .confirmMetadata:
                        MetadataConfirmStep(
                            spotData: $spotData,
                            extractedMetadata: extractedMetadata,
                            onNext: {
                                currentStep = .addRoute
                            },
                            onBack: {
                                currentStep = .identifySpot
                            }
                        )
                    case .addRoute:
                        RouteStep(
                            spotData: $spotData,
                            onNext: {
                                currentStep = .publish
                            },
                            onBack: {
                                currentStep = .confirmMetadata
                            }
                        )
                    case .publish:
                        PublishStep(
                            spotData: $spotData,
                            onPublish: {
                                // Handle publish
                            },
                            onBack: {
                                currentStep = .addRoute
                            }
                        )
                    }
                }
            }
            .navigationTitle("Add Spot")
            .navigationBarTitleDisplayMode(.inline)
            // Add safe area padding to account for tab bar
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 0)
            }
        }
    }
    
    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach([AddSpotStep.selectMedia, .identifySpot, .confirmMetadata, .addRoute, .publish], id: \.self) { step in
                Rectangle()
                    .fill(stepColor(for: step))
                    .frame(height: 3)
                    .animation(.easeInOut, value: currentStep)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private func stepColor(for step: AddSpotStep) -> Color {
        let steps: [AddSpotStep] = [.selectMedia, .identifySpot, .confirmMetadata, .addRoute, .publish]
        let currentIndex = steps.firstIndex(of: currentStep) ?? 0
        let stepIndex = steps.firstIndex(of: step) ?? 0
        
        return stepIndex <= currentIndex ? Color.green : Color(.systemGray5)
    }
    
    private func extractMetadata() async {
        extractedMetadata = []
        for item in selectedMedia {
            do {
                let metadata = try await metadataExtractor.extractMetadata(from: item)
                extractedMetadata.append(metadata)
                
                // Update spot data with first media's location and metadata
                if extractedMetadata.count == 1 {
                    spotData.location = metadata.location
                    spotData.heading = metadata.heading.map { Int($0) }
                    spotData.elevation = metadata.altitude.map { Int($0) }
                    spotData.captureDate = metadata.captureDate
                    spotData.cameraMake = metadata.cameraMake
                    spotData.cameraModel = metadata.cameraModel
                    spotData.lensModel = metadata.lensModel
                }
            } catch {
                print("Failed to extract metadata: \(error)")
            }
        }
    }
}

struct NewSpotData {
    var title = ""
    var isNewSpot = true
    var selectedExistingSpot: Spot?
    var location: CLLocationCoordinate2D?
    var heading: Int?
    var elevation: Int?
    var tags: [String] = []
    var difficulty: Spot.Difficulty = .moderate
    var notes = ""
    var parkingLocation: CLLocationCoordinate2D?
    var routePolyline: String?
    var hazards: [String] = []
    var fees: [String] = []
    
    // Photography metadata
    var captureDate: Date?
    var cameraMake: String?
    var cameraModel: String?
    var lensModel: String?
    var focalLength: Float?
    var focalLengthIn35mm: Float?
    var aperture: Float?
    var shutterSpeed: String?
    var iso: Int?
    var exposureBias: Float?
    var meteringMode: String?
    var whiteBalance: String?
    var flash: Bool = false
    
    // Post-processing
    var software: String?
    var presets: [String] = []
    var filters: [String] = []
    var editingNotes: String = ""
    
    // Tips for photographers
    var bestTimeNotes: String = ""
    var equipmentTips: String = ""
    var compositionTips: String = ""
    var seasonalNotes: String = ""
}

struct SpotIdentificationStep: View {
    @Binding var spotData: NewSpotData
    let extractedMetadata: [ExtractedPhotoMetadata]
    let onNext: () -> Void
    let onBack: () -> Void
    
    @State private var isReverseGeocoding = true
    @State private var reverseGeocodedName: String?
    @State private var nearbySpots: [Spot] = []
    @State private var isLoadingNearbySpots = true
    @State private var geocoder = CLGeocoder()
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Identify Spot")
                            .font(.title2)
                            .bold()
                            .padding(.top)
                        
                        if let location = spotData.location {
                            // Map showing location
                            Map(initialPosition: .region(MKCoordinateRegion(
                                center: location,
                                span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
                            ))) {
                                Marker("Photo Location", coordinate: location)
                                    .tint(.green)
                                
                                // Show nearby spots
                                ForEach(nearbySpots) { spot in
                                    Marker(spot.title, coordinate: spot.location)
                                        .tint(.blue)
                                }
                            }
                            .frame(height: 200)
                            .cornerRadius(12)
                            .padding(.horizontal)
                            
                            if isReverseGeocoding {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Finding location name...")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            } else if isLoadingNearbySpots {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Checking for nearby spots...")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            } else {
                                // Show results
                                if nearbySpots.isEmpty {
                                    // New spot
                                    newSpotSection
                                } else {
                                    // Existing spots nearby
                                    existingSpotsSection
                                }
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "location.slash")
                                    .font(.system(size: 50))
                                    .foregroundColor(.orange)
                                Text("No Location Data")
                                    .font(.headline)
                                Text("We couldn't extract GPS coordinates from your photos. You can still create a spot by manually setting the location.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .padding()
                        }
                    
                        Spacer(minLength: 20)
                    }
                }
                .frame(height: geometry.size.height - 100) // Leave space for navigation
                
                navigationButtons
            }
        }
        .onAppear {
            if let location = spotData.location {
                performReverseGeocoding(for: location)
                findNearbySpots(near: location)
            }
        }
    }
    
    private var newSpotSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if let path = Bundle.main.path(forResource: "explorer-emoji", ofType: "png"),
                   let explorerImage = UIImage(contentsOfFile: path) {
                    Image(uiImage: explorerImage)
                        .resizable()
                        .frame(width: 32, height: 32)
                } else {
                    Text("🥾")
                        .font(.title2)
                }
                Text("You're the first in this spot!")
                    .font(.headline)
                    .foregroundColor(.green)
                Spacer()
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                if let locationName = reverseGeocodedName {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("Spot Name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(locationName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    Text("We'll use this official location name for your new spot. You can refine the details in the next step.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                } else {
                    Text("No official location name found. You can enter a custom name in the next step.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
            }
        }
        .onAppear {
            spotData.isNewSpot = true
            spotData.selectedExistingSpot = nil
            if let locationName = reverseGeocodedName {
                spotData.title = locationName
            }
        }
    }
    
    private var existingSpotsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "photo.stack.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("Nearby Spots Found")
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Text("We found existing spots near your photo location. Are you adding photos to one of these spots, or creating a new one?")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            LazyVStack(spacing: 12) {
                ForEach(nearbySpots) { spot in
                    Button(action: {
                        spotData.isNewSpot = false
                        spotData.selectedExistingSpot = spot
                        spotData.title = spot.title
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(spot.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text(distanceString(to: spot.location))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if spotData.selectedExistingSpot?.id == spot.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(spotData.selectedExistingSpot?.id == spot.id ? Color.green.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Option to create new spot
                Button(action: {
                    spotData.isNewSpot = true
                    spotData.selectedExistingSpot = nil
                    if let locationName = reverseGeocodedName {
                        spotData.title = locationName
                    } else {
                        spotData.title = ""
                    }
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("You're the first in this spot!")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                            if let locationName = reverseGeocodedName {
                                Text("Using name: \(locationName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Custom name")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if spotData.isNewSpot {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            if let path = Bundle.main.path(forResource: "explorer-emoji", ofType: "png"),
                               let explorerImage = UIImage(contentsOfFile: path) {
                                Image(uiImage: explorerImage)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            } else {
                                Text("🥾")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding()
                    .background(spotData.isNewSpot ? Color.green.opacity(0.1) : Color(.systemGray6))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.green, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            
            // Extra padding to ensure scrollability above navigation buttons
            Spacer(minLength: 80)
        }
    }
    
    private var navigationButtons: some View {
        HStack {
            Button(action: onBack) {
                Text("Back")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
            }
            
            Button(action: onNext) {
                HStack {
                    Text("Continue")
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background((isReverseGeocoding || isLoadingNearbySpots || (!spotData.isNewSpot && spotData.selectedExistingSpot == nil)) ? Color.gray : Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isReverseGeocoding || isLoadingNearbySpots || (!spotData.isNewSpot && spotData.selectedExistingSpot == nil))
        }
        .padding()
    }
    
    private func performReverseGeocoding(for location: CLLocationCoordinate2D) {
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        geocoder.reverseGeocodeLocation(clLocation) { placemarks, error in
            DispatchQueue.main.async {
                isReverseGeocoding = false
                
                if let error = error {
                    print("Reverse geocoding error: \(error.localizedDescription)")
                    return
                }
                
                if let placemark = placemarks?.first {
                    // Build a descriptive name from placemark components
                    var nameComponents: [String] = []
                    
                    if let landmark = placemark.areasOfInterest?.first {
                        nameComponents.append(landmark)
                    } else if let name = placemark.name, !name.contains("+") {
                        nameComponents.append(name)
                    }
                    
                    if let thoroughfare = placemark.thoroughfare {
                        if !nameComponents.contains(where: { $0.contains(thoroughfare) }) {
                            nameComponents.append(thoroughfare)
                        }
                    }
                    
                    if let locality = placemark.locality {
                        nameComponents.append(locality)
                    }
                    
                    if nameComponents.isEmpty {
                        if let locality = placemark.locality {
                            nameComponents.append(locality)
                        } else if let administrativeArea = placemark.administrativeArea {
                            nameComponents.append(administrativeArea)
                        }
                    }
                    
                    reverseGeocodedName = nameComponents.joined(separator: ", ")
                }
            }
        }
    }
    
    private func findNearbySpots(near location: CLLocationCoordinate2D) {
        // Simulate API call to find nearby spots
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // For demo purposes, check if location is within 100m of existing spots
            let userLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
            
            // Create mock spots in various locations for testing
            let testSpots = [
                // Golden Gate area
                Spot(
                    id: UUID(),
                    title: "Golden Gate Vista Point",
                    location: CLLocationCoordinate2D(latitude: 37.8025, longitude: -122.4058),
                    headingDegrees: 180,
                    elevationMeters: 100,
                    subjectTags: ["Bridge", "Sunset"],
                    difficulty: .easy,
                    createdBy: UUID(),
                    privacy: .publicSpot,
                    license: "CC-BY-NC",
                    status: .active,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                Spot(
                    id: UUID(),
                    title: "Battery Spencer Overlook",
                    location: CLLocationCoordinate2D(latitude: 37.8028, longitude: -122.4055),
                    headingDegrees: 200,
                    elevationMeters: 120,
                    subjectTags: ["Bridge", "Architecture"],
                    difficulty: .moderate,
                    createdBy: UUID(),
                    privacy: .publicSpot,
                    license: "CC-BY-NC",
                    status: .active,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                // New York Central Park area
                Spot(
                    id: UUID(),
                    title: "Bethesda Fountain",
                    location: CLLocationCoordinate2D(latitude: 40.7764, longitude: -73.9719),
                    headingDegrees: 90,
                    elevationMeters: 50,
                    subjectTags: ["Fountain", "Park"],
                    difficulty: .easy,
                    createdBy: UUID(),
                    privacy: .publicSpot,
                    license: "CC-BY-NC",
                    status: .active,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                Spot(
                    id: UUID(),
                    title: "Bow Bridge View",
                    location: CLLocationCoordinate2D(latitude: 40.7766, longitude: -73.9717),
                    headingDegrees: 45,
                    elevationMeters: 52,
                    subjectTags: ["Bridge", "Lake"],
                    difficulty: .easy,
                    createdBy: UUID(),
                    privacy: .publicSpot,
                    license: "CC-BY-NC",
                    status: .active,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                // London area
                Spot(
                    id: UUID(),
                    title: "Tower Bridge South Bank",
                    location: CLLocationCoordinate2D(latitude: 51.5045, longitude: -0.0781),
                    headingDegrees: 315,
                    elevationMeters: 10,
                    subjectTags: ["Bridge", "Thames"],
                    difficulty: .easy,
                    createdBy: UUID(),
                    privacy: .publicSpot,
                    license: "CC-BY-NC",
                    status: .active,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                // Tokyo area
                Spot(
                    id: UUID(),
                    title: "Shibuya Crossing",
                    location: CLLocationCoordinate2D(latitude: 35.6598, longitude: 139.7006),
                    headingDegrees: 135,
                    elevationMeters: 30,
                    subjectTags: ["Urban", "Street"],
                    difficulty: .easy,
                    createdBy: UUID(),
                    privacy: .publicSpot,
                    license: "CC-BY-NC",
                    status: .active,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            ]
            
            // Filter test spots to find those within 100m of user location
            nearbySpots = testSpots.filter { spot in
                let spotLocation = CLLocation(latitude: spot.location.latitude, longitude: spot.location.longitude)
                return userLocation.distance(from: spotLocation) <= 100 // 100 meters
            }
            
            isLoadingNearbySpots = false
        }
    }
    
    private func distanceString(to location: CLLocationCoordinate2D) -> String {
        guard let userLocation = spotData.location else { return "" }
        
        let from = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let to = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let distance = from.distance(from: to)
        
        if distance < 1000 {
            return String(format: "%.0fm away", distance)
        } else {
            return String(format: "%.1fkm away", distance / 1000)
        }
    }
}

struct MediaPickerStep: View {
    @Binding var selectedMedia: [PhotosPickerItem]
    let onNext: () -> Void
    @State private var mediaType: MediaSelectionType = .both
    
    enum MediaSelectionType {
        case photos, videos, both
        
        var filter: PHPickerFilter {
            switch self {
            case .photos: return .images
            case .videos: return .videos
            case .both: return .any(of: [.images, .videos])
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Select Media")
                        .font(.title2)
                        .bold()
                        .padding(.top)
                    
                    Text("Choose photos or videos that showcase this spot")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Picker("Media Type", selection: $mediaType) {
                        Text("Photos").tag(MediaSelectionType.photos)
                        Text("Videos").tag(MediaSelectionType.videos)
                        Text("Both").tag(MediaSelectionType.both)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    PhotosPicker(
                        selection: $selectedMedia,
                        maxSelectionCount: 10,
                        matching: mediaType.filter
                    ) {
                        VStack(spacing: 12) {
                            HStack(spacing: 20) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 40))
                                Image(systemName: "video.fill")
                                    .font(.system(size: 40))
                            }
                            .foregroundColor(.green)
                            
                            Text("Tap to Select Media")
                                .font(.headline)
                            
                            if !selectedMedia.isEmpty {
                                Text("\(selectedMedia.count) items selected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("EXIF data will be extracted automatically", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label("Supports RAW, HEIC, JPEG, and video formats", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
            }
            
            Button(action: onNext) {
                HStack {
                    if selectedMedia.isEmpty {
                        Text("Select Media to Continue")
                    } else {
                        Text("Extract Metadata")
                        Image(systemName: "arrow.right")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedMedia.isEmpty ? Color.gray : Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(selectedMedia.isEmpty)
            .padding()
            .background(Color(.systemBackground))
        }
    }
}

#Preview {
    AddSpotView()
        .environmentObject(AppState())
}