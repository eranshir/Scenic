import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var spotDataService: SpotDataService
    @Binding var selectedSpotId: UUID?
    @Binding var mapCameraPosition: MapCameraPosition
    
    var body: some View {
        Map(position: $mapCameraPosition, interactionModes: .all, selection: $selectedSpotId) {
            ForEach(spotDataService.spots.isEmpty ? mockSpots : spotDataService.spots) { spot in
                Annotation(spot.title, coordinate: spot.location) {
                    NavigationLink(destination: SpotDetailView(spot: spot)) {
                        SpotMapPin(spot: spot, isSelected: selectedSpotId == spot.id)
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

// Empty mock data - app will use real database spots
let mockSpots: [Spot] = []

#Preview {
    MapView(
        selectedSpotId: .constant(nil as UUID?),
        mapCameraPosition: .constant(.automatic)
    )
    .environmentObject(AppState())
}