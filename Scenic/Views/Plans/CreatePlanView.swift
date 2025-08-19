import SwiftUI

struct CreatePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var title = ""
    @State private var description = ""
    @State private var isPublic = false
    @State private var estimatedDuration: Int? = nil
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(86400) // Tomorrow
    @State private var includeDates = false
    
    @State private var isCreating = false
    @State private var errorMessage: String?
    
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
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Create Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createPlan()
                    }
                    .disabled(title.isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createPlan() {
        guard !title.isEmpty else { return }
        
        isCreating = true
        errorMessage = nil
        
        // Create new plan
        let newPlan = Plan(
            id: UUID(),
            title: title,
            description: description.isEmpty ? nil : description,
            createdBy: appState.currentUser?.id ?? UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            isPublic: isPublic,
            originalPlanId: nil,
            estimatedDuration: estimatedDuration,
            startDate: includeDates ? startDate : nil,
            endDate: includeDates ? endDate : nil,
            items: []
        )
        
        // Add to app state (temporary - will use proper data service later)
        appState.plans.append(newPlan)
        
        // TODO: Save to database via PlanDataService
        // Task {
        //     do {
        //         try await PlanDataService.shared.createPlan(newPlan)
        //     } catch {
        //         await MainActor.run {
        //             errorMessage = "Failed to create plan: \(error.localizedDescription)"
        //             isCreating = false
        //         }
        //         return
        //     }
        // }
        
        isCreating = false
        dismiss()
    }
}

#Preview {
    CreatePlanView()
        .environmentObject(AppState())
}