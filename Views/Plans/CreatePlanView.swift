import SwiftUI

struct CreatePlanView: View {
    @Environment(\.dismiss) var dismiss
    @State private var planName = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(86400)
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Plan Details") {
                    TextField("Plan Name", text: $planName)
                    
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }
                
                Section("Settings") {
                    Toggle("Download for offline use", isOn: .constant(false))
                    
                    Picker("Time Zone", selection: .constant(TimeZone.current.identifier)) {
                        Text(TimeZone.current.identifier).tag(TimeZone.current.identifier)
                    }
                }
            }
            .navigationTitle("New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        dismiss()
                    }
                    .disabled(planName.isEmpty)
                }
            }
        }
    }
}