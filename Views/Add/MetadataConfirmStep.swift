import SwiftUI
import MapKit
import PhotosUI

struct MetadataConfirmStep: View {
    @Binding var spotData: NewSpotData
    let extractedMetadata: [ExtractedPhotoMetadata]
    let onNext: () -> Void
    let onBack: () -> Void
    
    @State private var selectedTab = 0
    @State private var isEditingLocation = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Review & Enhance Details")
                        .font(.title2)
                        .bold()
                        .padding(.top)
                    
                    // Tab selector for different sections
                    Picker("Section", selection: $selectedTab) {
                        Text("Basic").tag(0)
                        Text("Camera").tag(1)
                        Text("Settings").tag(2)
                        Text("Tips").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    Group {
                        switch selectedTab {
                        case 0:
                            basicInfoSection
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
                    
                    // Add some padding at the bottom for scrolling
                    Color.clear.frame(height: 20)
                }
            }
            
            // Navigation buttons outside ScrollView but inside main VStack
            navigationButtons
        }
    }
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            VStack(alignment: .leading) {
                HStack {
                    Text("Spot Title")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("*")
                        .foregroundColor(.red)
                    Text("(Required)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                TextField("e.g., Golden Gate Bridge Sunset Point", text: $spotData.title)
                    .textFieldStyle(.roundedBorder)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(spotData.title.isEmpty ? Color.orange : Color.clear, lineWidth: 2)
                    )
            }
            
            // Location
            VStack(alignment: .leading) {
                HStack {
                    Text("Location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let location = spotData.location {
                        Text("(\(location.latitude, specifier: "%.6f"), \(location.longitude, specifier: "%.6f"))")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else {
                        Text("(Not detected - tap map to set)")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: spotData.location ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))) {
                    if let location = spotData.location {
                        Marker("Photo Spot", coordinate: location)
                            .tint(.green)
                    }
                }
                .frame(height: 200)
                .cornerRadius(10)
                .overlay(
                    Button(action: { isEditingLocation.toggle() }) {
                        Label("Adjust", systemImage: "location.fill")
                            .font(.caption)
                            .padding(6)
                            .background(Color.white)
                            .cornerRadius(6)
                            .shadow(radius: 2)
                    }
                    .padding(8),
                    alignment: .topTrailing
                )
            }
            
            // Heading and Elevation
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Camera Heading")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        TextField("0", value: $spotData.heading, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                        Text("°")
                        Image(systemName: "location.north.line.fill")
                            .rotationEffect(.degrees(Double(spotData.heading ?? 0)))
                            .foregroundColor(.green)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Elevation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        TextField("0", value: $spotData.elevation, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                        Text("m")
                    }
                }
            }
            
            // Capture Time
            if let captureDate = spotData.captureDate {
                VStack(alignment: .leading) {
                    Text("Capture Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "calendar")
                        Text(captureDate, style: .date)
                        Spacer()
                        Image(systemName: "clock")
                        Text(captureDate, style: .time)
                    }
                    .font(.footnote)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            
            // Difficulty
            VStack(alignment: .leading) {
                Text("Access Difficulty")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Difficulty", selection: $spotData.difficulty) {
                    ForEach(Spot.Difficulty.allCases, id: \.self) { difficulty in
                        Text(difficulty.displayName).tag(difficulty)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Tags
            VStack(alignment: .leading) {
                Text("Subject Tags")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TagSelector(selectedTags: $spotData.tags)
            }
        }
    }
    
    private var cameraDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Camera & Lens Info
            if let firstMetadata = extractedMetadata.first {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Camera & Lens")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Camera")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Camera Model", text: Binding(
                                get: { spotData.cameraModel ?? firstMetadata.cameraModel ?? "Unknown" },
                                set: { spotData.cameraModel = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Make")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Make", text: Binding(
                                get: { spotData.cameraMake ?? firstMetadata.cameraMake ?? "" },
                                set: { spotData.cameraMake = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Lens")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Lens Model", text: Binding(
                            get: { spotData.lensModel ?? firstMetadata.lensModel ?? "Unknown" },
                            set: { spotData.lensModel = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                }
                
                Divider()
            }
            
            // Processing Software
            VStack(alignment: .leading) {
                Text("Post-Processing")
                    .font(.headline)
                
                VStack(alignment: .leading) {
                    Text("Software")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g., Lightroom, Capture One", text: Binding(
                        get: { spotData.software ?? "" },
                        set: { spotData.software = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading) {
                    Text("Presets/Profiles Used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g., Landscape Vivid, Custom B&W", text: Binding(
                        get: { spotData.presets.joined(separator: ", ") },
                        set: { spotData.presets = $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading) {
                    Text("Editing Notes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Describe your editing workflow", text: $spotData.editingNotes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
            }
        }
    }
    
    private var photographySettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Camera Settings")
                .font(.headline)
            
            if let firstMetadata = extractedMetadata.first,
               // Check if we have any actual EXIF data
               (firstMetadata.aperture != nil || firstMetadata.shutterSpeed != nil || 
                firstMetadata.iso != nil || firstMetadata.focalLength != nil) {
                // Display extracted EXIF data
                VStack(spacing: 12) {
                    ExifRow(label: "Focal Length", 
                           value: firstMetadata.focalLength.map { "\(Int($0))mm" },
                           value35mm: firstMetadata.focalLengthIn35mm.map { "(\(Int($0))mm in 35mm)" })
                    
                    ExifRow(label: "Aperture", 
                           value: firstMetadata.aperture.map { "f/\($0)" })
                    
                    ExifRow(label: "Shutter Speed", 
                           value: firstMetadata.shutterSpeed)
                    
                    ExifRow(label: "ISO", 
                           value: firstMetadata.iso.map { String($0) })
                    
                    ExifRow(label: "Exposure Bias", 
                           value: firstMetadata.exposureBias.map { String(format: "%.1f EV", $0) })
                    
                    ExifRow(label: "Metering Mode", 
                           value: firstMetadata.meteringMode)
                    
                    ExifRow(label: "White Balance", 
                           value: firstMetadata.whiteBalance)
                    
                    ExifRow(label: "Flash", 
                           value: firstMetadata.flash == true ? "Fired" : "Did not fire")
                    
                    if let width = firstMetadata.width, let height = firstMetadata.height {
                        ExifRow(label: "Resolution", 
                               value: "\(width) × \(height)",
                               value35mm: firstMetadata.megapixels.map { String(format: "%.1f MP", $0) })
                    }
                    
                    if let aspectRatio = firstMetadata.aspectRatio {
                        ExifRow(label: "Aspect Ratio", value: aspectRatio)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            } else {
                // Manual entry fields
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("No EXIF data detected in selected media")
                            .font(.footnote)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    Text("You can enter camera settings manually (optional):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 12) {
                    HStack {
                        TextField("Focal Length (mm)", value: $spotData.focalLength, format: .number)
                            .textFieldStyle(.roundedBorder)
                        TextField("Aperture (f/)", value: $spotData.aperture, format: .number.precision(.fractionLength(1)))
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        TextField("Shutter Speed", text: Binding(
                            get: { spotData.shutterSpeed ?? "" },
                            set: { spotData.shutterSpeed = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        
                        TextField("ISO", value: $spotData.iso, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
        }
    }
    
    private var photographerTipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tips for Other Photographers")
                .font(.headline)
            
            VStack(alignment: .leading) {
                Label("Best Time to Shoot", systemImage: "sun.max")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("e.g., Golden hour, 30 min before sunset", text: $spotData.bestTimeNotes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
            
            VStack(alignment: .leading) {
                Label("Recommended Equipment", systemImage: "camera")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("e.g., Wide angle lens, tripod, ND filters", text: $spotData.equipmentTips, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
            
            VStack(alignment: .leading) {
                Label("Composition Tips", systemImage: "viewfinder")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("e.g., Use foreground rocks for depth", text: $spotData.compositionTips, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
            
            VStack(alignment: .leading) {
                Label("Seasonal Notes", systemImage: "leaf")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("e.g., Best in fall for colors, avoid summer crowds", text: $spotData.seasonalNotes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
        }
    }
    
    private var navigationButtons: some View {
        VStack(spacing: 8) {
            if spotData.title.isEmpty {
                Text("Please enter a spot title to continue")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal)
            }
            
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
                    .background(spotData.title.isEmpty ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(spotData.title.isEmpty)
            }
        }
        .padding()
    }
}

struct ExifRow: View {
    let label: String
    let value: String?
    var value35mm: String? = nil
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value ?? "—")
                .font(.footnote)
                .fontWeight(.medium)
            
            if let value35mm = value35mm {
                Text(value35mm)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct TagSelector: View {
    @Binding var selectedTags: [String]
    
    let availableTags = [
        "Sunrise", "Sunset", "Golden Hour", "Blue Hour",
        "Mountains", "Ocean", "Forest", "Desert",
        "Urban", "Wildlife", "Waterfall", "Lake",
        "Bridge", "Architecture", "Night Sky", "Beach",
        "Trail", "Landscape", "Portrait", "Street",
        "Astro", "Macro", "Long Exposure", "HDR"
    ]
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
            ForEach(availableTags, id: \.self) { tag in
                Button(action: {
                    if selectedTags.contains(tag) {
                        selectedTags.removeAll { $0 == tag }
                    } else {
                        selectedTags.append(tag)
                    }
                }) {
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedTags.contains(tag) ? Color.green : Color(.systemGray5))
                        .foregroundColor(selectedTags.contains(tag) ? .white : .primary)
                        .cornerRadius(15)
                }
            }
        }
    }
}