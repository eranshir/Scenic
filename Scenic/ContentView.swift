import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: AppTab = .home
    @State private var showTestView = false // Set to true to test connections
    @State private var showSplashScreen = true
    
    var body: some View {
        if showTestView {
            TestConnectionView()
        } else if appState.isCheckingAuthStatus || showSplashScreen {
            // Show splash screen while checking authentication and for 1 second after
            SplashScreenView()
                .onAppear {
                    // If auth check is complete, start the 1-second timer
                    if !appState.isCheckingAuthStatus {
                        startSplashTimer()
                    }
                }
                .onChange(of: appState.isCheckingAuthStatus) { _, isChecking in
                    // When auth check completes, start the 1-second timer
                    if !isChecking {
                        startSplashTimer()
                    }
                }
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
    
    private func startSplashTimer() {
        // Show splash screen for 1 second after auth check completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showSplashScreen = false
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