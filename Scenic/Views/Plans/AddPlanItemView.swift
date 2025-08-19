import SwiftUI
import MapKit

struct AddPlanItemView: View {
    let plan: Plan
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItemType: PlanItemType = .spot
    @State private var searchText = ""
    @State private var selectedDate = Date()
    @State private var selectedStartTime = Date()
    @State private var selectedEndTime = Date().addingTimeInterval(3600)
    @State private var timingPreference: TimingPreference = .flexible
    @State private var notes = ""
    @State private var isScheduled = false
    
    var body: some View {
        NavigationStack {
            Form {
                itemTypeSection
                
                if selectedItemType == .spot {
                    spotSelectionSection
                } else {
                    poiSearchSection
                }
                
                scheduleSection
                
                notesSection
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addItem()
                    }
                    .disabled(searchText.isEmpty)
                }
            }
        }
    }
    
    private var itemTypeSection: some View {
        Section("Item Type") {
            Picker("Type", selection: $selectedItemType) {
                ForEach(PlanItemType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.systemImage)
                        .tag(type)
                }
            }
            .pickerStyle(.menu)
        }
    }
    
    private var spotSelectionSection: some View {
        Section("Select Spot") {
            NavigationLink(destination: SpotPickerView()) {
                HStack {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.green)
                    Text("Choose from your spots")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var poiSearchSection: some View {
        Section(selectedItemType.displayName) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search \(selectedItemType.displayName.lowercased())", text: $searchText)
            }
            
            if !searchText.isEmpty {
                ForEach(mockPOIResults, id: \.name) { poi in
                    Button(action: { selectPOI(poi) }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(poi.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(poi.address)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if let rating = poi.rating {
                                    HStack(spacing: 2) {
                                        ForEach(0..<Int(rating), id: \.self) { _ in
                                            Image(systemName: "star.fill")
                                                .font(.caption2)
                                                .foregroundColor(.yellow)
                                        }
                                        Text(String(format: "%.1f", rating))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            if let priceRange = poi.priceRange {
                                Text(priceRange)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var scheduleSection: some View {
        Section("Schedule") {
            Toggle("Schedule specific time", isOn: $isScheduled)
            
            if isScheduled {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                DatePicker("Start Time", selection: $selectedStartTime, displayedComponents: .hourAndMinute)
                DatePicker("End Time", selection: $selectedEndTime, displayedComponents: .hourAndMinute)
            }
            
            if selectedItemType == .spot {
                Picker("Timing Preference", selection: $timingPreference) {
                    ForEach(TimingPreference.allCases, id: \.self) { preference in
                        Label(preference.displayName, systemImage: preference.systemImage)
                            .tag(preference)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
    
    private var notesSection: some View {
        Section("Notes") {
            TextField("Add notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    private func selectPOI(_ poi: POIData) {
        searchText = poi.name
    }
    
    private func addItem() {
        // TODO: Implement actual item addition logic
        print("Adding \(selectedItemType.displayName): \(searchText)")
        dismiss()
    }
    
    // Mock POI data for demonstration
    private var mockPOIResults: [POIData] {
        guard !searchText.isEmpty else { return [] }
        
        return [
            POIData(
                name: "Sample \(selectedItemType.displayName)",
                address: "123 Main St, San Francisco, CA",
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                category: selectedItemType.displayName,
                phoneNumber: "+1-415-555-0123",
                website: "https://example.com",
                mapItemIdentifier: nil,
                businessHours: nil,
                amenities: ["WiFi", "Parking"],
                rating: 4.5,
                priceRange: "$$",
                photos: nil
            )
        ]
    }
}

struct SpotPickerView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Text("Spot picker coming soon...")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Choose Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AddPlanItemView(plan: Plan(
        id: UUID(),
        title: "Sample Plan",
        description: nil,
        createdBy: UUID(),
        createdAt: Date(),
        updatedAt: Date(),
        isPublic: false,
        originalPlanId: nil,
        estimatedDuration: nil,
        startDate: nil,
        endDate: nil,
        items: []
    ))
}