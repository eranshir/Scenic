import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: AppTab = .home
    @State private var addSpotViewId = UUID() // Key to force view recreation
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(AppTab.home)
            
            PlansView()
                .tabItem {
                    Label("Plans", systemImage: "calendar")
                }
                .tag(AppTab.plans)
            
            AddSpotView()
                .id(addSpotViewId) // Use ID to force view recreation
                .tabItem {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .tag(AppTab.add)
            
            JournalView()
                .tabItem {
                    Label("Journal", systemImage: "book.fill")
                }
                .tag(AppTab.journal)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(AppTab.profile)
        }
        .tint(.green)
        .onChange(of: selectedTab) { oldTab, newTab in
            // Reset AddSpotView when leaving the add tab
            if oldTab == .add && newTab != .add {
                // Generate new ID to force AddSpotView recreation when returning
                addSpotViewId = UUID()
            }
        }
    }
}

enum AppTab {
    case home
    case plans
    case add
    case journal
    case profile
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}