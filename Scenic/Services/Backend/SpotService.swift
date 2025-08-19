import Foundation
import Supabase
import CoreLocation

/// Service for managing spots in the backend
@MainActor
class SpotService: ObservableObject {
    static let shared = SpotService()
    
    @Published var spots: [SpotModel] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private init() {}
    
    // MARK: - Spot CRUD Operations
    
    /// Create a new spot
    func createSpot(
        title: String,
        location: CLLocationCoordinate2D,
        description: String? = nil,
        headingDegrees: Int? = nil,
        elevationMeters: Int? = nil,
        subjectTags: [String] = [],
        difficulty: Int = 3,
        privacy: String = "public"
    ) async throws -> SpotModel {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw SpotError.notAuthenticated
        }
        
        struct SpotInsert: Encodable {
            let title: String
            let description: String?
            let location: String  // PostGIS POINT format
            let latitude: Double
            let longitude: Double
            let heading_degrees: Int?
            let elevation_meters: Int?
            let subject_tags: [String]
            let difficulty: Int
            let created_by: String
            let privacy: String
        }
        
        // Create PostGIS POINT string
        let pointString = "POINT(\(location.longitude) \(location.latitude))"
        
        let spotCreate = SpotInsert(
            title: title,
            description: description,
            location: pointString,
            latitude: location.latitude,
            longitude: location.longitude,
            heading_degrees: headingDegrees,
            elevation_meters: elevationMeters,
            subject_tags: subjectTags,
            difficulty: difficulty,
            created_by: userId.uuidString,
            privacy: privacy
        )
        
        let response: SpotModel = try await supabase
            .from("spots")
            .insert(spotCreate)
            .select()
            .single()
            .execute()
            .value
        
        return response
    }
    
    /// Fetch spots with optional filters
    func fetchSpots(
        nearLocation: CLLocationCoordinate2D? = nil,
        radiusKm: Double = 50,
        tags: [String]? = nil,
        difficulty: Int? = nil,
        limit: Int = 50,
        updatedSince: Date? = nil
    ) async throws -> [SpotModel] {
        // Build base query
        var baseQuery = supabase
            .from("spots")
            .select("*")
            .eq("status", value: "active")
        
        // Add timestamp filter for incremental sync
        if let updatedSince = updatedSince {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let timestampString = formatter.string(from: updatedSince)
            baseQuery = baseQuery.gte("updated_at", value: timestampString)
        }
        
        // Build full query based on filters
        let query: PostgrestTransformBuilder
        if let difficulty = difficulty {
            query = baseQuery
                .eq("difficulty", value: difficulty)
                .order("updated_at", ascending: false)
                .limit(limit)
        } else {
            query = baseQuery
                .order("updated_at", ascending: false)
                .limit(limit)
        }
        
        let spots: [SpotModel] = try await query.execute().value
        
        // Filter by tags client-side if provided
        var filteredSpots = spots
        if let tags = tags, !tags.isEmpty {
            filteredSpots = spots.filter { spot in
                // Check if spot has any of the requested tags
                return spot.subjectTags.contains { tag in
                    tags.contains(tag)
                }
            }
        }
        
        // If location provided, filter by distance client-side
        // (PostGIS distance queries would be more efficient but require raw SQL)
        if let nearLocation = nearLocation {
            return filteredSpots.filter { spot in
                let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
                let userLocation = CLLocation(latitude: nearLocation.latitude, longitude: nearLocation.longitude)
                let distanceKm = spotLocation.distance(from: userLocation) / 1000
                return distanceKm <= radiusKm
            }
        }
        
        return filteredSpots
    }
    
    /// Get a single spot by ID
    func getSpot(id: UUID) async throws -> SpotModel {
        let spot: SpotModel = try await supabase
            .from("spots")
            .select("*")
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        
        return spot
    }
    
    /// Update a spot
    func updateSpot(id: UUID, updates: SpotUpdate) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw SpotError.notAuthenticated
        }
        
        // Verify ownership
        let spot: SpotModel = try await supabase
            .from("spots")
            .select("created_by")
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        
        guard spot.createdBy == userId else {
            throw SpotError.unauthorized
        }
        
        try await supabase
            .from("spots")
            .update(updates)
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    /// Delete a spot (soft delete - sets status to 'deleted')
    func deleteSpot(id: UUID) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw SpotError.notAuthenticated
        }
        
        // Verify ownership
        let spot: SpotModel = try await supabase
            .from("spots")
            .select("created_by")
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        
        guard spot.createdBy == userId else {
            throw SpotError.unauthorized
        }
        
        try await supabase
            .from("spots")
            .update(["status": "deleted"])
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    // MARK: - Spot Interactions
    
    /// Vote on a spot
    func voteSpot(id: UUID, voteType: String) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw SpotError.notAuthenticated
        }
        
        // Check if already voted
        let existingVote: [VoteModel]? = try? await supabase
            .from("votes")
            .select()
            .eq("spot_id", value: id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        if let existing = existingVote, !existing.isEmpty {
            // Update existing vote
            try await supabase
                .from("votes")
                .update(["vote_type": voteType])
                .eq("id", value: existing[0].id.uuidString)
                .execute()
        } else {
            // Create new vote
            let vote = VoteCreate(
                spotId: id,
                userId: userId,
                voteType: voteType
            )
            
            try await supabase
                .from("votes")
                .insert(vote)
                .execute()
        }
    }
    
    /// Save a spot to user's collection
    func saveSpot(id: UUID) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw SpotError.notAuthenticated
        }
        
        let save = SaveCreate(
            spotId: id,
            userId: userId
        )
        
        try await supabase
            .from("saves")
            .insert(save)
            .execute()
    }
    
    /// Add a comment to a spot
    func addComment(spotId: UUID, text: String) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw SpotError.notAuthenticated
        }
        
        let comment = CommentCreate(
            spotId: spotId,
            userId: userId,
            commentText: text
        )
        
        try await supabase
            .from("comments")
            .insert(comment)
            .execute()
    }
    
    // MARK: - Search and Discovery
    
    /// Search spots by text query
    func searchSpots(query: String) async throws -> [SpotModel] {
        let spots: [SpotModel] = try await supabase
            .from("spots")
            .select("*")
            .textSearch("title", query: query)
            .eq("status", value: "active")
            .limit(50)
            .execute()
            .value
        
        return spots
    }
    
    /// Get trending spots based on recent activity
    func getTrendingSpots(limit: Int = 20) async throws -> [SpotModel] {
        // This would ideally use a database function to calculate trending score
        // For now, we'll fetch spots with most recent votes
        let spots: [SpotModel] = try await supabase
            .from("spots")
            .select("*")
            .eq("status", value: "active")
            .order("vote_count", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        return spots
    }
}

// MARK: - Data Models

struct SpotModel: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String?
    let latitude: Double
    let longitude: Double
    let headingDegrees: Int?
    let elevationMeters: Int?
    let subjectTags: [String]
    let difficulty: Int
    let createdBy: UUID
    let privacy: String
    let license: String
    let status: String
    let voteCount: Int
    let createdAt: Date
    let updatedAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case id, title, description, latitude, longitude
        case headingDegrees = "heading_degrees"
        case elevationMeters = "elevation_meters"
        case subjectTags = "subject_tags"
        case difficulty
        case createdBy = "created_by"
        case privacy, license, status
        case voteCount = "vote_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}


struct SpotUpdate: Codable {
    let title: String?
    let description: String?
    let subjectTags: [String]?
    let difficulty: Int?
    
    private enum CodingKeys: String, CodingKey {
        case title, description
        case subjectTags = "subject_tags"
        case difficulty
    }
}


struct SunSnapshotModel: Codable {
    let id: UUID
    let spotId: UUID
    let date: Date
    let sunrise: String
    let sunset: String
    let goldenHourMorning: String
    let goldenHourEvening: String
    let blueHourMorning: String
    let blueHourEvening: String
    
    private enum CodingKeys: String, CodingKey {
        case id
        case spotId = "spot_id"
        case date, sunrise, sunset
        case goldenHourMorning = "golden_hour_morning"
        case goldenHourEvening = "golden_hour_evening"
        case blueHourMorning = "blue_hour_morning"
        case blueHourEvening = "blue_hour_evening"
    }
}

struct WeatherSnapshotModel: Codable {
    let id: UUID
    let spotId: UUID
    let capturedAt: Date
    let temperature: Double
    let conditions: String
    let visibility: Double?
    let cloudCover: Int?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case spotId = "spot_id"
        case capturedAt = "captured_at"
        case temperature, conditions, visibility
        case cloudCover = "cloud_cover"
    }
}

struct AccessInfoModel: Codable {
    let id: UUID
    let spotId: UUID
    let parkingLocation: [Double]?
    let hikingDistance: Double?
    let hikingDuration: Int?
    let hikingDifficulty: String?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case spotId = "spot_id"
        case parkingLocation = "parking_location"
        case hikingDistance = "hiking_distance"
        case hikingDuration = "hiking_duration"
        case hikingDifficulty = "hiking_difficulty"
    }
}

struct SpotTipModel: Codable {
    let id: UUID
    let spotId: UUID
    let userId: UUID
    let tipType: String
    let tipText: String
    
    private enum CodingKeys: String, CodingKey {
        case id
        case spotId = "spot_id"
        case userId = "user_id"
        case tipType = "tip_type"
        case tipText = "tip_text"
    }
}

struct CommentModel: Codable {
    let id: UUID
    let spotId: UUID
    let userId: UUID
    let commentText: String
    let createdAt: Date
    var profile: ProfileModel?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case spotId = "spot_id"
        case userId = "user_id"
        case commentText = "comment_text"
        case createdAt = "created_at"
        case profile = "profiles"
    }
}

struct ProfileModel: Codable {
    let username: String?
    let displayName: String?
    let avatarUrl: String?
    
    private enum CodingKeys: String, CodingKey {
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
    }
}

struct VoteModel: Codable, Identifiable {
    let id: UUID
    let spotId: UUID
    let userId: UUID
    let voteType: String
}

struct VoteCreate: Codable {
    let spotId: UUID
    let userId: UUID
    let voteType: String
    
    private enum CodingKeys: String, CodingKey {
        case spotId = "spot_id"
        case userId = "user_id"
        case voteType = "vote_type"
    }
}

struct SaveCreate: Codable {
    let spotId: UUID
    let userId: UUID
    
    private enum CodingKeys: String, CodingKey {
        case spotId = "spot_id"
        case userId = "user_id"
    }
}

struct CommentCreate: Codable {
    let spotId: UUID
    let userId: UUID
    let commentText: String
    
    private enum CodingKeys: String, CodingKey {
        case spotId = "spot_id"
        case userId = "user_id"
        case commentText = "comment_text"
    }
}

// MARK: - Errors

enum SpotError: LocalizedError {
    case notAuthenticated
    case unauthorized
    case notFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to perform this action"
        case .unauthorized:
            return "You don't have permission to modify this spot"
        case .notFound:
            return "Spot not found"
        case .invalidData:
            return "Invalid data provided"
        }
    }
}
