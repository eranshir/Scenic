import SwiftUI
import CoreLocation

struct EditPlanItemView: View {
    let item: PlanItem
    let plan: Plan
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var scheduledDate: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var timingPreference: TimingPreference
    @State private var notes: String
    @State private var includeSchedule: Bool
    
    init(item: PlanItem, plan: Plan) {
        self.item = item
        self.plan = plan
        
        _scheduledDate = State(initialValue: item.scheduledDate ?? Date())
        _startTime = State(initialValue: item.scheduledStartTime ?? Date())
        _endTime = State(initialValue: item.scheduledEndTime ?? Date().addingTimeInterval(3600))
        _timingPreference = State(initialValue: item.timingPreference ?? .flexible)
        _notes = State(initialValue: item.notes ?? "")
        _includeSchedule = State(initialValue: item.scheduledDate != nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                itemInfoSection
                scheduleSection
                notesSection
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
        }
    }
    
    private var itemInfoSection: some View {
        Section("Item Details") {
            HStack {
                Image(systemName: item.type.systemImage)
                    .foregroundColor(colorForItemType(item.type))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.headline)
                    Text(item.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
    
    private var scheduleSection: some View {
        Section("Schedule") {
            Toggle("Include specific schedule", isOn: $includeSchedule)
            
            if includeSchedule {
                DatePicker("Date", selection: $scheduledDate, displayedComponents: .date)
                DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
            }
            
            Picker("Timing Preference", selection: $timingPreference) {
                ForEach(TimingPreference.allCases, id: \.self) { preference in
                    Label(preference.displayName, systemImage: preference.systemImage)
                        .tag(preference)
                }
            }
            .pickerStyle(.menu)
        }
    }
    
    private var notesSection: some View {
        Section("Notes") {
            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(2...6)
        }
    }
    
    private func colorForItemType(_ type: PlanItemType) -> Color {
        switch type {
        case .spot: return .green
        case .accommodation: return .blue
        case .restaurant: return .orange
        case .attraction: return .purple
        }
    }
    
    private func saveChanges() {
        guard let planIndex = appState.plans.firstIndex(where: { $0.id == plan.id }),
              let itemIndex = appState.plans[planIndex].items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        
        // Update the item with new values
        appState.plans[planIndex].items[itemIndex].scheduledDate = includeSchedule ? scheduledDate : nil
        appState.plans[planIndex].items[itemIndex].scheduledStartTime = includeSchedule ? startTime : nil
        appState.plans[planIndex].items[itemIndex].scheduledEndTime = includeSchedule ? endTime : nil
        appState.plans[planIndex].items[itemIndex].timingPreference = timingPreference
        appState.plans[planIndex].items[itemIndex].notes = notes.isEmpty ? nil : notes
        
        print("✅ Updated plan item: \(item.displayName)")
        dismiss()
    }
}

#Preview {
    let mockSpot = Spot(
        id: UUID(),
        title: "Golden Gate Bridge",
        location: CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783),
        headingDegrees: nil,
        elevationMeters: nil,
        subjectTags: ["bridge", "landmark"],
        difficulty: .easy,
        createdBy: UUID(),
        privacy: .publicSpot,
        license: "CC BY 4.0",
        status: .active,
        createdAt: Date(),
        updatedAt: Date()
    )
    
    let mockItem = PlanItem(
        id: UUID(),
        planId: UUID(),
        type: .spot,
        orderIndex: 0,
        scheduledDate: Date(),
        scheduledStartTime: Date(),
        scheduledEndTime: Date().addingTimeInterval(3600),
        timingPreference: .sunrise,
        spotId: mockSpot.id,
        spot: mockSpot,
        poiData: nil,
        notes: "Great sunrise spot",
        createdAt: Date()
    )
    
    let mockPlan = Plan(
        id: UUID(),
        title: "San Francisco Photography",
        description: "Weekend photography plan",
        createdBy: UUID(),
        createdAt: Date(),
        updatedAt: Date(),
        isPublic: false,
        originalPlanId: nil,
        estimatedDuration: 2,
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 2),
        items: [mockItem]
    )
    
    EditPlanItemView(item: mockItem, plan: mockPlan)
        .environmentObject(AppState())
}