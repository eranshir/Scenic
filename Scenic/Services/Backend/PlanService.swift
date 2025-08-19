import Foundation
import Supabase
import CoreLocation

/// Service for managing user plans and itineraries
@MainActor
class PlanService: ObservableObject {
    static let shared = PlanService()
    
    @Published var userPlans: [PlanModel] = []
    @Published var currentPlan: PlanModel?
    @Published var isLoading = false
    @Published var error: Error?
    
    private init() {}
    
    // MARK: - Plan CRUD Operations
    
    /// Create a new plan
    func createPlan(
        title: String,
        description: String? = nil,
        plannedDate: Date? = nil,
        isPublic: Bool = false
    ) async throws -> PlanModel {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw PlanError.notAuthenticated
        }
        
        let planCreate = SimplePlanCreate(
            userId: userId,
            title: title,
            description: description,
            plannedDate: plannedDate,
            isPublic: isPublic
        )
        
        let plan: PlanModel = try await supabase
            .from("plans")
            .insert(planCreate)
            .select("""
                *,
                plan_spots(*, spots(*))
            """)
            .single()
            .execute()
            .value
        
        // Add to local array
        userPlans.append(plan)
        
        return plan
    }
    
    /// Get user's plans
    func fetchUserPlans() async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw PlanError.notAuthenticated
        }
        
        isLoading = true
        
        let plans: [PlanModel] = try await supabase
            .from("plans")
            .select("""
                *,
                plan_spots(
                    *,
                    spots(
                        *,
                        media(*),
                        sun_snapshots(*),
                        weather_snapshots(*)
                    )
                )
            """)
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        userPlans = plans
        isLoading = false
    }
    
    /// Get a specific plan by ID
    func getPlan(id: UUID) async throws -> PlanModel {
        let plan: PlanModel = try await supabase
            .from("plans")
            .select("""
                *,
                plan_spots(
                    *,
                    spots(
                        *,
                        media(*),
                        sun_snapshots(*),
                        weather_snapshots(*),
                        access_info(*)
                    )
                ),
                profiles!plans_user_id_fkey(username, display_name, avatar_url)
            """)
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        
        currentPlan = plan
        return plan
    }
    
    /// Update a plan
    func updatePlan(
        id: UUID,
        title: String? = nil,
        description: String? = nil,
        plannedDate: Date? = nil,
        isPublic: Bool? = nil
    ) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw PlanError.notAuthenticated
        }
        
        // Verify ownership
        let plan: PlanModel = try await supabase
            .from("plans")
            .select("user_id")
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        
        guard plan.userId == userId else {
            throw PlanError.unauthorized
        }
        
        // Create update object with only non-nil values
        let updates = SimplePlanUpdate(
            title: title,
            description: description,
            plannedDate: plannedDate,
            isPublic: isPublic
        )
        
        try await supabase
            .from("plans")
            .update(updates)
            .eq("id", value: id.uuidString)
            .execute()
        
        // Refresh the plan
        _ = try await getPlan(id: id)
    }
    
    /// Delete a plan
    func deletePlan(id: UUID) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw PlanError.notAuthenticated
        }
        
        // Verify ownership
        let plan: PlanModel = try await supabase
            .from("plans")
            .select("user_id")
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        
        guard plan.userId == userId else {
            throw PlanError.unauthorized
        }
        
        // Delete plan (cascade will delete plan_spots)
        try await supabase
            .from("plans")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
        
        // Remove from local array
        userPlans.removeAll { $0.id == id }
    }
    
    // MARK: - Plan Spots Management
    
    /// Add a spot to a plan
    func addSpotToPlan(
        planId: UUID,
        spotId: UUID,
        orderIndex: Int? = nil,
        plannedArrival: Date? = nil,
        notes: String? = nil
    ) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw PlanError.notAuthenticated
        }
        
        // Verify plan ownership
        let plan: PlanModel = try await supabase
            .from("plans")
            .select("user_id")
            .eq("id", value: planId.uuidString)
            .single()
            .execute()
            .value
        
        guard plan.userId == userId else {
            throw PlanError.unauthorized
        }
        
        // Get current max order index if not provided
        let finalOrderIndex: Int
        if let orderIndex = orderIndex {
            finalOrderIndex = orderIndex
        } else {
            let planSpots: [PlanSpotModel] = try await supabase
                .from("plan_spots")
                .select("order_index")
                .eq("plan_id", value: planId.uuidString)
                .order("order_index", ascending: false)
                .limit(1)
                .execute()
                .value
            
            finalOrderIndex = (planSpots.first?.orderIndex ?? -1) + 1
        }
        
        let planSpot = PlanSpotCreate(
            planId: planId,
            spotId: spotId,
            orderIndex: finalOrderIndex,
            plannedArrival: plannedArrival,
            notes: notes
        )
        
        try await supabase
            .from("plan_spots")
            .insert(planSpot)
            .execute()
        
        // Refresh the plan
        _ = try await getPlan(id: planId)
    }
    
    /// Remove a spot from a plan
    func removeSpotFromPlan(planId: UUID, spotId: UUID) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw PlanError.notAuthenticated
        }
        
        // Verify plan ownership
        let plan: PlanModel = try await supabase
            .from("plans")
            .select("user_id")
            .eq("id", value: planId.uuidString)
            .single()
            .execute()
            .value
        
        guard plan.userId == userId else {
            throw PlanError.unauthorized
        }
        
        try await supabase
            .from("plan_spots")
            .delete()
            .eq("plan_id", value: planId.uuidString)
            .eq("spot_id", value: spotId.uuidString)
            .execute()
        
        // Refresh the plan
        _ = try await getPlan(id: planId)
    }
    
    /// Reorder spots in a plan
    func reorderSpotsInPlan(planId: UUID, spotOrders: [(spotId: UUID, orderIndex: Int)]) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw PlanError.notAuthenticated
        }
        
        // Verify plan ownership
        let plan: PlanModel = try await supabase
            .from("plans")
            .select("user_id")
            .eq("id", value: planId.uuidString)
            .single()
            .execute()
            .value
        
        guard plan.userId == userId else {
            throw PlanError.unauthorized
        }
        
        // Update each spot's order
        for (spotId, orderIndex) in spotOrders {
            try await supabase
                .from("plan_spots")
                .update(["order_index": orderIndex])
                .eq("plan_id", value: planId.uuidString)
                .eq("spot_id", value: spotId.uuidString)
                .execute()
        }
        
        // Refresh the plan
        _ = try await getPlan(id: planId)
    }
    
    // MARK: - Plan Discovery
    
    /// Get public plans
    func getPublicPlans(limit: Int = 20) async throws -> [PlanModel] {
        let plans: [PlanModel] = try await supabase
            .from("plans")
            .select("""
                *,
                plan_spots(
                    *,
                    spots(*, media(*))
                ),
                profiles!plans_user_id_fkey(username, display_name, avatar_url)
            """)
            .eq("is_public", value: true)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        return plans
    }
    
    /// Clone a public plan
    func clonePlan(planId: UUID) async throws -> PlanModel {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw PlanError.notAuthenticated
        }
        
        // Get the original plan
        let originalPlan: PlanModel = try await supabase
            .from("plans")
            .select("""
                *,
                plan_spots(*)
            """)
            .eq("id", value: planId.uuidString)
            .single()
            .execute()
            .value
        
        // Create new plan
        let newPlan = SimplePlanCreate(
            userId: userId,
            title: "\(originalPlan.title) (Copy)",
            description: originalPlan.description,
            plannedDate: nil,
            isPublic: false
        )
        
        let createdPlan: PlanModel = try await supabase
            .from("plans")
            .insert(newPlan)
            .select()
            .single()
            .execute()
            .value
        
        // Copy spots
        if let planSpots = originalPlan.planSpots {
            for spot in planSpots {
                let planSpotCopy = PlanSpotCreate(
                    planId: createdPlan.id,
                    spotId: spot.spotId,
                    orderIndex: spot.orderIndex,
                    plannedArrival: nil,
                    notes: spot.notes
                )
                
                try await supabase
                    .from("plan_spots")
                    .insert(planSpotCopy)
                    .execute()
            }
        }
        
        // Fetch complete plan with spots
        return try await getPlan(id: createdPlan.id)
    }
}

// MARK: - Data Models

struct PlanModel: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let title: String
    let description: String?
    let plannedDate: Date?
    let isPublic: Bool
    let createdAt: Date
    let updatedAt: Date
    
    var planSpots: [PlanSpotModel]?
    var profile: ProfileModel?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title, description
        case plannedDate = "planned_date"
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case planSpots = "plan_spots"
        case profile = "profiles"
    }
}

struct SimplePlanCreate: Codable {
    let userId: UUID
    let title: String
    let description: String?
    let plannedDate: Date?
    let isPublic: Bool
    
    private enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case title, description
        case plannedDate = "planned_date"
        case isPublic = "is_public"
    }
}

struct SimplePlanUpdate: Codable {
    let title: String?
    let description: String?
    let plannedDate: Date?
    let isPublic: Bool?
    
    
    private enum CodingKeys: String, CodingKey {
        case title, description
        case plannedDate = "planned_date"
        case isPublic = "is_public"
    }
}

struct PlanSpotModel: Codable, Identifiable {
    let id: UUID
    let planId: UUID
    let spotId: UUID
    let orderIndex: Int
    let plannedArrival: Date?
    let notes: String?
    let addedAt: Date
    
    var spot: SpotModel?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case spotId = "spot_id"
        case orderIndex = "order_index"
        case plannedArrival = "planned_arrival"
        case notes
        case addedAt = "added_at"
        case spot = "spots"
    }
}

struct PlanSpotCreate: Codable {
    let planId: UUID
    let spotId: UUID
    let orderIndex: Int
    let plannedArrival: Date?
    let notes: String?
    
    private enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case spotId = "spot_id"
        case orderIndex = "order_index"
        case plannedArrival = "planned_arrival"
        case notes
    }
}

// MARK: - Errors

enum PlanError: LocalizedError {
    case notAuthenticated
    case unauthorized
    case notFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to manage plans"
        case .unauthorized:
            return "You don't have permission to modify this plan"
        case .notFound:
            return "Plan not found"
        case .invalidData:
            return "Invalid plan data"
        }
    }
}