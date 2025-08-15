import SwiftUI
import MapKit

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var spotDataService: SpotDataService
    @State private var viewMode: ViewMode = .map
    @State private var showFilters = false
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var selectedSpotId: UUID?
    @State private var showSearchResults = false
    @State private var searchResults: [Spot] = []
    
    enum ViewMode {
        case map, list
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewMode == .map {
                    MapView(selectedSpotId: $selectedSpotId, mapCameraPosition: $mapCameraPosition)
                } else {
                    SpotListView()
                }
                
                VStack {
                    searchBarWithResults
                    Spacer()
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showFilters.toggle() }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Picker("View Mode", selection: $viewMode) {
                        Image(systemName: "map").tag(ViewMode.map)
                        Image(systemName: "list.bullet").tag(ViewMode.list)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                }
            }
            .sheet(isPresented: $showFilters) {
                FilterView()
            }
            .onTapGesture {
                // Hide search results and keyboard when tapping outside
                if showSearchResults {
                    hideSearchResults()
                    hideKeyboard()
                }
            }
        }
    }
    
    private var searchBarWithResults: some View {
        VStack(spacing: 0) {
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search region or spot...", text: $appState.filterSettings.searchQuery)
                        .textFieldStyle(.plain)
                        .onChange(of: appState.filterSettings.searchQuery) { oldValue, newValue in
                            performSearch(query: newValue)
                        }
                        .onSubmit {
                            handleSearchSubmit()
                        }
                        .onTapGesture {
                            if !appState.filterSettings.searchQuery.isEmpty {
                                showSearchResults = true
                            }
                        }
                    if !appState.filterSettings.searchQuery.isEmpty {
                        Button(action: {
                            clearSearch()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                if appState.filterSettings.showGoldenHour || appState.filterSettings.showBlueHour || !appState.filterSettings.selectedTags.isEmpty {
                    Text("\(activeFilterCount) active")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Search results dropdown
            if showSearchResults {
                VStack(spacing: 0) {
                    if searchResults.isEmpty && !appState.filterSettings.searchQuery.isEmpty {
                        // No results found
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("No spots found")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Try a different search term or browse the map")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else if !searchResults.isEmpty {
                        // Show search results
                        ForEach(searchResults.prefix(5), id: \.id) { spot in
                            SearchResultRow(spot: spot) {
                                selectSearchResult(spot)
                            }
                        }
                        
                        if searchResults.count > 5 {
                            HStack {
                                Text("\(searchResults.count - 5) more results...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(radius: 5)
                .padding(.horizontal)
                .padding(.top, 2)
            }
        }
    }
    
    private var activeFilterCount: Int {
        var count = 0
        if appState.filterSettings.showGoldenHour { count += 1 }
        if appState.filterSettings.showBlueHour { count += 1 }
        count += appState.filterSettings.selectedTags.count
        return count
    }
    
    // MARK: - Search Functions
    
    private func performSearch(query: String) {
        // Debounce search to avoid excessive processing
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            showSearchResults = false
            return
        }
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 1 else {
            searchResults = []
            showSearchResults = false
            return
        }
        
        // Perform local search through available spots
        let allSpots = spotDataService.spots.isEmpty ? mockSpots : spotDataService.spots
        
        searchResults = allSpots.compactMap { spot in
            // Ensure spot has valid data
            guard !spot.title.isEmpty else { return nil }
            return spot
        }
        .filter { spot in
            // Search in title, subject tags, and region
            let titleMatch = spot.title.localizedCaseInsensitiveContains(trimmedQuery)
            let tagsMatch = spot.subjectTags.contains { $0.localizedCaseInsensitiveContains(trimmedQuery) }
            
            // Search in location-based info if available
            let locationMatch = searchInLocationInfo(spot: spot, query: trimmedQuery)
            
            return titleMatch || tagsMatch || locationMatch
        }
        .sorted { spot1, spot2 in
            // Sort by relevance: title matches first, then others
            let spot1TitleMatch = spot1.title.localizedCaseInsensitiveContains(trimmedQuery)
            let spot2TitleMatch = spot2.title.localizedCaseInsensitiveContains(trimmedQuery)
            
            if spot1TitleMatch && !spot2TitleMatch {
                return true
            } else if !spot1TitleMatch && spot2TitleMatch {
                return false
            } else {
                // If both or neither match title, sort alphabetically
                return spot1.title.localizedCompare(spot2.title) == .orderedAscending
            }
        }
        
        // Always show results container when there's a query, even if empty
        showSearchResults = true
    }
    
    private func searchInLocationInfo(spot: Spot, query: String) -> Bool {
        // This could be expanded to include reverse geocoding results
        // For now, we'll do basic coordinate matching if someone types coordinates
        if query.contains(",") {
            let components = query.components(separatedBy: ",")
            if components.count == 2,
               let lat = Double(components[0].trimmingCharacters(in: .whitespaces)),
               let lng = Double(components[1].trimmingCharacters(in: .whitespaces)),
               lat.isFinite && lng.isFinite, // Check for valid numbers
               abs(lat) <= 90 && abs(lng) <= 180 { // Check for valid coordinate ranges
                
                let queryLocation = CLLocation(latitude: lat, longitude: lng)
                let spotLocation = CLLocation(latitude: spot.location.latitude, longitude: spot.location.longitude)
                let distance = queryLocation.distance(from: spotLocation)
                
                // Consider it a match if within 5km
                return distance < 5000
            }
        }
        return false
    }
    
    private func handleSearchSubmit() {
        // Handle when user presses Enter key
        guard !appState.filterSettings.searchQuery.isEmpty else { return }
        
        if searchResults.isEmpty {
            // No results found, show feedback
            showSearchResults = true
            // Optionally, dismiss keyboard
            hideKeyboard()
        } else {
            // Jump to first search result
            selectSearchResult(searchResults[0])
        }
    }
    
    private func selectSearchResult(_ spot: Spot) {
        // Set the search query to the selected spot's title
        appState.filterSettings.searchQuery = spot.title
        hideSearchResults()
        
        // Jump map to spot location
        jumpToSpot(spot)
        
        // Select the spot on the map
        selectedSpotId = spot.id
    }
    
    private func jumpToSpot(_ spot: Spot) {
        // Validate coordinates to prevent NaN errors
        guard spot.location.latitude.isFinite && spot.location.longitude.isFinite,
              abs(spot.location.latitude) <= 90,
              abs(spot.location.longitude) <= 180 else {
            print("⚠️ Invalid coordinates for spot: \(spot.title)")
            return
        }
        
        let region = MKCoordinateRegion(
            center: spot.location,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        withAnimation(.easeInOut(duration: 1.0)) {
            mapCameraPosition = .region(region)
        }
    }
    
    private func clearSearch() {
        appState.filterSettings.searchQuery = ""
        searchResults = []
        hideSearchResults()
    }
    
    private func hideSearchResults() {
        showSearchResults = false
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Search Result Row Component

struct SearchResultRow: View {
    let spot: Spot
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(spot.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Label(spot.difficulty.displayName, systemImage: "figure.hiking")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !spot.subjectTags.isEmpty {
                            Text(spot.subjectTags.prefix(2).joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    // Show additional info like elevation or access info
                    if let elevation = spot.elevationMeters {
                        Text("\(elevation)m elevation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "location.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text("\(spot.location.latitude, specifier: "%.3f"), \(spot.location.longitude, specifier: "%.3f")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}