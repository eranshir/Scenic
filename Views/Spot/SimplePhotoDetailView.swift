import SwiftUI
import MapKit
import CoreLocation

struct SimplePhotoDetailView: View {
    let media: [Media]
    @State var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
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
            .onAppear {
                print("🔍 SimplePhotoDetailView appeared with \(media.count) media items")
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
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
            
            // Placeholder for photographer tips
            VStack(alignment: .leading, spacing: 12) {
                TipCard(
                    icon: "sun.max",
                    title: "Best Time to Shoot",
                    content: "This photo was captured during golden hour. The warm, soft light enhances colors and creates beautiful shadows."
                )
                
                TipCard(
                    icon: "camera",
                    title: "Equipment Used",
                    content: "\(currentMedia?.device ?? "Camera") with \(currentMedia?.lens ?? "standard lens")"
                )
                
                if let exif = currentMedia?.exifData, let focalLength = exif.focalLength {
                    TipCard(
                        icon: "viewfinder",
                        title: "Composition",
                        content: "Shot at \(Int(focalLength))mm focal length. This focal length is ideal for this type of scene."
                    )
                }
                
                TipCard(
                    icon: "info.circle",
                    title: "Pro Tip",
                    content: "Study the light, shadows, and composition of this shot. Pay attention to the camera settings used to achieve this look."
                )
            }
        }
    }
}

// MARK: - Supporting Components

struct PhotoMetadataCard: View {
    let media: Media
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photo Information")
                .font(.headline)
            
            VStack(spacing: 8) {
                if let captureDate = media.captureTimeUTC ?? media.exifData?.dateTimeOriginal {
                    MetadataRow(label: "Captured", value: captureDate.formatted(date: .abbreviated, time: .shortened))
                }
                
                if let filename = media.originalFilename {
                    MetadataRow(label: "Filename", value: filename)
                }
                
                if let width = media.exifData?.width, let height = media.exifData?.height {
                    MetadataRow(label: "Resolution", value: "\(width) × \(height)")
                }
                
                if let device = media.device {
                    MetadataRow(label: "Device", value: device)
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
                
                // Mock sun timing (simplified for this implementation)
                HStack {
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "sunrise.fill")
                                .foregroundColor(.orange)
                            Text("Sunrise")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text("6:30 AM")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        HStack {
                            Text("Sunset")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "sunset.fill")
                                .foregroundColor(.orange)
                        }
                        Text("6:45 PM")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                // Timing context
                HStack {
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .foregroundColor(.orange)
                            Text("Golden Hour")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                    }
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

struct LocationCard: View {
    let latitude: Double
    let longitude: Double
    let heading: Float?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)
            
            VStack(spacing: 8) {
                MetadataRow(label: "Coordinates", value: String(format: "%.6f, %.6f", latitude, longitude))
                
                if let heading = heading {
                    MetadataRow(label: "Camera Direction", value: "\(Int(heading))°")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Mini map preview
            Map(initialPosition: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))) {
                Marker("Photo Location", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                    .tint(.green)
            }
            .frame(height: 150)
            .cornerRadius(10)
        }
    }
}

struct CameraInfoCard: View {
    let media: Media
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera & Lens")
                .font(.headline)
            
            VStack(spacing: 8) {
                if let make = media.exifData?.make {
                    MetadataRow(label: "Make", value: make)
                }
                
                if let model = media.exifData?.model {
                    MetadataRow(label: "Model", value: model)
                }
                
                if let lens = media.lens ?? media.exifData?.lens {
                    MetadataRow(label: "Lens", value: lens)
                }
                
                if let software = media.exifData?.software {
                    MetadataRow(label: "Software", value: software)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

struct CameraSettingsCard: View {
    let exifData: ExifData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera Settings")
                .font(.headline)
            
            VStack(spacing: 8) {
                if let focalLength = exifData.focalLength {
                    MetadataRow(label: "Focal Length", value: "\(Int(focalLength))mm")
                }
                
                if let aperture = exifData.fNumber {
                    MetadataRow(label: "Aperture", value: "f/\(aperture)")
                }
                
                if let exposureTime = exifData.exposureTime {
                    MetadataRow(label: "Shutter Speed", value: exposureTime)
                }
                
                if let iso = exifData.iso {
                    MetadataRow(label: "ISO", value: String(iso))
                }
                
                if let colorSpace = exifData.colorSpace {
                    MetadataRow(label: "Color Space", value: colorSpace)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
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

#Preview {
    SimplePhotoDetailView(
        media: [
            Media(
                id: UUID(),
                spotId: UUID(),
                userId: UUID(),
                type: .photo,
                url: "sample-photo",
                thumbnailUrl: nil,
                captureTimeUTC: Date(),
                exifData: ExifData(
                    make: "Apple",
                    model: "iPhone 15 Pro",
                    lens: "iPhone 15 Pro back triple camera 6.86mm f/1.78",
                    focalLength: 24,
                    fNumber: 1.78,
                    exposureTime: "1/250",
                    iso: 64,
                    dateTimeOriginal: Date(),
                    gpsLatitude: 37.7749,
                    gpsLongitude: -122.4194,
                    gpsDirection: 180,
                    width: 4032,
                    height: 3024
                ),
                device: "iPhone 15 Pro",
                lens: "Main Camera",
                focalLengthMM: 24,
                aperture: 1.78,
                shutterSpeed: "1/250",
                iso: 64,
                resolutionWidth: 4032,
                resolutionHeight: 3024,
                presets: [],
                filters: [],
                headingFromExif: true,
                originalFilename: "IMG_1234.HEIC",
                createdAt: Date()
            )
        ],
        selectedIndex: 0
    )
}