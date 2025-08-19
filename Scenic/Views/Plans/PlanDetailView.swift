import SwiftUI
import MapKit

struct PlanDetailView: View {
    let plan: Plan
    @EnvironmentObject var appState: AppState
    @State private var selectedDate: Date = Date()
    @State private var viewMode: ViewMode = .timeline
    @State private var showingAddItem = false
    @State private var showingShareSheet = false
    @State private var editingItem: PlanItem?
    @State private var showingRemoveAlert = false
    @State private var itemToRemove: PlanItem?
    @State private var isEditMode = false
    
    // Inline editing state
    @State private var editTitle: String = ""
    @State private var editDescription: String = ""
    @State private var editIsPublic: Bool = false
    @State private var editEstimatedDuration: Int? = nil
    @State private var editStartDate: Date = Date()
    @State private var editEndDate: Date = Date()
    @State private var editIncludeDates: Bool = false
    
    enum ViewMode: String, CaseIterable {
        case timeline = "Timeline"
        case map = "Map"
    }
    
    var body: some View {
        Group {
            if isEditMode {
                ScrollView {
                    VStack(spacing: 0) {
                        planHeader
                        
                        viewModeSelector
                        
                        Group {
                            switch viewMode {
                            case .timeline:
                                timelineView
                            case .map:
                                mapView
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 0) {
                    planHeader
                    
                    viewModeSelector
                    
                    Group {
                        switch viewMode {
                        case .timeline:
                            timelineView
                        case .map:
                            mapView
                        }
                    }
                }
            }
        }
        .navigationTitle(isEditMode ? "Edit Plan" : plan.title)
        .navigationBarTitleDisplayMode(isEditMode ? .inline : .large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if isEditMode {
                    Button("Cancel") {
                        cancelEditing()
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditMode {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                } else {
                Menu {
                    Button(action: { showingShareSheet = true }) {
                        Label("Share Plan", systemImage: "square.and.arrow.up")
                    }
                    Button(action: {}) {
                        Label("Fork Plan", systemImage: "arrow.triangle.branch")
                    }
                    Button(action: { startEditing() }) {
                        Label("Edit Plan", systemImage: "pencil")
                    }
                    Button(action: {}) {
                        Label("Export GPX", systemImage: "map")
                    }
                    Button(role: .destructive, action: {}) {
                        Label("Delete Plan", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddPlanItemView(plan: plan)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [createShareText()])
        }
        .sheet(item: $editingItem) { item in
            EditPlanItemView(item: item, plan: plan)
        }
        .alert("Remove Item", isPresented: $showingRemoveAlert, presenting: itemToRemove) { item in
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                removeItem(item)
            }
        } message: { item in
            Text("Are you sure you want to remove \"\(item.displayName)\" from this plan?")
        }
    }
    
    private var planHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isEditMode {
                // Plan Title and Description (editable)
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Plan Title", text: $editTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Description (optional)", text: $editDescription, axis: .vertical)
                        .font(.subheadline)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                }
            } else {
                // Plan Description and Privacy (read-only)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if let description = plan.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No description")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .italic()
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if plan.isPublic {
                            Label("Public", systemImage: "globe")
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else {
                            Label("Private", systemImage: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            
            if isEditMode {
                // Edit mode controls
                VStack(alignment: .leading, spacing: 16) {
                    // Privacy Toggle
                    Toggle("Make plan public", isOn: $editIsPublic)
                        .font(.subheadline)
                    
                    // Duration Field
                    HStack {
                        Text("Estimated Duration")
                            .font(.subheadline)
                        Spacer()
                        TextField("Days", value: $editEstimatedDuration, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("days")
                            .font(.subheadline)
                    }
                    
                    // Date Controls
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Include specific dates", isOn: $editIncludeDates)
                            .font(.subheadline)
                        
                        if editIncludeDates {
                            VStack(spacing: 8) {
                                DatePicker("Start Date", selection: $editStartDate, displayedComponents: .date)
                                DatePicker("End Date", selection: $editEndDate, displayedComponents: .date)
                            }
                        }
                    }
                }
            } else {
                // Plan Metadata Grid (read-only)
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    // Duration Info
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Duration", systemImage: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if let actualDuration = plan.actualDuration {
                            Text("\(actualDuration + 1) days")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        } else if let estimatedDuration = plan.estimatedDuration {
                            Text("~\(estimatedDuration) days")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Not set")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    // Date Info
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Dates", systemImage: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if let dateRange = plan.dateRangeString {
                            Text(dateRange)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        } else {
                            Text("Flexible")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    // Items Count
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Items", systemImage: "mappin.and.ellipse")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("\(plan.items.count)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
            
            if let stats = planStats {
                HStack(spacing: 20) {
                    ForEach(stats, id: \.label) { stat in
                        VStack {
                            Text("\(stat.count)")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text(stat.label)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var planStats: [(label: String, count: Int)]? {
        let stats = plan.stats
        guard stats.totalItems > 0 else { return nil }
        
        var result: [(label: String, count: Int)] = []
        if stats.spotCount > 0 { result.append(("Spots", stats.spotCount)) }
        if stats.accommodationCount > 0 { result.append(("Hotels", stats.accommodationCount)) }
        if stats.restaurantCount > 0 { result.append(("Dining", stats.restaurantCount)) }
        if stats.attractionCount > 0 { result.append(("Attractions", stats.attractionCount)) }
        
        return result.isEmpty ? nil : result
    }
    
    private var viewModeSelector: some View {
        Picker("View Mode", selection: $viewMode) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
    
    private var dateSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<7, id: \.self) { dayOffset in
                    let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: plan.startDate ?? Date()) ?? Date()
                    
                    Button(action: { selectedDate = date }) {
                        VStack(spacing: 4) {
                            Text(dayName(date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.headline)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Calendar.current.isDate(selectedDate, inSameDayAs: date) ? Color.green : Color(.systemGray6))
                        .foregroundColor(Calendar.current.isDate(selectedDate, inSameDayAs: date) ? .white : .primary)
                        .cornerRadius(10)
                    }
                }
            }
        }
    }
    
    private var timelineView: some View {
        Group {
            if isEditMode {
                // In edit mode, don't add scroll view to avoid nesting
                VStack(spacing: 20) {
                    if plan.startDate != nil {
                        dateSelector
                    }
                    
                    timeline
                    
                    addItemButton
                }
                .padding()
            } else {
                // In read mode, use scroll view as before
                ScrollView {
                    VStack(spacing: 20) {
                        if plan.startDate != nil {
                            dateSelector
                        }
                        
                        timeline
                        
                        addItemButton
                    }
                    .padding()
                }
            }
        }
    }
    
    private var mapView: some View {
        Map {
            ForEach(plan.items.compactMap { $0.coordinate != nil ? $0 : nil }, id: \.id) { item in
                if let coordinate = item.coordinate {
                    Annotation(item.displayName, coordinate: coordinate) {
                        ZStack {
                            Circle()
                                .fill(colorForItemType(item.type))
                                .frame(width: 30, height: 30)
                            
                            Image(systemName: item.type.systemImage)
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .mapStyle(.standard)
        .overlay(alignment: .bottomTrailing) {
            addItemButton
                .padding()
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
    
    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEditMode {
                ForEach(plan.sortedItems, id: \.id) { item in
                    PlanItemRow(
                        item: item,
                        isEditMode: isEditMode,
                        onEdit: { editingItem = $0 },
                        onRemove: { 
                            itemToRemove = $0
                            showingRemoveAlert = true
                        }
                    )
                    .deleteDisabled(false)
                    
                    if item.id != plan.sortedItems.last?.id {
                        HStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 2, height: 30)
                                .offset(x: 17)
                            
                            Spacer()
                        }
                    }
                }
                .onMove(perform: moveItems)
            } else {
                ForEach(plan.sortedItems) { item in
                    PlanItemRow(
                        item: item,
                        isEditMode: isEditMode,
                        onEdit: { editingItem = $0 },
                        onRemove: { 
                            itemToRemove = $0
                            showingRemoveAlert = true
                        }
                    )
                    
                    if item.id != plan.sortedItems.last?.id {
                        HStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 2, height: 30)
                                .offset(x: 17)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
    }
    
    private var addItemButton: some View {
        Menu {
            Button(action: { showingAddItem = true }) {
                Label("Add Spot", systemImage: "camera.fill")
            }
            Button(action: { showingAddItem = true }) {
                Label("Add Accommodation", systemImage: "bed.double.fill")
            }
            Button(action: { showingAddItem = true }) {
                Label("Add Restaurant", systemImage: "fork.knife")
            }
            Button(action: { showingAddItem = true }) {
                Label("Add Attraction", systemImage: "star.fill")
            }
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.white)
                Text("Add Item")
                    .font(.footnote)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding()
            .background(.green)
            .cornerRadius(10)
        }
        .padding(.top, 12)
    }
    
    private func createShareText() -> String {
        var text = "Check out my plan: \(plan.title)\n\n"
        
        if let description = plan.description {
            text += "\(description)\n\n"
        }
        
        if let dateRange = plan.dateRangeString {
            text += "📅 \(dateRange)\n\n"
        }
        
        text += "📍 Includes \(plan.items.count) items:\n"
        
        for item in plan.sortedItems.prefix(5) {
            text += "• \(item.displayName)\n"
        }
        
        if plan.items.count > 5 {
            text += "... and \(plan.items.count - 5) more\n"
        }
        
        text += "\nShared from Scenic 📸"
        return text
    }
    
    private func dayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        let updatedPlan = appState.reorderPlanItems(plan: plan, from: source, to: destination)
        print("✅ Reordered plan items")
    }
    
    private func removeItem(_ item: PlanItem) {
        let updatedPlan = appState.removePlanItem(itemId: item.id, from: plan)
        print("✅ Removed item: \(item.displayName)")
    }
    
    // MARK: - Inline Editing Methods
    
    private func startEditing() {
        // Initialize edit state with current plan values
        editTitle = plan.title
        editDescription = plan.description ?? ""
        editIsPublic = plan.isPublic
        editEstimatedDuration = plan.estimatedDuration
        editStartDate = plan.startDate ?? Date()
        editEndDate = plan.endDate ?? Date().addingTimeInterval(86400) // Tomorrow
        editIncludeDates = plan.startDate != nil || plan.endDate != nil
        
        // Enter edit mode
        isEditMode = true
    }
    
    private func cancelEditing() {
        // Reset all edit state and exit edit mode
        isEditMode = false
        editTitle = ""
        editDescription = ""
        editIsPublic = false
        editEstimatedDuration = nil
        editStartDate = Date()
        editEndDate = Date()
        editIncludeDates = false
    }
    
    private func saveChanges() {
        // Create updated plan with new values
        var updatedPlan = plan
        updatedPlan.title = editTitle.isEmpty ? plan.title : editTitle
        updatedPlan.description = editDescription.isEmpty ? nil : editDescription
        updatedPlan.isPublic = editIsPublic
        updatedPlan.estimatedDuration = editEstimatedDuration
        updatedPlan.startDate = editIncludeDates ? editStartDate : nil
        updatedPlan.endDate = editIncludeDates ? editEndDate : nil
        updatedPlan.updatedAt = Date()
        
        // Save through AppState
        appState.savePlan(updatedPlan)
        
        // Exit edit mode
        isEditMode = false
        
        print("✅ Updated plan: \(updatedPlan.title)")
    }
}

struct PlanItemRow: View {
    let item: PlanItem
    let isEditMode: Bool
    let onEdit: (PlanItem) -> Void
    let onRemove: (PlanItem) -> Void
    
    var body: some View {
        Group {
            if item.type == .spot && !isEditMode, let spot = item.spot {
                NavigationLink(destination: SpotDetailView(spot: spot)) {
                    rowContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                rowContent
            }
        }
    }
    
    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 36, height: 36)
                
                Image(systemName: item.type.systemImage)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.headline)
                
                if let arrival = item.scheduledStartTime {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(formatTime(arrival))
                            .font(.caption)
                        
                        if let duration = item.durationMinutes {
                            Text("• \(duration) min")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.secondary)
                }
                
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            if !isEditMode {
                HStack(spacing: 8) {
                    // Show chevron for spot items to indicate they're tappable
                    if item.type == .spot && item.spot != nil {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Menu {
                        Button(action: { onEdit(item) }) {
                            Label("Edit Time", systemImage: "clock")
                        }
                        Button(action: {}) {
                            Label("Mark as Backup", systemImage: "star")
                        }
                        Button(role: .destructive, action: { onRemove(item) }) {
                            Label("Remove", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}