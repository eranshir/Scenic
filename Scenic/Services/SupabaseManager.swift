import Foundation
import Auth
import Functions
import PostgREST
import Realtime
import Storage
import Supabase  // This is the main package that should also be available

// Type alias to avoid conflicts with Scenic's User model
typealias SupabaseUser = Auth.User

/// Manages all Supabase interactions
@MainActor
class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    @Published var currentUser: SupabaseUser?
    @Published var currentProfile: Profile?
    @Published var isAuthenticated = false
    
    private init() {
        // Initialize Supabase client
        let url = URL(string: "https://joamynsevhhhiwynidxp.supabase.co")!
        let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpvYW15bnNldmhoaGl3eW5pZHhwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUzNTA0MDMsImV4cCI6MjA3MDkyNjQwM30.AmXZkxfYLWmwoV3b7uYX01WrvezArmt5gr6468-0YR4"
        
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey
        )
        
        // Check for existing session
        Task {
            await checkSession()
        }
    }
    
    // MARK: - Authentication
    
    func checkSession() async {
        do {
            let session = try await client.auth.session
            currentUser = session.user
            isAuthenticated = true
            await fetchProfile()
        } catch {
            currentUser = nil
            isAuthenticated = false
        }
    }
    
    func signUp(email: String, password: String, username: String) async throws {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["username": .string(username)]
        )
        
        currentUser = response.user
        isAuthenticated = true
        await fetchProfile()
    }
    
    func signIn(email: String, password: String) async throws {
        let response = try await client.auth.signIn(
            email: email,
            password: password
        )
        
        currentUser = response.user
        isAuthenticated = true
        await fetchProfile()
    }
    
    func signInWithApple(idToken: String, nonce: String) async throws {
        let response = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        
        currentUser = response.user
        isAuthenticated = true
        await fetchProfile()
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
        currentProfile = nil
        isAuthenticated = false
    }
    
    // MARK: - Profile Management
    
    func fetchProfile() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            let profile: Profile = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            currentProfile = profile
        } catch {
            print("Error fetching profile: \(error)")
        }
    }
    
    func updateProfile(_ updates: ProfileUpdate) async throws {
        guard let userId = currentUser?.id else { throw SupabaseError.notAuthenticated }
        
        try await client
            .from("profiles")
            .update(updates)
            .eq("id", value: userId.uuidString)
            .execute()
        
        await fetchProfile()
    }
    
    // MARK: - Spots Operations
    
    func createSpot(_ spot: SpotCreate) async throws -> SupabaseSpot {
        guard let userId = currentUser?.id else { throw SupabaseError.notAuthenticated }
        
        var spotData = spot
        spotData.createdBy = userId
        
        let response: SupabaseSpot = try await client
            .from("spots")
            .insert(spotData)
            .select()
            .single()
            .execute()
            .value
        
        return response
    }
    
    func fetchSpots(limit: Int = 50) async throws -> [SupabaseSpot] {
        let spots: [SupabaseSpot] = try await client
            .from("spots")
            .select("""
                *,
                profiles!created_by(username, avatar_url),
                media(cloudinary_secure_url, thumbnail_url)
            """)
            .eq("privacy", value: "public")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        return spots
    }
    
    func fetchNearbySpots(latitude: Double, longitude: Double, radiusMeters: Int = 50000) async throws -> [SupabaseSpot] {
        let spots: [SupabaseSpot] = try await client
            .rpc("nearby_spots", params: [
                "lat": latitude,
                "lng": longitude,
                "radius_meters": Double(radiusMeters)
            ])
            .execute()
            .value
        
        return spots
    }
    
    // MARK: - Media Operations
    
    func saveMediaReference(_ media: MediaCreate) async throws -> SupabaseMedia {
        let response: SupabaseMedia = try await client
            .from("media")
            .insert(media)
            .select()
            .single()
            .execute()
            .value
        
        return response
    }
    
    // MARK: - Social Features
    
    func voteForSpot(spotId: UUID) async throws {
        guard let userId = currentUser?.id else { throw SupabaseError.notAuthenticated }
        
        try await client
            .from("votes")
            .insert([
                "user_id": userId.uuidString,
                "spot_id": spotId.uuidString
            ])
            .execute()
    }
    
    func removeVote(spotId: UUID) async throws {
        guard let userId = currentUser?.id else { throw SupabaseError.notAuthenticated }
        
        try await client
            .from("votes")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("spot_id", value: spotId.uuidString)
            .execute()
    }
    
    func addComment(spotId: UUID, body: String) async throws -> SupabaseComment {
        guard let userId = currentUser?.id else { throw SupabaseError.notAuthenticated }
        
        let comment: SupabaseComment = try await client
            .from("comments")
            .insert([
                "spot_id": spotId.uuidString,
                "user_id": userId.uuidString,
                "body": body
            ])
            .select()
            .single()
            .execute()
            .value
        
        return comment
    }
    
    // MARK: - Real-time Subscriptions
    
    func subscribeToSpots() async {
        let channel = client.channel("public:spots")
        
        // Using the new Realtime V2 API with correct syntax
        await channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "spots"
        ) { action in
            print("New spot created: \(action)")
            // Handle new spot
        }
        
        // Subscribe to the channel
        await channel.subscribe()
    }
    
    // MARK: - Test Connection
    
    func testConnection() async throws {
        // Test by fetching profiles table structure
        let _ = try await client
            .from("profiles")
            .select("*")
            .limit(1)
            .execute()
    }
}

// MARK: - Error Types

enum SupabaseError: LocalizedError {
    case notAuthenticated
    case invalidData
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to perform this action"
        case .invalidData:
            return "Invalid data provided"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - Data Models

struct Profile: Codable {
    let id: UUID
    let username: String
    let displayName: String?
    let bio: String?
    let avatarUrl: String?
    let explorerScore: Int
    let explorerLevel: String
    let spotsCreated: Int
    let photosShared: Int
}

struct ProfileUpdate: Codable {
    var displayName: String?
    var bio: String?
    var avatarUrl: String?
}

struct SpotCreate: Codable {
    let title: String
    let description: String?
    let latitude: Double
    let longitude: Double
    let difficulty: Int
    let subjectTags: [String]
    var createdBy: UUID?
}

struct MediaCreate: Codable {
    let spotId: UUID
    let userId: UUID
    let cloudinaryPublicId: String
    let cloudinaryUrl: String
    let cloudinarySecureUrl: String
    let type: String
    let width: Int?
    let height: Int?
}

// Renamed to avoid conflicts with existing models
struct SupabaseSpot: Codable {
    let id: UUID
    let title: String
    let description: String?
    let latitude: Double
    let longitude: Double
    let difficulty: Int
    let subjectTags: [String]?
    let createdBy: UUID
    let createdAt: Date
    let updatedAt: Date
}

struct SupabaseMedia: Codable {
    let id: UUID
    let spotId: UUID
    let userId: UUID
    let cloudinaryPublicId: String
    let cloudinaryUrl: String
    let cloudinarySecureUrl: String
    let type: String
    let width: Int?
    let height: Int?
    let captureTimeUtc: String?
    let attributionText: String?
    let originalSource: String?
    let originalPhotoId: String?
    let licenseType: String?
    let gpsLatitude: Double?
    let gpsLongitude: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case spotId = "spot_id"
        case userId = "user_id"
        case cloudinaryPublicId = "cloudinary_public_id"
        case cloudinaryUrl = "cloudinary_url"
        case cloudinarySecureUrl = "cloudinary_secure_url"
        case type
        case width
        case height
        case captureTimeUtc = "capture_time_utc"
        case attributionText = "attribution_text"
        case originalSource = "original_source"
        case originalPhotoId = "original_photo_id"
        case licenseType = "license_type"
        case gpsLatitude = "gps_latitude"
        case gpsLongitude = "gps_longitude"
    }
}

struct SupabaseComment: Codable {
    let id: UUID
    let spotId: UUID
    let userId: UUID
    let body: String
    let createdAt: Date
}