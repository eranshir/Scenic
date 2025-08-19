import SwiftUI

struct EditPlanView: View {
    let plan: Plan
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var description: String
    @State private var isPublic: Bool
    @State private var estimatedDuration: Int?
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var includeDates: Bool
    
    @State private var isUpdating = false
    @State private var errorMessage: String?
    
    init(plan: Plan) {
        self.plan = plan
        self._title = State(initialValue: plan.title)
        self._description = State(initialValue: plan.description ?? "")
        self._isPublic = State(initialValue: plan.isPublic)
        self._estimatedDuration = State(initialValue: plan.estimatedDuration)
        self._startDate = State(initialValue: plan.startDate ?? Date())
        self._endDate = State(initialValue: plan.endDate ?? Date().addingTimeInterval(86400))
        self._includeDates = State(initialValue: plan.startDate != nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Plan Details") {
                    TextField("Plan Title", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Duration") {
                    HStack {
                        Text("Estimated Duration")
                        Spacer()
                        TextField("Days", value: $estimatedDuration, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("days")
                    }
                }
                
                Section("Dates") {
                    Toggle("Include specific dates", isOn: $includeDates)
                    
                    if includeDates {
                        DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                    }
                }
                
                Section("Privacy") {
                    Toggle("Make plan public", isOn: $isPublic)
                    
                    if isPublic {
                        Text("Public plans can be viewed and forked by other users")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Plan Items") {
                    Text("Items: \(plan.items.count)")
                        .foregroundColor(.secondary)
                    
                    if plan.items.isEmpty {
                        Text("No items added yet")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(plan.items.prefix(3)) { item in
                            HStack {
                                Image(systemName: item.type.systemImage)
                                    .foregroundColor(colorForItemType(item.type))
                                Text(item.displayName)
                                    .font(.caption)
                                Spacer()
                            }
                        }
                        
                        if plan.items.count > 3 {
                            Text("... and \(plan.items.count - 3) more items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updatePlan()
                    }
                    .disabled(title.isEmpty || isUpdating)
                }
            }
        }
    }
    
    private func updatePlan() {
        guard !title.isEmpty else { return }
        
        isUpdating = true
        errorMessage = nil
        
        // Create updated plan with new values
        var updatedPlan = plan
        updatedPlan.title = title
        updatedPlan.description = description.isEmpty ? nil : description
        updatedPlan.isPublic = isPublic
        updatedPlan.estimatedDuration = estimatedDuration
        updatedPlan.startDate = includeDates ? startDate : nil
        updatedPlan.endDate = includeDates ? endDate : nil
        updatedPlan.updatedAt = Date()
        
        // Update through AppState
        appState.updatePlan(updatedPlan)
        
        print("✅ Updated plan: \(updatedPlan.title)")
        
        isUpdating = false
        dismiss()
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

#Preview {
    EditPlanView(plan: Plan(
        id: UUID(),
        title: "Sample Plan",
        description: "A sample plan for testing",
        createdBy: UUID(),
        createdAt: Date(),
        updatedAt: Date(),
        isPublic: false,
        originalPlanId: nil,
        estimatedDuration: 3,
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 3),
        items: []
    ))
    .environmentObject(AppState())
}