import SwiftUI

struct AddToPlanView: View {
    let spot: Spot
    @Environment(\.dismiss) var dismiss
    @State private var selectedPlan: Plan?
    @State private var targetDate = Date()
    @State private var arrivalTime = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Select Plan") {
                    ForEach(mockPlans) { plan in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(plan.name)
                                    .font(.headline)
                                if let date = plan.startDate {
                                    Text(date, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if selectedPlan?.id == plan.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPlan = plan
                        }
                    }
                }
                
                Section("Schedule") {
                    DatePicker("Date", selection: $targetDate, displayedComponents: .date)
                    DatePicker("Arrival Time", selection: $arrivalTime, displayedComponents: .hourAndMinute)
                }
                
                Section {
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Create New Plan")
                        }
                    }
                }
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
                        dismiss()
                    }
                    .disabled(selectedPlan == nil)
                }
            }
        }
    }
}