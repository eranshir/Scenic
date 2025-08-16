import SwiftUI
import MapKit
import CoreLocation

struct RouteStep: View {
    @Binding var spotData: NewSpotData
    let onNext: () -> Void
    let onBack: () -> Void
    
    @State private var isDrawingRoute = false
    @State private var isSettingParking = false
    @State private var routePoints: [CLLocationCoordinate2D] = []
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Access & Route")
                        .font(.title2)
                        .bold()
                        .padding(.top)
                    
                    mapSection
                    
                    routeInfoDisplay
                    
                    accessDetailsSection
                    
                    // Add padding at bottom for scroll content
                    Color.clear.frame(height: 20)
                }
            }
            
            // Navigation buttons pinned at bottom
            navigationButtons
                .background(Color(.systemBackground))
        }
        .onAppear {
            if let location = spotData.location {
                let region = MKCoordinateRegion(
                    center: location,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                mapRegion = region
                mapCameraPosition = .region(region)
            }
        }
    }
    
    private var mapSection: some View {
        MapReader { mapProxy in
            Map(position: $mapCameraPosition) {
                if let parkingLocation = spotData.parkingLocation {
                    Annotation("Parking", coordinate: parkingLocation) {
                        Image(systemName: "car.fill")
                            .padding(8)
                            .background(Circle().fill(Color.blue))
                            .foregroundColor(.white)
                    }
                }
                
                if let spotLocation = spotData.location {
                    Annotation("Photo Spot", coordinate: spotLocation) {
                        Image(systemName: "camera.fill")
                            .padding(8)
                            .background(Circle().fill(Color.green))
                            .foregroundColor(.white)
                    }
                }
                
                if routePoints.count > 1 {
                    MapPolyline(coordinates: routePoints)
                        .stroke(.blue, lineWidth: 3)
                }
                
                ForEach(Array(routePoints.enumerated()), id: \.offset) { index, point in
                    Annotation("", coordinate: point) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapScaleView()
            }
            .onMapCameraChange { context in
                mapRegion = context.region
            }
            .onTapGesture { location in
                if let coordinate = mapProxy.convert(location, from: .local) {
                    handleMapTap(coordinate: coordinate)
                }
            }
            .frame(height: 300)
            .cornerRadius(10)
            .overlay(alignment: .top) {
                mapOverlayTop
            }
            .overlay(alignment: .bottom) {
                mapOverlayBottom
            }
        }
    }
    
    private var mapOverlayTop: some View {
        Group {
            if isSettingParking || isDrawingRoute {
                HStack {
                    Image(systemName: isSettingParking ? "car.fill" : "pencil.tip")
                    Text(isSettingParking ? "Tap on the map to set parking location" : "Tap on the map to add route points")
                }
                .font(.caption)
                .padding(8)
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(8)
            }
        }
    }
    
    private var mapOverlayBottom: some View {
        HStack {
            Button(action: {
                isDrawingRoute.toggle()
                isSettingParking = false
                if !isDrawingRoute && routePoints.count > 0 {
                    spotData.routePolyline = encodeRoute(routePoints)
                }
            }) {
                Label(isDrawingRoute ? "Done Drawing" : "Draw Route", systemImage: "pencil.tip")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isDrawingRoute ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            Button(action: {
                isSettingParking.toggle()
                isDrawingRoute = false
            }) {
                Label(isSettingParking ? "Cancel" : "Set Parking", systemImage: "car.fill")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isSettingParking ? Color.gray : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            if routePoints.count > 0 || spotData.parkingLocation != nil {
                Button(action: {
                    routePoints.removeAll()
                    spotData.parkingLocation = nil
                    spotData.routePolyline = nil
                }) {
                    Label("Clear", systemImage: "trash")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
    }
    
    private var routeInfoDisplay: some View {
        Group {
            if routePoints.count > 0 || spotData.parkingLocation != nil {
                VStack(alignment: .leading, spacing: 8) {
                    if spotData.parkingLocation != nil {
                        HStack {
                            Image(systemName: "car.fill")
                                .foregroundColor(.blue)
                            Text("Parking location set")
                                .font(.caption)
                        }
                    }
                    
                    if routePoints.count > 1 {
                        HStack {
                            Image(systemName: "figure.walk")
                                .foregroundColor(.green)
                            Text("Route: \(routePoints.count) points")
                                .font(.caption)
                            Spacer()
                            Text("~\(estimatedDistance()) m")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }
    }
    
    private var accessDetailsSection: some View {
        VStack(spacing: 12) {
            HazardSelector(hazards: $spotData.hazards)
            FeeSelector(fees: $spotData.fees)
            
            VStack(alignment: .leading) {
                Text("Additional Notes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Any tips for accessing this spot?", text: $spotData.notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
        }
        .padding()
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
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    private func estimatedDistance() -> Int {
        guard routePoints.count > 1 else { return 0 }
        
        var totalDistance: CLLocationDistance = 0
        for i in 1..<routePoints.count {
            let start = CLLocation(latitude: routePoints[i-1].latitude, longitude: routePoints[i-1].longitude)
            let end = CLLocation(latitude: routePoints[i].latitude, longitude: routePoints[i].longitude)
            totalDistance += start.distance(from: end)
        }
        
        return Int(totalDistance)
    }
    
    private func encodeRoute(_ points: [CLLocationCoordinate2D]) -> String {
        return points.map { "\($0.latitude),\($0.longitude)" }.joined(separator: ";")
    }
    
    private func handleMapTap(coordinate: CLLocationCoordinate2D) {
        if isSettingParking {
            spotData.parkingLocation = coordinate
            isSettingParking = false
        } else if isDrawingRoute {
            routePoints.append(coordinate)
        }
    }
}

struct HazardSelector: View {
    @Binding var hazards: [String]
    
    let commonHazards = ["Steep cliffs", "Slippery when wet", "No cell service", "Wildlife"]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Hazards")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                ForEach(commonHazards, id: \.self) { hazard in
                    Button(action: {
                        if hazards.contains(hazard) {
                            hazards.removeAll { $0 == hazard }
                        } else {
                            hazards.append(hazard)
                        }
                    }) {
                        Text(hazard)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(hazards.contains(hazard) ? Color.orange : Color(.systemGray5))
                            .foregroundColor(hazards.contains(hazard) ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
        }
    }
}

struct FeeSelector: View {
    @Binding var fees: [String]
    
    let commonFees = ["Parking fee", "Park entrance", "Permit required"]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Fees")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                ForEach(commonFees, id: \.self) { fee in
                    Button(action: {
                        if fees.contains(fee) {
                            fees.removeAll { $0 == fee }
                        } else {
                            fees.append(fee)
                        }
                    }) {
                        Text(fee)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(fees.contains(fee) ? Color.yellow : Color(.systemGray5))
                            .foregroundColor(fees.contains(fee) ? .black : .primary)
                            .cornerRadius(6)
                    }
                }
            }
        }
    }
}