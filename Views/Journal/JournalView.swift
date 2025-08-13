import SwiftUI
import MapKit

struct JournalView: View {
    @EnvironmentObject var appState: AppState
    @State private var viewMode: ViewMode = .timeline
    @State private var showingExportOptions = false
    
    enum ViewMode {
        case timeline, map, stats
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("View Mode", selection: $viewMode) {
                    Text("Timeline").tag(ViewMode.timeline)
                    Text("Map").tag(ViewMode.map)
                    Text("Stats").tag(ViewMode.stats)
                }
                .pickerStyle(.segmented)
                .padding()
                
                Group {
                    switch viewMode {
                    case .timeline:
                        JournalTimelineView()
                    case .map:
                        JournalMapView()
                    case .stats:
                        JournalStatsView()
                    }
                }
            }
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingExportOptions = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingExportOptions) {
                ExportOptionsView()
            }
        }
    }
}

struct JournalTimelineView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(mockJournalEntries) { entry in
                    JournalEntryCard(entry: entry)
                }
            }
            .padding()
        }
    }
}

struct JournalEntryCard: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(entry.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(entry.spotName)
                        .font(.headline)
                }
                
                Spacer()
                
                if entry.isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            ZStack {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(height: 200)
                    .cornerRadius(10)
                
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            if let notes = entry.notes {
                Text(notes)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            HStack(spacing: 16) {
                Label("\(entry.photoCount) photos", systemImage: "photo")
                    .font(.caption)
                
                if let camera = entry.camera {
                    Label(camera, systemImage: "camera")
                        .font(.caption)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "square.and.pencil")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct JournalMapView: View {
    var body: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        ))) {
            ForEach(mockJournalEntries) { entry in
                Marker(entry.spotName, coordinate: entry.location)
                    .tint(.purple)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
    }
}

struct JournalStatsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                StatCard(title: "Total Spots", value: "42", icon: "mappin.circle.fill", color: .green)
                StatCard(title: "Photos Taken", value: "1,284", icon: "photo.circle.fill", color: .blue)
                StatCard(title: "Countries", value: "5", icon: "globe", color: .orange)
                StatCard(title: "Total Distance", value: "234 km", icon: "figure.walk", color: .purple)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top Cameras")
                        .font(.headline)
                    
                    CameraStatRow(camera: "Canon EOS R5", count: 523)
                    CameraStatRow(camera: "iPhone 15 Pro", count: 412)
                    CameraStatRow(camera: "DJI Mavic 3", count: 89)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title2)
                    .bold()
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CameraStatRow: View {
    let camera: String
    let count: Int
    
    var body: some View {
        HStack {
            Text(camera)
                .font(.footnote)
            Spacer()
            Text("\(count) photos")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ExportOptionsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Button(action: {}) {
                    Label("Export as CSV", systemImage: "doc.text")
                }
                
                Button(action: {}) {
                    Label("Export as GPX", systemImage: "location")
                }
                
                Button(action: {}) {
                    Label("Export Photos", systemImage: "photo.on.rectangle.angled")
                }
                
                Button(action: {}) {
                    Label("Create PDF Report", systemImage: "doc.richtext")
                }
            }
            .navigationTitle("Export Journal")
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
}

struct JournalEntry: Identifiable {
    let id = UUID()
    let date: Date
    let spotName: String
    let location: CLLocationCoordinate2D
    let photoCount: Int
    let camera: String?
    let notes: String?
    let isPrivate: Bool
}

let mockJournalEntries = [
    JournalEntry(
        date: Date().addingTimeInterval(-86400),
        spotName: "Golden Gate Vista",
        location: CLLocationCoordinate2D(latitude: 37.8024, longitude: -122.4058),
        photoCount: 24,
        camera: "Canon EOS R5",
        notes: "Perfect golden hour conditions. The fog rolled in just as expected.",
        isPrivate: false
    ),
    JournalEntry(
        date: Date().addingTimeInterval(-86400 * 3),
        spotName: "Baker Beach",
        location: CLLocationCoordinate2D(latitude: 37.7936, longitude: -122.4836),
        photoCount: 18,
        camera: "iPhone 15 Pro",
        notes: "Quick sunset shoot. Great reflections on the wet sand.",
        isPrivate: true
    )
]

#Preview {
    JournalView()
        .environmentObject(AppState())
}