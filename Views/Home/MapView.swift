import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedSpotId: UUID?
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )
    
    var body: some View {
        Map(position: $cameraPosition, selection: $selectedSpotId, interactionModes: .all) {
            ForEach(mockSpots) { spot in
                Annotation(spot.title, coordinate: spot.location) {
                    SpotMapPin(spot: spot, isSelected: selectedSpotId == spot.id)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSpotId = spot.id
                            }
                        }
                }
            }
            
            UserAnnotation()
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .safeAreaInset(edge: .bottom) {
            if let selectedId = selectedSpotId,
               let spot = mockSpots.first(where: { $0.id == selectedId }) {
                SpotPreviewCard(spot: spot)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

struct SpotMapPin: View {
    let spot: Spot
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green)
                .frame(width: isSelected ? 40 : 30, height: isSelected ? 40 : 30)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
            
            Image(systemName: "camera.fill")
                .foregroundColor(.white)
                .font(.system(size: isSelected ? 18 : 14))
        }
        .shadow(radius: 3)
    }
}

struct SpotPreviewCard: View {
    let spot: Spot
    @State private var showDetail = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(spot.title)
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Label("\(spot.difficulty.displayName)", systemImage: "figure.hiking")
                            .font(.caption)
                        
                        if let snapshot = spot.sunSnapshot {
                            if snapshot.isGoldenHour {
                                Label("Golden Hour", systemImage: "sun.max.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else if snapshot.isBlueHour {
                                Label("Blue Hour", systemImage: "moon.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    HStack {
                        ForEach(spot.subjectTags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
                
                NavigationLink(destination: SpotDetailView(spot: spot)) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
}

let mockSpots = [
    Spot(
        id: UUID(),
        title: "Golden Gate Vista",
        location: CLLocationCoordinate2D(latitude: 37.8024, longitude: -122.4058),
        headingDegrees: 180,
        elevationMeters: 100,
        subjectTags: ["Bridge", "Sunset", "Ocean"],
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
        title: "Baker Beach Sunset",
        location: CLLocationCoordinate2D(latitude: 37.7936, longitude: -122.4836),
        headingDegrees: 90,
        elevationMeters: 10,
        subjectTags: ["Beach", "Sunset", "Bridge"],
        difficulty: .veryEasy,
        createdBy: UUID(),
        privacy: .publicSpot,
        license: "CC-BY-NC",
        status: .active,
        createdAt: Date(),
        updatedAt: Date()
    ),
    Spot(
        id: UUID(),
        title: "Lands End Trail",
        location: CLLocationCoordinate2D(latitude: 37.7879, longitude: -122.5060),
        headingDegrees: 270,
        elevationMeters: 60,
        subjectTags: ["Trail", "Ocean", "Cliffs"],
        difficulty: .moderate,
        createdBy: UUID(),
        privacy: .publicSpot,
        license: "CC-BY-NC",
        status: .active,
        createdAt: Date(),
        updatedAt: Date()
    )
]

#Preview {
    MapView(selectedSpotId: .constant(nil))
        .environmentObject(AppState())
}