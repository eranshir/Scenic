import SwiftUI
import MapKit

struct PublishStep: View {
    @Binding var spotData: NewSpotData
    @EnvironmentObject var appState: AppState
    let onPublish: () -> Void
    let onBack: () -> Void
    
    @State private var privacy: Spot.Privacy = .publicSpot
    @State private var license = "CC-BY-NC"
    @State private var isPublishing = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Review & Publish")
                        .font(.title2)
                        .bold()
                        .padding(.top)
                    
                    // Preview Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Preview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        spotPreviewCard
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Details Summary
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Details Summary")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        detailsSummary
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Privacy & License
                    VStack(spacing: 16) {
                        VStack(alignment: .leading) {
                            Text("Privacy")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("Privacy", selection: $privacy) {
                                Text("Public").tag(Spot.Privacy.publicSpot)
                                Text("Private").tag(Spot.Privacy.privateSpot)
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("License")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("License", selection: $license) {
                                Text("CC-BY-NC").tag("CC-BY-NC")
                                Text("CC-BY").tag("CC-BY")
                                Text("All Rights Reserved").tag("ARR")
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                    .padding(.horizontal)
                    
                    // Add some padding at bottom
                    Color.clear.frame(height: 20)
                }
            }
            
            // Action Buttons pinned at bottom
            VStack(spacing: 12) {
                Button(action: {
                    Task {
                        await publishSpot()
                    }
                }) {
                    HStack {
                        if isPublishing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                            Text("Publishing...")
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Publish Spot")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(spotData.title.isEmpty ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(spotData.title.isEmpty || isPublishing)
                
                Button(action: onBack) {
                    Text("Back to Edit")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(10)
                }
                .disabled(isPublishing)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .alert("Success!", isPresented: $showSuccessAlert) {
            Button("OK") {
                // Reset the form and go back to the beginning or dismiss
                onPublish()
            }
        } message: {
            Text("Your spot has been published successfully!")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var spotPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and location
            Text(spotData.title.isEmpty ? "Untitled Spot" : spotData.title)
                .font(.title3)
                .bold()
            
            if let location = spotData.location {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("(\(location.latitude, specifier: "%.4f"), \(location.longitude, specifier: "%.4f"))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Map Preview
            if let location = spotData.location {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: location,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))) {
                    Marker("Photo Spot", coordinate: location)
                        .tint(.green)
                    
                    if let parking = spotData.parkingLocation {
                        Marker("Parking", coordinate: parking)
                            .tint(.blue)
                    }
                }
                .frame(height: 150)
                .cornerRadius(8)
                .disabled(true)
            }
            
            // Tags
            if !spotData.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(spotData.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(15)
                        }
                    }
                }
            }
            
            // Difficulty
            HStack {
                Image(systemName: "figure.hiking")
                Text("Difficulty: \(convertDifficulty(spotData.difficulty).displayName)")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
    }
    
    private var detailsSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Camera Info
            if let camera = spotData.cameraModel {
                detailRow(icon: "camera", title: "Camera", value: camera)
            }
            
            if let lens = spotData.lensModel {
                detailRow(icon: "camera.aperture", title: "Lens", value: lens)
            }
            
            // Settings
            if spotData.focalLength != nil || spotData.aperture != nil || spotData.iso != nil {
                HStack(spacing: 16) {
                    if let focal = spotData.focalLength {
                        settingBadge(label: "\(Int(focal))mm")
                    }
                    if let aperture = spotData.aperture {
                        settingBadge(label: String(format: "f/%.1f", aperture))
                    }
                    if let iso = spotData.iso {
                        settingBadge(label: "ISO \(iso)")
                    }
                    if let shutter = spotData.shutterSpeed {
                        settingBadge(label: shutter)
                    }
                }
                .font(.caption)
            }
            
            // Access Info
            if spotData.parkingLocation != nil {
                detailRow(icon: "car.fill", title: "Parking", value: "Location set")
            }
            
            if !spotData.hazards.isEmpty {
                detailRow(icon: "exclamationmark.triangle", title: "Hazards", value: spotData.hazards.joined(separator: ", "))
            }
            
            if !spotData.fees.isEmpty {
                detailRow(icon: "dollarsign.circle", title: "Fees", value: spotData.fees.joined(separator: ", "))
            }
            
            // Tips
            if !spotData.bestTimeNotes.isEmpty {
                detailRow(icon: "sun.max", title: "Best Time", value: spotData.bestTimeNotes)
            }
            
            if !spotData.equipmentTips.isEmpty {
                detailRow(icon: "backpack", title: "Equipment", value: spotData.equipmentTips)
            }
            
            if !spotData.notes.isEmpty {
                detailRow(icon: "note.text", title: "Notes", value: spotData.notes)
            }
        }
    }
    
    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.footnote)
            }
            
            Spacer()
        }
    }
    
    private func settingBadge(label: String) -> some View {
        Text(label)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray5))
            .cornerRadius(6)
    }
    
    private func convertDifficulty(_ difficulty: Spot.Difficulty) -> Spot.Difficulty {
        // Direct passthrough since NewSpotData already uses Spot.Difficulty
        return difficulty
    }
    
    private func publishSpot() async {
        isPublishing = true
        
        // Simulate API call
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Here you would normally make an API call to save the spot
        // For now, we'll just create a local spot and add it to the app state
        
        var newSpot = Spot(
            id: UUID(),
            title: spotData.title,
            location: spotData.location ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
            headingDegrees: spotData.heading,
            elevationMeters: spotData.elevation,
            subjectTags: spotData.tags,
            difficulty: spotData.difficulty,
            createdBy: UUID(), // This would be the current user's ID
            privacy: privacy,
            license: license,
            status: .active,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Create AccessInfo if we have parking or route data
        if spotData.parkingLocation != nil || !spotData.hazards.isEmpty || !spotData.fees.isEmpty || spotData.routePolyline != nil {
            let accessInfo = AccessInfo(
                id: UUID(),
                spotId: newSpot.id,
                parkingLocation: spotData.parkingLocation,
                routePolyline: spotData.routePolyline,
                routeDistanceMeters: nil, // Would be calculated from route
                routeElevationGainMeters: nil, // Would be calculated from route
                routeDifficulty: nil,
                hazards: spotData.hazards,
                fees: spotData.fees,
                notes: spotData.notes.isEmpty ? nil : spotData.notes,
                estimatedHikingTimeMinutes: nil // Would be calculated
            )
            newSpot.accessInfo = accessInfo
        }
        
        // Add to app state
        await MainActor.run {
            // Note: We would need to update AppState to have a spots array
            // For now, just mark as published
            isPublishing = false
            showSuccessAlert = true
        }
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.footnote)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}