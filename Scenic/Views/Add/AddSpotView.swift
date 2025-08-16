import SwiftUI
import PhotosUI
import Photos
import CoreLocation
import MapKit
import CoreData

struct PlacemarkData {
    let country: String?
    let countryCode: String?
    let administrativeArea: String?
    let subAdministrativeArea: String?
    let locality: String?
    let subLocality: String?
    let thoroughfare: String?
    let subThoroughfare: String?
    let postalCode: String?
    let locationName: String?
    let areasOfInterest: [String]?
}

struct AddSpotView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var spotDataService: SpotDataService
    @State private var selectedMedia: [PhotosPickerItem] = []
    @State private var extractedMetadata: [ExtractedPhotoMetadata] = []
    @State private var currentStep = AddSpotStep.selectMedia
    @State private var spotData = NewSpotData()
    @StateObject private var metadataExtractor = PhotoMetadataExtractor()
    @State private var showingSuccessMessage = false
    @State private var isProcessing = false
    
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
                                Task {
                                    await saveSpotToDatabase()
                                }
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
            .onAppear {
                // Ensure clean state when view appears
                if !isProcessing && currentStep == .selectMedia {
                    resetForm()
                }
            }
            .onDisappear {
                // Clean up when leaving the view
                isProcessing = false
            }
            .overlay(
                // Success message overlay
                Group {
                    if showingSuccessMessage {
                        VStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            Text("Spot Saved Successfully!")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Your spot has been saved to your local collection")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: showingSuccessMessage)
            )
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
    
    private func saveSpotToDatabase() async {
        guard !isProcessing else { return }
        isProcessing = true
        
        if spotData.isNewSpot {
            // Create new spot
            await createNewSpot()
        } else if let existingSpot = spotData.selectedExistingSpot {
            // Add photos to existing spot
            await addPhotosToExistingSpot(existingSpot)
        }
        
        // Show success and reset form
        showingSuccessMessage = true
        resetForm()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showingSuccessMessage = false
            isProcessing = false
            // Navigate back to map or show the created spot
            // appState.selectedTab = .home // TODO: Handle navigation
        }
    }
    
    private func createNewSpot() async {
        
        // Convert NewSpotData to Spot model
        let spot = Spot(
            id: UUID(),
            title: spotData.title.isEmpty ? "Untitled Spot" : spotData.title,
            location: spotData.location ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
            headingDegrees: spotData.heading,
            elevationMeters: spotData.elevation,
            subjectTags: spotData.tags,
            difficulty: spotData.difficulty,
            createdBy: UUID(), // TODO: Replace with actual user ID
            privacy: .publicSpot,
            license: "CC-BY-NC", // Default license
            status: .active,
            createdAt: Date(),
            updatedAt: Date(),
            country: spotData.placemarkData?.country,
            countryCode: spotData.placemarkData?.countryCode,
            administrativeArea: spotData.placemarkData?.administrativeArea,
            subAdministrativeArea: spotData.placemarkData?.subAdministrativeArea,
            locality: spotData.placemarkData?.locality,
            subLocality: spotData.placemarkData?.subLocality,
            thoroughfare: spotData.placemarkData?.thoroughfare,
            subThoroughfare: spotData.placemarkData?.subThoroughfare,
            postalCode: spotData.placemarkData?.postalCode,
            locationName: spotData.placemarkData?.locationName,
            areasOfInterest: spotData.placemarkData?.areasOfInterest,
            media: createMediaFromExtractedData(),
            sunSnapshot: nil, // TODO: Add sun snapshot if available
            weatherSnapshot: nil, // TODO: Add weather snapshot if available
            accessInfo: createAccessInfo(),
            comments: [],
            voteCount: 0
        )
        
        // Save to database first to create CDMedia entities
        spotDataService.saveSpot(spot)
        
        // Cache the selected photos using the new cache system
        await cacheSelectedPhotos(spot: spot)
        
        print("✅ Created new spot: \(spot.title)")
    }
    
    private func createExifData(from metadata: ExtractedPhotoMetadata) -> ExifData {
        return ExifData(
            make: metadata.cameraMake,
            model: metadata.cameraModel,
            lens: metadata.lensModel,
            focalLength: metadata.focalLength,
            fNumber: metadata.aperture,
            exposureTime: metadata.shutterSpeed,
            iso: metadata.iso,
            dateTimeOriginal: metadata.captureDate,
            gpsLatitude: metadata.location?.latitude,
            gpsLongitude: metadata.location?.longitude,
            gpsAltitude: metadata.altitude != nil ? Double(metadata.altitude!) : nil,
            gpsDirection: metadata.heading != nil ? Float(metadata.heading!) : nil,
            width: nil,
            height: nil,
            colorSpace: nil,
            software: nil
        )
    }
    
    private func addPhotosToExistingSpot(_ existingSpot: Spot) async {
        // First, cache the photos BEFORE creating media objects
        print("📸 Caching \(selectedMedia.count) new photos for existing spot")
        
        // Create media objects with proper caching
        var cachedMedia: [Media] = []
        for (index, photoItem) in selectedMedia.enumerated() {
            if index < extractedMetadata.count {
                let metadata = extractedMetadata[index]
                let mediaId = UUID()
                
                // Cache the photo first
                let cdMedia = CDMedia(context: PersistenceController.shared.container.viewContext)
                cdMedia.id = mediaId
                cdMedia.url = "local_\(mediaId.uuidString)"
                
                let success = await PhotoLoader.shared.cacheFromPhotosPicker(item: photoItem, cdMedia: cdMedia)
                
                if success {
                    print("✅ Cached photo \(index + 1) with ID: \(mediaId)")
                    
                    // Create the Media object only if caching succeeded
                    let media = Media(
                        id: mediaId,
                        spotId: existingSpot.id,
                        userId: UUID(), // TODO: Use actual user ID
                        type: .photo,
                        url: "local_\(mediaId.uuidString)",
                        thumbnailUrl: nil,
                        captureTimeUTC: metadata.captureDate,
                        exifData: createExifData(from: metadata),
                        device: metadata.cameraModel,
                        lens: metadata.lensModel,
                        focalLengthMM: metadata.focalLength,
                        aperture: metadata.aperture,
                        shutterSpeed: metadata.shutterSpeed,
                        iso: metadata.iso,
                        presets: [],
                        filters: [],
                        headingFromExif: metadata.heading != nil,
                        originalFilename: nil,
                        createdAt: Date()
                    )
                    cachedMedia.append(media)
                } else {
                    print("❌ Failed to cache photo \(index + 1)")
                }
            }
        }
        
        // Create updated spot with the successfully cached media
        let updatedSpot = Spot(
            id: existingSpot.id, // Keep existing ID
            title: existingSpot.title,
            location: existingSpot.location,
            headingDegrees: existingSpot.headingDegrees,
            elevationMeters: existingSpot.elevationMeters,
            subjectTags: existingSpot.subjectTags,
            difficulty: existingSpot.difficulty,
            createdBy: existingSpot.createdBy,
            privacy: existingSpot.privacy,
            license: existingSpot.license,
            status: existingSpot.status,
            createdAt: existingSpot.createdAt,
            updatedAt: Date(), // Update timestamp
            country: existingSpot.country,
            countryCode: existingSpot.countryCode,
            administrativeArea: existingSpot.administrativeArea,
            subAdministrativeArea: existingSpot.subAdministrativeArea,
            locality: existingSpot.locality,
            subLocality: existingSpot.subLocality,
            thoroughfare: existingSpot.thoroughfare,
            subThoroughfare: existingSpot.subThoroughfare,
            postalCode: existingSpot.postalCode,
            locationName: existingSpot.locationName,
            areasOfInterest: existingSpot.areasOfInterest,
            media: existingSpot.media + cachedMedia, // Append only successfully cached media
            sunSnapshot: existingSpot.sunSnapshot,
            weatherSnapshot: existingSpot.weatherSnapshot,
            accessInfo: existingSpot.accessInfo,
            comments: existingSpot.comments,
            voteCount: existingSpot.voteCount
        )
        
        // Save updated spot to database
        spotDataService.saveSpot(updatedSpot)
        
        print("✅ Added \(cachedMedia.count) photos to existing spot: \(existingSpot.title)")
    }
    
    private func createMediaFromExtractedData() -> [Media] {
        return extractedMetadata.enumerated().map { index, metadata in
            // Generate a unique identifier for local storage
            let mediaId = UUID()
            let photoIdentifier = "local_\(mediaId.uuidString)"
            print("💾 Creating media with local identifier: \(photoIdentifier)")
            
            return Media(
                id: mediaId,
                spotId: nil, // Will be set by the relationship
                userId: UUID(), // TODO: Replace with actual user ID
                type: .photo, // Assuming photos for now
                url: photoIdentifier, // Store our local identifier
                thumbnailUrl: nil,
                captureTimeUTC: metadata.captureDate,
                exifData: ExifData(
                    make: metadata.cameraMake,
                    model: metadata.cameraModel,
                    lens: metadata.lensModel,
                    focalLength: metadata.focalLength,
                    fNumber: metadata.aperture,
                    exposureTime: metadata.shutterSpeed,
                    iso: metadata.iso,
                    dateTimeOriginal: metadata.captureDate,
                    gpsLatitude: metadata.location?.latitude,
                    gpsLongitude: metadata.location?.longitude,
                    gpsAltitude: metadata.altitude,
                    gpsDirection: metadata.heading.map { Float($0) },
                    width: metadata.width,
                    height: metadata.height,
                    colorSpace: metadata.colorSpace,
                    software: metadata.software
                ),
                device: [metadata.cameraMake, metadata.cameraModel].compactMap { $0 }.joined(separator: " "),
                lens: metadata.lensModel,
                focalLengthMM: metadata.focalLength,
                aperture: metadata.aperture,
                shutterSpeed: metadata.shutterSpeed,
                iso: metadata.iso,
                resolutionWidth: metadata.width,
                resolutionHeight: metadata.height,
                presets: [],
                filters: [],
                headingFromExif: metadata.heading != nil,
                originalFilename: selectedMedia[safe: index]?.itemIdentifier ?? "Photo.HEIC",
                createdAt: Date()
            )
        }
    }
    
    private func createAccessInfo() -> AccessInfo? {
        guard spotData.parkingLocation != nil || 
              spotData.routePolyline != nil ||
              !spotData.hazards.isEmpty ||
              !spotData.fees.isEmpty else {
            return nil
        }
        
        return AccessInfo(
            id: UUID(),
            spotId: UUID(), // Will be set by the relationship
            parkingLocation: spotData.parkingLocation,
            routePolyline: spotData.routePolyline,
            routeDistanceMeters: nil,
            routeElevationGainMeters: nil,
            routeDifficulty: nil,
            hazards: spotData.hazards,
            fees: spotData.fees,
            notes: nil,
            estimatedHikingTimeMinutes: nil
        )
    }
    
    private func resetForm() {
        selectedMedia = []
        extractedMetadata = []
        currentStep = .selectMedia
        spotData = NewSpotData()
    }
    
    // MARK: - Photo Caching
    
    private func cacheSelectedPhotos(spot: Spot) async {
        print("📁 Starting photo caching for \(selectedMedia.count) photos")
        
        let photoLoader = PhotoLoader.shared
        let context = PersistenceController.shared.container.viewContext
        
        let fetchRequest: NSFetchRequest<CDSpot> = CDSpot.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", spot.id as CVarArg)
        
        do {
            let cdSpots = try context.fetch(fetchRequest)
            guard let cdSpot = cdSpots.first else {
                print("❌ Could not find CDSpot for ID: \(spot.id)")
                return
            }
            
            let cdMediaItems = (cdSpot.media?.allObjects as? [CDMedia]) ?? []
            print("📸 Found \(cdMediaItems.count) CDMedia items to cache")
            
            for (index, mediaItem) in selectedMedia.enumerated() {
                if index < cdMediaItems.count {
                    let cdMedia = cdMediaItems[index]
                    print("💾 Caching photo \(index + 1)/\(selectedMedia.count)")
                    
                    let success = await photoLoader.cacheFromPhotosPicker(item: mediaItem, cdMedia: cdMedia)
                    
                    if success {
                        print("✅ Successfully cached photo \(index + 1)")
                    } else {
                        print("❌ Failed to cache photo \(index + 1)")
                    }
                }
            }
            
            try context.save()
            print("💿 Saved cache information to Core Data")
            
        } catch {
            print("❌ Error caching photos: \(error)")
        }
    }
}

// Safe array access extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
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
    
    // Location metadata from reverse geocoding
    var placemarkData: PlacemarkData?
    
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
    @EnvironmentObject var spotDataService: SpotDataService
    
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
                    
                    // Store all location data from placemark in spotData
                    spotData.placemarkData = PlacemarkData(
                        country: placemark.country,
                        countryCode: placemark.isoCountryCode,
                        administrativeArea: placemark.administrativeArea,
                        subAdministrativeArea: placemark.subAdministrativeArea,
                        locality: placemark.locality,
                        subLocality: placemark.subLocality,
                        thoroughfare: placemark.thoroughfare,
                        subThoroughfare: placemark.subThoroughfare,
                        postalCode: placemark.postalCode,
                        locationName: placemark.name,
                        areasOfInterest: placemark.areasOfInterest
                    )
                    
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
        print("🔍 Searching for spots near location: \(location.latitude), \(location.longitude)")
        
        // Search for spots within 100m radius using the SpotDataService
        let nearbyFiltered = spotDataService.filterSpots(
            nearLocation: (
                latitude: location.latitude,
                longitude: location.longitude,
                radiusKM: 0.1 // 100 meters = 0.1 km
            )
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🎯 Found \(nearbyFiltered.count) nearby spots")
            nearbySpots = nearbyFiltered
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