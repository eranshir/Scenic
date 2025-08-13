import SwiftUI
import MapKit

struct PublishStep: View {
    @Binding var spotData: NewSpotData
    @EnvironmentObject var appState: AppState
    let onPublish: () -> Void
    let onBack: () -> Void
    
    @State private var license = "CC-BY-NC"
    @State private var isPublishing = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var publishedAsPublic = false
    
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
                    
                    // Add substantial padding at bottom to ensure content is above tab bar
                    Color.clear.frame(height: 100)
                }
            }
            
            // Compact Action Section pinned at bottom
            VStack(spacing: 12) {
                // Primary Action: Save and Publish (with license chooser)
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        // Main publish button
                        Button(action: {
                            Task {
                                await publishSpot(asPublic: true)
                            }
                        }) {
                            HStack {
                                if isPublishing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                    Text("Publishing...")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                } else {
                                    Image(systemName: "globe")
                                    Text("Save & Publish")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(spotData.title.isEmpty ? Color.gray : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(spotData.title.isEmpty || isPublishing)
                        
                        // Inline license chooser
                        Picker("License", selection: $license) {
                            Text("CC-BY-NC").tag("CC-BY-NC")
                            Text("CC-BY").tag("CC-BY") 
                            Text("All Rights Reserved").tag("ARR")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                        .disabled(spotData.title.isEmpty || isPublishing)
                    }
                    
                    // Helper text for publishing
                    Text("Share with the Scenic community under your chosen license")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Secondary actions row
                HStack(spacing: 12) {
                    // Back button (smaller, secondary)
                    Button(action: onBack) {
                        HStack {
                            Image(systemName: "chevron.left")
                                .font(.caption)
                            Text("Back")
                                .font(.footnote)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                    }
                    .disabled(isPublishing)
                    
                    // Secondary save-only button
                    Button(action: {
                        Task {
                            await publishSpot(asPublic: false)
                        }
                    }) {
                        HStack {
                            if isPublishing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                                Text("Saving...")
                                    .font(.footnote)
                            } else {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                Text("Just Save")
                                    .font(.footnote)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray4))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(spotData.title.isEmpty || isPublishing)
                }
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
            Text(publishedAsPublic ? "Your spot has been saved to your journal and published to the community!" : "Your spot has been saved to your journal!")
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
            // Always show at least basic info
            let hasAnyData = spotData.cameraModel != nil || 
                            spotData.lensModel != nil ||
                            spotData.focalLength != nil ||
                            spotData.aperture != nil ||
                            spotData.iso != nil ||
                            spotData.shutterSpeed != nil ||
                            spotData.parkingLocation != nil ||
                            !spotData.hazards.isEmpty ||
                            !spotData.fees.isEmpty ||
                            !spotData.bestTimeNotes.isEmpty ||
                            !spotData.equipmentTips.isEmpty ||
                            !spotData.notes.isEmpty
            
            if !hasAnyData {
                // Show placeholder when no data is available
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text("No additional details provided")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Text("You can add camera settings, access information, and tips in the previous steps.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            } else {
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
    
    private func publishSpot(asPublic: Bool) async {
        isPublishing = true
        
        // Simulate API call
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Here you would normally make an API call to save the spot
        // For now, we'll just create a local spot and add it to the app state
        
        let privacy: Spot.Privacy = asPublic ? .publicSpot : .privateSpot
        let finalLicense = asPublic ? license : "Private" // Private spots don't need public licenses
        
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
            license: finalLicense,
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
            publishedAsPublic = asPublic
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