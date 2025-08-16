import SwiftUI

struct PlansView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingCreatePlan = false
    
    var body: some View {
        NavigationStack {
            Group {
                if appState.plans.isEmpty {
                    emptyState
                } else {
                    plansList
                }
            }
            .navigationTitle("Plans")
            .toolbar {
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
                ForEach(mockPlans) { plan in
                    NavigationLink(destination: PlanDetailView(plan: plan)) {
                        PlanCard(plan: plan)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }
}

struct PlanCard: View {
    let plan: Plan
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(.headline)
                    
                    if let startDate = plan.startDate {
                        Text(startDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if plan.isOfflineCached {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            HStack(spacing: 20) {
                Label("\(plan.items.count) spots", systemImage: "mappin")
                    .font(.caption)
                
                if let duration = planDuration(plan) {
                    Label(duration, systemImage: "clock")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(plan.items.prefix(5)) { item in
                        VStack {
                            Circle()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                )
                            
                            if let time = item.plannedArrivalUTC {
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
}

let mockPlans = [
    Plan(
        id: UUID(),
        userId: UUID(),
        name: "Golden Gate Weekend",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 2),
        timezoneIdentifier: TimeZone.current.identifier,
        isOfflineCached: true,
        items: [
            PlanItem(
                id: UUID(),
                planId: UUID(),
                spotId: UUID(),
                spot: mockSpots[0],
                targetDate: Date(),
                plannedArrivalUTC: Date().addingTimeInterval(3600 * 6),
                plannedDepartureUTC: Date().addingTimeInterval(3600 * 8),
                backupRank: nil,
                notes: nil,
                isCompleted: false
            )
        ],
        createdAt: Date(),
        updatedAt: Date()
    )
]

#Preview {
    PlansView()
        .environmentObject(AppState())
}