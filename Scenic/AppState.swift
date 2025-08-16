import Foundation
import SwiftUI
import Combine

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
        loadMockData()
    }
    
    private func loadMockData() {
        currentUser = User(
            id: UUID(),
            handle: "photographer",
            name: "Demo User",
            email: "demo@scenic.app",
            avatarUrl: nil,
            bio: "Landscape photography enthusiast",
            reputationScore: 100,
            homeRegion: "San Francisco Bay Area",
            roles: [.user],
            badges: [],
            followersCount: 42,
            followingCount: 28,
            spotsCount: 15,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        isAuthenticated = true
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