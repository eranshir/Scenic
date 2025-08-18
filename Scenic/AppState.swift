import Foundation
import SwiftUI
import Combine
import Supabase

class AppState: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isGuestMode = false
    @Published var authProvider: AuthProvider = .none
    @Published var spots: [Spot] = []
    @Published var plans: [Plan] = []
    @Published var journalEntries: [Media] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var selectedSpot: Spot?
    @Published var selectedPlan: Plan?
    
    @Published var filterSettings = FilterSettings()
    @Published var mapRegion: MapRegion?
    
    enum AuthProvider {
        case none
        case apple
        case google
        case guest
    }
    
    init() {
        // Check for existing session on app launch
        checkExistingSession()
    }
    
    private func checkExistingSession() {
        Task {
            // Check if user has an existing Supabase session
            if let session = try? await supabase.auth.session {
                await handleExistingSession(session)
            } else {
                // No existing session, show auth screen
                await MainActor.run {
                    isAuthenticated = false
                }
            }
        }
    }
    
    @MainActor
    func handleExistingSession(_ session: Session) {
        isAuthenticated = true
        
        let user = session.user
        
        // Debug logging
        print("🔍 AppState handleExistingSession:")
        print("  - User ID: \(user.id)")
        print("  - Email: \(user.email ?? "nil")")
        print("  - User Metadata Keys: \(user.userMetadata.keys)")
        print("  - App Metadata Keys: \(user.appMetadata.keys)")
        
        // Determine auth provider and guest status
        if user.email == nil || user.appMetadata["provider"]?.value as? String == "anonymous" {
            isGuestMode = true
            authProvider = .guest
        } else if let provider = user.appMetadata["provider"]?.value as? String {
            switch provider {
            case "apple":
                authProvider = .apple
            case "google":
                authProvider = .google
            default:
                authProvider = .none
            }
        }
        
        // Extract metadata values properly
        let handle = (user.userMetadata["handle"]?.value as? String) ?? 
                    (user.userMetadata["preferred_username"]?.value as? String) ??
                    user.email?.components(separatedBy: "@").first ?? 
                    (isGuestMode ? "guest" : "user")
        
        // For Apple Sign-In, try to get the name from user metadata
        var fullName = (user.userMetadata["full_name"]?.value as? String) ?? ""
        if fullName.isEmpty {
            fullName = (user.userMetadata["name"]?.value as? String) ?? ""
        }
        if fullName.isEmpty {
            fullName = (user.userMetadata["display_name"]?.value as? String) ?? ""
        }
        
        print("  - Extracted handle: \(handle)")
        print("  - Extracted fullName: \(fullName)")
        
        if fullName.isEmpty && !isGuestMode {
            fullName = user.email?.components(separatedBy: "@").first?.capitalized ?? "User"
        }
        if isGuestMode {
            fullName = "Guest User"
        }
        
        let avatarUrl = user.userMetadata["avatar_url"]?.value as? String
        let bio = (user.userMetadata["bio"]?.value as? String) ?? (isGuestMode ? "Exploring in guest mode" : "")
        
        currentUser = User(
            id: UUID(uuidString: user.id.uuidString) ?? UUID(),
            handle: handle,
            name: fullName,
            email: user.email ?? "",
            avatarUrl: avatarUrl,
            bio: bio,
            reputationScore: isGuestMode ? 0 : 0,
            homeRegion: "",
            roles: isGuestMode ? [.guest] : [.user],
            badges: [],
            followersCount: 0,
            followingCount: 0,
            spotsCount: 0,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt
        )
        
        // Start automatic sync down after successful authentication
        startAutomaticSyncDown()
    }
    
    @MainActor
    private func startAutomaticSyncDown() {
        print("🔄 Starting automatic sync down on app launch...")
        
        // Clear last sync time for testing
        UserDefaults.standard.removeObject(forKey: "lastSyncDownTime")
        
        Task {
            await SyncService.shared.syncRemoteSpotsToLocal()
            print("✅ Automatic sync down completed")
        }
    }
    
    func signOut() {
        Task {
            try? await supabase.auth.signOut()
            await MainActor.run {
                isAuthenticated = false
                isGuestMode = false
                authProvider = .none
                currentUser = nil
                spots = []
                plans = []
                journalEntries = []
            }
        }
    }
}

struct FilterSettings {
    var searchQuery = ""
    var selectedDifficulty: Spot.Difficulty?
    var selectedTags: Set<String> = []
    var showGoldenHour = false
    var showBlueHour = false
    var maxDistance: Double?
}

struct MapRegion {
    var latitude: Double
    var longitude: Double
    var latitudeDelta: Double
    var longitudeDelta: Double
}