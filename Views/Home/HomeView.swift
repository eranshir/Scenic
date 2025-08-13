import SwiftUI
import MapKit

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var viewMode: ViewMode = .map
    @State private var showFilters = false
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var selectedSpotId: UUID?
    
    enum ViewMode {
        case map, list
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewMode == .map {
                    MapView(selectedSpotId: $selectedSpotId)
                } else {
                    SpotListView()
                }
                
                VStack {
                    searchBar
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
        }
    }
    
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search region or spot...", text: $appState.filterSettings.searchQuery)
                    .textFieldStyle(.plain)
                if !appState.filterSettings.searchQuery.isEmpty {
                    Button(action: { appState.filterSettings.searchQuery = "" }) {
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
    }
    
    private var activeFilterCount: Int {
        var count = 0
        if appState.filterSettings.showGoldenHour { count += 1 }
        if appState.filterSettings.showBlueHour { count += 1 }
        count += appState.filterSettings.selectedTags.count
        return count
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}