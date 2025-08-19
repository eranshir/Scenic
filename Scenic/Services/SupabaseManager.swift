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
    
    // MARK: - Plans Management
    
    func fetchPlans() async throws -> [SupabasePlan] {
        guard let userId = currentUser?.id else { throw SupabaseError.notAuthenticated }
        
        let plans: [SupabasePlan] = try await client
            .from("plans")
            .select("""
                id, title, description, created_by, created_at, updated_at,
                is_public, original_plan_id, estimated_duration, start_date, end_date,
                plan_items (
                    id, type, order_index, scheduled_date, scheduled_start_time, 
                    scheduled_end_time, timing_preference, spot_id, poi_data, notes, created_at
                )
            """)
            .or("created_by.eq.\(userId.uuidString),is_public.eq.true")
            .order("updated_at", ascending: false)
            .execute()
            .value
        
        return plans
    }
    
    func createPlan(_ plan: Plan) async throws -> SupabasePlan {
        guard let userId = currentUser?.id else { throw SupabaseError.notAuthenticated }
        
        let planCreate = PlanCreate(
            title: plan.title,
            description: plan.description,
            createdBy: userId,
            isPublic: plan.isPublic,
            originalPlanId: plan.originalPlanId,
            estimatedDuration: plan.estimatedDuration,
            startDate: plan.startDate,
            endDate: plan.endDate
        )
        
        let createdPlan: SupabasePlan = try await client
            .from("plans")
            .insert(planCreate)
            .select()
            .single()
            .execute()
            .value
        
        // Create plan items if any
        for item in plan.items {
            try await createPlanItem(item, planId: createdPlan.id)
        }
        
        return createdPlan
    }
    
    func updatePlan(_ plan: Plan) async throws -> SupabasePlan {
        guard let userId = currentUser?.id else { throw SupabaseError.notAuthenticated }
        
        let planUpdate = PlanUpdate(
            title: plan.title,
            description: plan.description,
            isPublic: plan.isPublic,
            originalPlanId: plan.originalPlanId,
            estimatedDuration: plan.estimatedDuration,
            startDate: plan.startDate,
            endDate: plan.endDate,
            updatedAt: Date()
        )
        
        let updatedPlan: SupabasePlan = try await client
            .from("plans")
            .update(planUpdate)
            .eq("id", value: plan.id.uuidString)
            .eq("created_by", value: userId.uuidString)
            .select()
            .single()
            .execute()
            .value
        
        // Update plan items (delete all and recreate for simplicity)
        try await deletePlanItems(planId: plan.id)
        for item in plan.items {
            try await createPlanItem(item, planId: plan.id)
        }
        
        return updatedPlan
    }
    
    func deletePlan(planId: UUID) async throws {
        guard let userId = currentUser?.id else { throw SupabaseError.notAuthenticated }
        
        try await client
            .from("plans")
            .delete()
            .eq("id", value: planId.uuidString)
            .eq("created_by", value: userId.uuidString)
            .execute()
    }
    
    func forkPlan(originalPlanId: UUID, newTitle: String) async throws -> SupabasePlan {
        guard let userId = currentUser?.id else { throw SupabaseError.notAuthenticated }
        
        // Fetch the original plan
        let originalPlan: SupabasePlan = try await client
            .from("plans")
            .select("""
                id, title, description, estimated_duration, start_date, end_date,
                plan_items (
                    type, order_index, timing_preference, spot_id, poi_data, notes
                )
            """)
            .eq("id", value: originalPlanId.uuidString)
            .eq("is_public", value: true)
            .single()
            .execute()
            .value
        
        // Create new plan
        let planCreate = PlanCreate(
            title: newTitle,
            description: originalPlan.description,
            createdBy: userId,
            isPublic: false,
            originalPlanId: originalPlanId,
            estimatedDuration: originalPlan.estimatedDuration,
            startDate: nil,
            endDate: nil
        )
        
        let newPlan: SupabasePlan = try await client
            .from("plans")
            .insert(planCreate)
            .select()
            .single()
            .execute()
            .value
        
        // Copy plan items
        for item in originalPlan.planItems ?? [] {
            let poiDataEncoded = item.poiData?.mapValues { AnyCodable($0) }
            
            let itemCreate = PlanItemCreate(
                planId: newPlan.id,
                type: item.type,
                orderIndex: item.orderIndex,
                scheduledDate: nil,
                scheduledStartTime: nil,
                scheduledEndTime: nil,
                timingPreference: item.timingPreference,
                spotId: item.spotId,
                poiData: poiDataEncoded,
                notes: item.notes
            )
            
            try await client
                .from("plan_items")
                .insert(itemCreate)
                .execute()
        }
        
        return newPlan
    }
    
    // MARK: - Plan Items Management
    
    private func createPlanItem(_ item: PlanItem, planId: UUID) async throws {
        var poiDataEncoded: [String: AnyCodable]?
        if let poiData = item.poiData {
            let poiDict = try poiData.toDictionary()
            poiDataEncoded = poiDict.mapValues { AnyCodable($0) }
        }
        
        let itemCreate = PlanItemCreate(
            planId: planId,
            type: item.type.rawValue,
            orderIndex: item.orderIndex,
            scheduledDate: item.scheduledDate,
            scheduledStartTime: item.scheduledStartTime,
            scheduledEndTime: item.scheduledEndTime,
            timingPreference: item.timingPreference?.rawValue,
            spotId: item.spotId,
            poiData: poiDataEncoded,
            notes: item.notes
        )
        
        try await client
            .from("plan_items")
            .insert(itemCreate)
            .execute()
    }
    
    private func deletePlanItems(planId: UUID) async throws {
        try await client
            .from("plan_items")
            .delete()
            .eq("plan_id", value: planId.uuidString)
            .execute()
    }
    
    func fetchPublicPlans(limit: Int = 20, offset: Int = 0) async throws -> [SupabasePlan] {
        let plans: [SupabasePlan] = try await client
            .from("plans")
            .select("""
                id, title, description, created_by, created_at, updated_at,
                is_public, original_plan_id, estimated_duration,
                plan_items (
                    id, type, order_index, timing_preference, spot_id, poi_data
                )
            """)
            .eq("is_public", value: true)
            .order("updated_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        
        return plans
    }
    
    // MARK: - Real-time Subscriptions
    
    func subscribeToSpots() async {
        let channel = client.channel("public:spots")
        
        // Using the new Realtime V2 API with correct syntax
        let _ = await channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "spots"
        ) { action in
            print("New spot created: \(action)")
            // Handle new spot
        }
        
        // Subscribe to the channel
        do {
            try await channel.subscribe()
        } catch {
            print("Error subscribing to spots channel: \(error)")
        }
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

struct SupabasePlan: Codable {
    let id: UUID
    let title: String
    let description: String?
    let createdBy: UUID
    let createdAt: Date
    let updatedAt: Date
    let isPublic: Bool
    let originalPlanId: UUID?
    let estimatedDuration: Int?
    let startDate: Date?
    let endDate: Date?
    let planItems: [SupabasePlanItem]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isPublic = "is_public"
        case originalPlanId = "original_plan_id"
        case estimatedDuration = "estimated_duration"
        case startDate = "start_date"
        case endDate = "end_date"
        case planItems = "plan_items"
    }
}

// MARK: - Plan Create/Update Structs

struct PlanCreate: Codable {
    let title: String
    let description: String?
    let createdBy: UUID
    let isPublic: Bool
    let originalPlanId: UUID?
    let estimatedDuration: Int?
    let startDate: Date?
    let endDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case createdBy = "created_by"
        case isPublic = "is_public"
        case originalPlanId = "original_plan_id"
        case estimatedDuration = "estimated_duration"
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

struct PlanUpdate: Codable {
    let title: String
    let description: String?
    let isPublic: Bool
    let originalPlanId: UUID?
    let estimatedDuration: Int?
    let startDate: Date?
    let endDate: Date?
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case isPublic = "is_public"
        case originalPlanId = "original_plan_id"
        case estimatedDuration = "estimated_duration"
        case startDate = "start_date"
        case endDate = "end_date"
        case updatedAt = "updated_at"
    }
}

struct PlanItemCreate: Codable {
    let planId: UUID
    let type: String
    let orderIndex: Int
    let scheduledDate: Date?
    let scheduledStartTime: Date?
    let scheduledEndTime: Date?
    let timingPreference: String?
    let spotId: UUID?
    let poiData: [String: AnyCodable]?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case type
        case orderIndex = "order_index"
        case scheduledDate = "scheduled_date"
        case scheduledStartTime = "scheduled_start_time"
        case scheduledEndTime = "scheduled_end_time"
        case timingPreference = "timing_preference"
        case spotId = "spot_id"
        case poiData = "poi_data"
        case notes
    }
}

// Helper to make Any values encodable
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else if let arrayValue = value as? [Any] {
            try container.encode(arrayValue.map { AnyCodable($0) })
        } else if let dictValue = value as? [String: Any] {
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        } else {
            try container.encodeNil()
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
}

struct SupabasePlanItem: Codable {
    let id: UUID
    let planId: UUID
    let type: String
    let orderIndex: Int
    let scheduledDate: Date?
    let scheduledStartTime: Date?
    let scheduledEndTime: Date?
    let timingPreference: String?
    let spotId: UUID?
    let poiData: [String: Any]?
    let notes: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case type
        case orderIndex = "order_index"
        case scheduledDate = "scheduled_date"
        case scheduledStartTime = "scheduled_start_time"
        case scheduledEndTime = "scheduled_end_time"
        case timingPreference = "timing_preference"
        case spotId = "spot_id"
        case poiData = "poi_data"
        case notes
        case createdAt = "created_at"
    }
    
    // Custom decoder for JSONB poi_data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        planId = try container.decode(UUID.self, forKey: .planId)
        type = try container.decode(String.self, forKey: .type)
        orderIndex = try container.decode(Int.self, forKey: .orderIndex)
        scheduledDate = try container.decodeIfPresent(Date.self, forKey: .scheduledDate)
        scheduledStartTime = try container.decodeIfPresent(Date.self, forKey: .scheduledStartTime)
        scheduledEndTime = try container.decodeIfPresent(Date.self, forKey: .scheduledEndTime)
        timingPreference = try container.decodeIfPresent(String.self, forKey: .timingPreference)
        spotId = try container.decodeIfPresent(UUID.self, forKey: .spotId)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        
        // Decode JSONB poi_data
        if let poiDataValue = try? container.decodeIfPresent(Data.self, forKey: .poiData) {
            poiData = try? JSONSerialization.jsonObject(with: poiDataValue) as? [String: Any]
        } else {
            poiData = nil
        }
    }
    
    // Custom encoder for JSONB poi_data
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(planId, forKey: .planId)
        try container.encode(type, forKey: .type)
        try container.encode(orderIndex, forKey: .orderIndex)
        try container.encodeIfPresent(scheduledDate, forKey: .scheduledDate)
        try container.encodeIfPresent(scheduledStartTime, forKey: .scheduledStartTime)
        try container.encodeIfPresent(scheduledEndTime, forKey: .scheduledEndTime)
        try container.encodeIfPresent(timingPreference, forKey: .timingPreference)
        try container.encodeIfPresent(spotId, forKey: .spotId)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(createdAt, forKey: .createdAt)
        
        // Encode JSONB poi_data
        if let poiData = poiData {
            let jsonData = try JSONSerialization.data(withJSONObject: poiData)
            try container.encode(jsonData, forKey: .poiData)
        }
    }
}