import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: AppTab = .home
    @State private var showTestView = false // Set to true to test connections
    
    var body: some View {
        if showTestView {
            TestConnectionView()
        } else if appState.isCheckingAuthStatus {
            // Show loading screen while checking authentication
            VStack {
                Spacer()
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                Text("Loading...")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .background(Color(.systemBackground))
        } else if !appState.isAuthenticated {
            AuthenticationView()
        } else {
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