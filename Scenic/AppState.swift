import Foundation
import SwiftUI
import Combine
import Supabase

class AppState: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var spots: [Spot] = []
    @Published var plans: [Plan] = []
    @Published var journalEntries: [Media] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var selectedSpot: Spot?
    @Published var selectedPlan: Plan?
    
    @Published var filterSettings = FilterSettings()
    @Published var mapRegion: MapRegion?
    
    init() {
        // Check for existing session on app launch
        checkExistingSession()
    }
    
    private func checkExistingSession() {
        Task {
            // Check if user has an existing Supabase session
            if let session = try? await supabase.auth.session {
                await MainActor.run {
                    handleExistingSession(session)
                }
            } else {
                // No existing session, show auth screen
                await MainActor.run {
                    isAuthenticated = false
                }
            }
        }
    }
    
    func handleExistingSession(_ session: Session) {
        isAuthenticated = true
        
        let user = session.user
        
        // Extract metadata values properly
        let handle = (user.userMetadata["handle"]?.value as? String) ?? user.email?.components(separatedBy: "@").first ?? "user"
        let fullName = (user.userMetadata["full_name"]?.value as? String) ?? "User"
        let avatarUrl = user.userMetadata["avatar_url"]?.value as? String
        let bio = (user.userMetadata["bio"]?.value as? String) ?? ""
        
        currentUser = User(
            id: UUID(uuidString: user.id.uuidString) ?? UUID(),
            handle: handle,
            name: fullName,
            email: user.email ?? "",
            avatarUrl: avatarUrl,
            bio: bio,
            reputationScore: 0,
            homeRegion: "",
            roles: [.user],
            badges: [],
            followersCount: 0,
            followingCount: 0,
            spotsCount: 0,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt
        )
    }
    
    func signOut() {
        Task {
            try? await supabase.auth.signOut()
            await MainActor.run {
                isAuthenticated = false
                currentUser = nil
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