import SwiftUI
import CoreLocation

struct PlansView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingCreatePlan = false
    @State private var searchText = ""
    @State private var selectedFilter: PlanFilter = .all
    
    enum PlanFilter: String, CaseIterable {
        case all = "All"
        case myPlans = "My Plans"
        case `public` = "Public"
        case scheduled = "Scheduled"
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if filteredPlans.isEmpty {
                    if appState.plans.isEmpty {
                        emptyState
                    } else {
                        noResultsView
                    }
                } else {
                    plansList
                }
            }
            .searchable(text: $searchText, prompt: "Search plans...")
            .navigationTitle("Plans")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        ForEach(PlanFilter.allCases, id: \.self) { filter in
                            Button(action: { selectedFilter = filter }) {
                                HStack {
                                    Text(filter.rawValue)
                                    if selectedFilter == filter {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedFilter.rawValue)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreatePlan = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreatePlan) {
                CreatePlanView()
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Plans Yet")
                .font(.title2)
                .bold()
            
            Text("Create your first photography plan to organize your shoots")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { showingCreatePlan = true }) {
                Text("Create Plan")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
    
    private var plansList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredPlans) { plan in
                    NavigationLink(destination: PlanDetailView(plan: plan)) {
                        PlanCard(plan: plan)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }
    
    private var filteredPlans: [Plan] {
        let plans = appState.plans.isEmpty ? mockPlans : appState.plans
        
        let filtered = plans.filter { plan in
            switch selectedFilter {
            case .all:
                return true
            case .myPlans:
                return plan.createdBy == appState.currentUser?.id
            case .`public`:
                return plan.isPublic
            case .scheduled:
                return plan.startDate != nil
            }
        }
        
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { plan in
                plan.title.localizedCaseInsensitiveContains(searchText) ||
                (plan.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    private var noResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No plans found")
                .font(.title2)
                .bold()
            
            Text("Try adjusting your search or filter")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }
}

struct PlanCard: View {
    let plan: Plan
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.headline)
                    
                    if let startDate = plan.startDate {
                        Text(startDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if plan.isPublic {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.gray)
                }
            }
            
            HStack(spacing: 20) {
                Label("\(plan.items.count) items", systemImage: "mappin")
                    .font(.caption)
                
                if let duration = planDuration(plan) {
                    Label(duration, systemImage: "clock")
                        .font(.caption)
                } else if let estimatedDuration = plan.estimatedDuration {
                    Label("\(estimatedDuration) days", systemImage: "clock")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(plan.items.prefix(5)) { item in
                        VStack {
                            Circle()
                                .fill(colorForItemType(item.type).opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: item.type.systemImage)
                                        .font(.caption)
                                        .foregroundColor(colorForItemType(item.type))
                                )
                            
                            if let time = item.scheduledStartTime {
                                Text(formatTime(time))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if plan.items.count > 5 {
                        VStack {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text("+\(plan.items.count - 5)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                )
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func planDuration(_ plan: Plan) -> String? {
        guard let start = plan.startDate, let end = plan.endDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        return "\(days + 1) days"
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func colorForItemType(_ type: PlanItemType) -> Color {
        switch type {
        case .spot: return .green
        case .accommodation: return .blue
        case .restaurant: return .orange
        case .attraction: return .purple
        }
    }
}

let mockPlans = [
    Plan(
        id: UUID(),
        title: "Golden Gate Weekend",
        description: "A beautiful weekend exploring the Golden Gate area",
        createdBy: UUID(),
        createdAt: Date(),
        updatedAt: Date(),
        isPublic: false,
        originalPlanId: nil,
        estimatedDuration: 2,
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 2),
        items: [
            PlanItem(
                id: UUID(),
                planId: UUID(),
                type: .spot,
                orderIndex: 0,
                scheduledDate: Date(),
                scheduledStartTime: Date().addingTimeInterval(3600 * 6),
                scheduledEndTime: Date().addingTimeInterval(3600 * 8),
                timingPreference: .sunrise,
                spotId: UUID(),
                spot: nil,
                poiData: nil,
                notes: nil,
                createdAt: Date()
            ),
            PlanItem(
                id: UUID(),
                planId: UUID(),
                type: .restaurant,
                orderIndex: 1,
                scheduledDate: Date(),
                scheduledStartTime: Date().addingTimeInterval(3600 * 12),
                scheduledEndTime: Date().addingTimeInterval(3600 * 13),
                timingPreference: .flexible,
                spotId: nil,
                spot: nil,
                poiData: POIData(
                    name: "Fisherman's Wharf Restaurant",
                    address: "123 Pier St, San Francisco, CA",
                    coordinate: CLLocationCoordinate2D(latitude: 37.8080, longitude: -122.4177),
                    category: "Restaurant",
                    phoneNumber: "+1-415-555-0123",
                    website: "https://example.com",
                    mapItemIdentifier: nil,
                    businessHours: nil,
                    amenities: ["Outdoor Seating", "Ocean View"],
                    rating: 4.5,
                    priceRange: "$$",
                    photos: nil
                ),
                notes: "Great seafood with ocean views",
                createdAt: Date()
            )
        ]
    )
]

#Preview {
    PlansView()
        .environmentObject(AppState())
}