import SwiftUI
import Supabase

@main
struct ScenicApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var appState = AppState()
    @StateObject private var spotDataService = SpotDataService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appState)
                .environmentObject(spotDataService)
                .onOpenURL { url in
                    // Handle OAuth callback
                    print("Received URL: \(url)")
                    
                    // Clear the pending auth flow
                    UserDefaults.standard.removeObject(forKey: "pendingAuthFlow")
                    
                    Task {
                        do {
                            try await supabase.auth.session(from: url)
                            
                            // Check if we now have a session
                            if let session = try? await supabase.auth.session {
                                await MainActor.run {
                                    appState.handleExistingSession(session)
                                }
                            }
                        } catch {
                            print("Error handling OAuth callback: \(error)")
                        }
                    }
                }
        }
    }
}

// Supabase client configuration
let supabase = SupabaseClient(
    supabaseURL: URL(string: Config.supabaseURL)!,
    supabaseKey: Config.supabaseAnonKey
)