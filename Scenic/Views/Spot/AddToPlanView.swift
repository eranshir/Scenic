import SwiftUI

struct AddToPlanView: View {
    let spot: Spot
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var selectedPlan: Plan?
    @State private var targetDate = Date()
    @State private var arrivalTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600) // 1 hour later
    @State private var timingPreference: TimingPreference = .flexible
    @State private var notes = ""
    @State private var includeSchedule = false
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                planSelectionSection
                scheduleSection
                createNewPlanSection
            }
            .navigationTitle("Add to Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addSpotToPlan()
                    }
                    .disabled(selectedPlan == nil)
                }
            }
        }
        .alert("Success!", isPresented: $showingSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(successMessage)
        }
    }
    
    private var planSelectionSection: some View {
        Section("Select Plan") {
            ForEach(appState.plans) { plan in
                planRow(plan)
            }
        }
    }
    
    private func planRow(_ plan: Plan) -> some View {
        HStack {
            planInfo(plan)
            Spacer()
            selectionIndicator(plan)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedPlan = plan
        }
    }
    
    private func planInfo(_ plan: Plan) -> some View {
        VStack(alignment: .leading) {
            Text(plan.title)
                .font(.headline)
            if let date = plan.startDate {
                Text(date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func selectionIndicator(_ plan: Plan) -> some View {
        Group {
            if selectedPlan?.id == plan.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                EmptyView()
            }
        }
    }
    
    private var scheduleSection: some View {
        Section("Schedule") {
            Toggle("Include specific schedule", isOn: $includeSchedule)
            
            if includeSchedule {
                DatePicker("Date", selection: $targetDate, displayedComponents: .date)
                DatePicker("Start Time", selection: $arrivalTime, displayedComponents: .hourAndMinute)
                DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
            }
            
            Picker("Timing Preference", selection: $timingPreference) {
                ForEach(TimingPreference.allCases, id: \.self) { preference in
                    Label(preference.displayName, systemImage: preference.systemImage)
                        .tag(preference)
                }
            }
            .pickerStyle(.menu)
            
            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(2...4)
        }
    }
    
    private var createNewPlanSection: some View {
        Section {
            Button(action: createNewPlan) {
                HStack {
                    Image(systemName: "plus")
                    Text("Create New Plan")
                }
            }
        }
    }
    
    private func addSpotToPlan() {
        guard let selectedPlan = selectedPlan else { return }
        
        // Create a new PlanItem for the spot
        let newPlanItem = PlanItem(
            id: UUID(),
            planId: selectedPlan.id,
            type: .spot,
            orderIndex: selectedPlan.items.count, // Add at the end
            scheduledDate: includeSchedule ? targetDate : nil,
            scheduledStartTime: includeSchedule ? arrivalTime : nil,
            scheduledEndTime: includeSchedule ? endTime : nil,
            timingPreference: timingPreference,
            spotId: spot.id,
            spot: spot, // Include the full spot data
            poiData: nil,
            notes: notes.isEmpty ? nil : notes,
            createdAt: Date()
        )
        
        // Find the plan in appState and update it
        if let planIndex = appState.plans.firstIndex(where: { $0.id == selectedPlan.id }) {
            appState.plans[planIndex].items.append(newPlanItem)
            
            // TODO: Sync to database via PlanDataService
            // Task {
            //     do {
            //         try await PlanDataService.shared.addItemToPlan(planId: selectedPlan.id, item: newPlanItem)
            //     } catch {
            //         // Handle error
            //         print("Failed to add item to plan: \(error)")
            //     }
            // }
            
            print("✅ Added spot \(spot.title) to plan \(selectedPlan.title)")
        }
        
        successMessage = "\(spot.title) has been added to your plan!"
        showingSuccessAlert = true
    }
    
    private func createNewPlan() {
        // Create a new plan with the current spot
        let newPlan = Plan(
            id: UUID(),
            title: "New Plan with \(spot.title)",
            description: "Plan created from \(spot.title)",
            createdBy: appState.currentUser?.id ?? UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            isPublic: false,
            originalPlanId: nil,
            estimatedDuration: nil,
            startDate: includeSchedule ? targetDate : nil,
            endDate: includeSchedule ? targetDate : nil,
            items: []
        )
        
        // Add the plan to appState
        appState.plans.append(newPlan)
        
        // Select the newly created plan
        selectedPlan = newPlan
        
        // TODO: Sync to database via PlanDataService
        // Task {
        //     do {
        //         try await PlanDataService.shared.createPlan(newPlan)
        //     } catch {
        //         print("Failed to create plan: \(error)")
        //     }
        // }
        
        print("✅ Created new plan: \(newPlan.title)")
    }
}