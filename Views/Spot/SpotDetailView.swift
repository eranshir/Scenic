import SwiftUI
import MapKit

struct SpotDetailView: View {
    let spot: Spot
    @EnvironmentObject var appState: AppState
    @State private var showingShareSheet = false
    @State private var showingAddToPlan = false
    @State private var selectedTab = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                mediaCarousel
                
                VStack(spacing: 16) {
                    headerSection
                    sunWeatherSection
                    locationSection
                    exifSection
                    accessSection
                    commentsSection
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: { showingAddToPlan = true }) {
                        Image(systemName: "calendar.badge.plus")
                    }
                    
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddToPlan) {
            AddToPlanView(spot: spot)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [spot.title, "Check out this photo spot on Scenic!"])
        }
    }
    
    private var mediaCarousel: some View {
        TabView(selection: $selectedTab) {
            ForEach(0..<3, id: \.self) { index in
                ZStack {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color.green.opacity(0.3), Color.blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.5))
                }
                .tag(index)
            }
        }
        .frame(height: 300)
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(spot.title)
                .font(.largeTitle)
                .bold()
            
            HStack {
                ForEach(spot.subjectTags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                }
            }
            
            HStack {
                Button(action: {}) {
                    HStack {
                        Image(systemName: "arrow.up")
                        Text("\(spot.voteCount)")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: {}) {
                    HStack {
                        Image(systemName: "bookmark")
                        Text("Save")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text("@photographer")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Explorer")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var sunWeatherSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Light & Weather", icon: "sun.max.fill")
            
            SunTimesWidget()
            
            WeatherWidget()
        }
    }
    
    private var locationSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Location", icon: "location.fill")
            
            Map(initialPosition: .region(MKCoordinateRegion(
                center: spot.location,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))) {
                Marker(spot.title, coordinate: spot.location)
                    .tint(.green)
            }
            .frame(height: 200)
            .cornerRadius(12)
            .allowsHitTesting(false)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("GPS Coordinates")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(spot.location.latitude, specifier: "%.6f"), \(spot.location.longitude, specifier: "%.6f")")
                        .font(.footnote)
                        .fontDesign(.monospaced)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "doc.on.doc")
                }
                
                Button(action: {}) {
                    Image(systemName: "location.north.line.fill")
                        .rotationEffect(.degrees(Double(spot.headingDegrees ?? 0)))
                }
            }
            
            if let heading = spot.headingDegrees {
                HStack {
                    Image(systemName: "safari")
                    Text("Heading: \(heading)°")
                        .font(.caption)
                    Spacer()
                }
            }
            
            if let elevation = spot.elevationMeters {
                HStack {
                    Image(systemName: "arrow.up.and.down")
                    Text("Elevation: \(elevation)m")
                        .font(.caption)
                    Spacer()
                }
            }
        }
    }
    
    private var exifSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Camera Settings", icon: "camera.fill")
            
            ExifDataView()
        }
    }
    
    private var accessSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Access & Route", icon: "figure.hiking")
            
            AccessInfoView(difficulty: spot.difficulty)
        }
    }
    
    private var commentsSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Comments", icon: "message.fill")
            
            if spot.comments.isEmpty {
                Text("No comments yet. Be the first!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(spot.comments) { comment in
                    CommentRow(comment: comment)
                }
            }
            
            Button(action: {}) {
                HStack {
                    Image(systemName: "plus.message.fill")
                    Text("Add Comment")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.green)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        SpotDetailView(spot: mockSpots[0])
            .environmentObject(AppState())
    }
}