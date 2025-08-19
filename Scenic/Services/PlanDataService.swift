import Foundation
import CoreData
import SwiftUI

@MainActor
class PlanDataService: ObservableObject {
    private let persistenceController: PersistenceController
    private var viewContext: NSManagedObjectContext {
        persistenceController.container.viewContext
    }
    
    @Published var plans: [Plan] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    init(persistenceController: PersistenceController = PersistenceController.shared) {
        self.persistenceController = persistenceController
        loadPlans()
        
        // Listen for sync completion notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlansDidSync),
            name: .plansDidSync,
            object: nil
        )
    }
    
    @objc private func handlePlansDidSync() {
        print("📨 Received plansDidSync notification, reloading plans...")
        loadPlans()
    }
    
    // MARK: - Plan Operations
    
    func loadPlans() {
        isLoading = true
        error = nil
        
        do {
            let request: NSFetchRequest<CDPlan> = CDPlan.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \CDPlan.updatedAt, ascending: false)]
            
            let cdPlans = try viewContext.fetch(request)
            plans = cdPlans.map { $0.toPlan() }
            
            print("✅ Loaded \(plans.count) plans from Core Data")
        } catch {
            self.error = error
            print("❌ Failed to load plans: \(error)")
        }
        
        isLoading = false
    }
    
    func createPlan(title: String, description: String? = nil, createdBy: UUID? = nil) -> Plan {
        let plan = Plan(
            id: UUID(),
            title: title,
            description: description,
            createdBy: createdBy ?? UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            isPublic: false,
            originalPlanId: nil,
            estimatedDuration: nil,
            startDate: nil,
            endDate: nil,
            items: []
        )
        
        savePlan(plan)
        return plan
    }
    
    func savePlan(_ plan: Plan) {
        do {
            // Check if plan already exists
            let request: NSFetchRequest<CDPlan> = CDPlan.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", plan.id as CVarArg)
            
            let existingPlans = try viewContext.fetch(request)
            
            let cdPlan: CDPlan
            if let existing = existingPlans.first {
                // Update existing plan
                cdPlan = existing
                cdPlan.updateFromPlan(plan)
            } else {
                // Create new plan
                cdPlan = CDPlan.fromPlan(plan, in: viewContext)
            }
            
            // Handle plan items
            // First remove all existing items
            if let existingItems = cdPlan.items?.allObjects as? [CDPlanItem] {
                for item in existingItems {
                    viewContext.delete(item)
                }
            }
            
            // Add current items
            for item in plan.items {
                let cdPlanItem = CDPlanItem.fromPlanItem(item, plan: cdPlan, in: viewContext)
                
                // Link to spot if this is a spot item
                if item.type == .spot, let spotId = item.spotId {
                    let spotRequest: NSFetchRequest<CDSpot> = CDSpot.fetchRequest()
                    spotRequest.predicate = NSPredicate(format: "id == %@", spotId as CVarArg)
                    if let cdSpot = try? viewContext.fetch(spotRequest).first {
                        cdPlanItem.spot = cdSpot
                    }
                }
            }
            
            try viewContext.save()
            loadPlans() // Refresh the list
            
            print("✅ Saved plan: \(plan.title)")
        } catch {
            self.error = error
            print("❌ Failed to save plan: \(error)")
        }
    }
    
    func deletePlan(_ plan: Plan) {
        do {
            let request: NSFetchRequest<CDPlan> = CDPlan.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", plan.id as CVarArg)
            
            let cdPlans = try viewContext.fetch(request)
            for cdPlan in cdPlans {
                viewContext.delete(cdPlan)
            }
            
            try viewContext.save()
            loadPlans() // Refresh the list
            
            print("✅ Deleted plan: \(plan.title)")
        } catch {
            self.error = error
            print("❌ Failed to delete plan: \(error)")
        }
    }
    
    func addSpotToPlan(spot: Spot, plan: Plan, timingPreference: TimingPreference? = nil) -> Plan {
        let newItem = PlanItem(
            id: UUID(),
            planId: plan.id,
            type: .spot,
            orderIndex: plan.items.count,
            scheduledDate: nil,
            scheduledStartTime: nil,
            scheduledEndTime: nil,
            timingPreference: timingPreference,
            spotId: spot.id,
            spot: spot,
            poiData: nil,
            notes: nil,
            createdAt: Date()
        )
        
        var updatedPlan = plan
        updatedPlan.items.append(newItem)
        updatedPlan.updatedAt = Date()
        
        savePlan(updatedPlan)
        return updatedPlan
    }
    
    func addPOIToPlan(poi: POIData, type: PlanItemType, plan: Plan, timingPreference: TimingPreference? = nil) -> Plan {
        let newItem = PlanItem(
            id: UUID(),
            planId: plan.id,
            type: type,
            orderIndex: plan.items.count,
            scheduledDate: nil,
            scheduledStartTime: nil,
            scheduledEndTime: nil,
            timingPreference: timingPreference,
            spotId: nil,
            spot: nil,
            poiData: poi,
            notes: nil,
            createdAt: Date()
        )
        
        var updatedPlan = plan
        updatedPlan.items.append(newItem)
        updatedPlan.updatedAt = Date()
        
        savePlan(updatedPlan)
        return updatedPlan
    }
    
    func removePlanItem(itemId: UUID, from plan: Plan) -> Plan {
        var updatedPlan = plan
        updatedPlan.items.removeAll { $0.id == itemId }
        
        // Reorder remaining items
        for (index, var item) in updatedPlan.items.enumerated() {
            item.orderIndex = index
            updatedPlan.items[index] = item
        }
        
        updatedPlan.updatedAt = Date()
        savePlan(updatedPlan)
        return updatedPlan
    }
    
    func reorderPlanItems(plan: Plan, from source: IndexSet, to destination: Int) -> Plan {
        var updatedPlan = plan
        var items = updatedPlan.sortedItems
        items.move(fromOffsets: source, toOffset: destination)
        
        // Update order indices
        for (index, var item) in items.enumerated() {
            item.orderIndex = index
            items[index] = item
        }
        
        updatedPlan.items = items
        updatedPlan.updatedAt = Date()
        savePlan(updatedPlan)
        return updatedPlan
    }
    
    // MARK: - Plan Search and Filtering
    
    func getPublicPlans() -> [Plan] {
        return plans.filter { $0.isPublic }
    }
    
    func getPrivatePlans() -> [Plan] {
        return plans.filter { !$0.isPublic }
    }
    
    func searchPlans(query: String) -> [Plan] {
        guard !query.isEmpty else { return plans }
        
        return plans.filter { plan in
            plan.title.localizedCaseInsensitiveContains(query) ||
            (plan.description?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let plansDidSync = Notification.Name("plansDidSync")
}