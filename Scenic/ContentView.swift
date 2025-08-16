import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: AppTab = .home
    
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