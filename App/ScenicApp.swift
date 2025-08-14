import SwiftUI

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
                .preferredColorScheme(.dark)
        }
    }
}