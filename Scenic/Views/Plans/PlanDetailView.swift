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
    
    enum ViewMode: String, CaseIterable {
        case timeline = "Timeline"
        case map = "Map"
    }
    
    var body: some View {
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
        .navigationTitle(plan.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if viewMode == .timeline {
                    Button(isEditMode ? "Done" : "Edit") {
                        withAnimation {
                            isEditMode.toggle()
                        }
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingShareSheet = true }) {
                        Label("Share Plan", systemImage: "square.and.arrow.up")
                    }
                    Button(action: {}) {
                        Label("Fork Plan", systemImage: "arrow.triangle.branch")
                    }
                    Button(action: {}) {
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let description = plan.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let dateRange = plan.dateRangeString {
                        Text(dateRange)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(plan.items.count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if plan.isPublic {
                        Label("Public", systemImage: "globe")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    } else {
                        Label("Private", systemImage: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(.gray)
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
        guard let planIndex = appState.plans.firstIndex(where: { $0.id == plan.id }) else { return }
        
        var updatedItems = appState.plans[planIndex].sortedItems
        updatedItems.move(fromOffsets: source, toOffset: destination)
        
        // Update order indices
        for (index, item) in updatedItems.enumerated() {
            if let itemIndex = appState.plans[planIndex].items.firstIndex(where: { $0.id == item.id }) {
                appState.plans[planIndex].items[itemIndex].orderIndex = index
            }
        }
        
        print("✅ Reordered plan items")
    }
    
    private func removeItem(_ item: PlanItem) {
        guard let planIndex = appState.plans.firstIndex(where: { $0.id == plan.id }) else { return }
        
        appState.plans[planIndex].items.removeAll { $0.id == item.id }
        
        // Update order indices for remaining items
        let sortedItems = appState.plans[planIndex].sortedItems
        for (index, remainingItem) in sortedItems.enumerated() {
            if let itemIndex = appState.plans[planIndex].items.firstIndex(where: { $0.id == remainingItem.id }) {
                appState.plans[planIndex].items[itemIndex].orderIndex = index
            }
        }
        
        print("✅ Removed item: \(item.displayName)")
    }
}

struct PlanItemRow: View {
    let item: PlanItem
    let isEditMode: Bool
    let onEdit: (PlanItem) -> Void
    let onRemove: (PlanItem) -> Void
    
    var body: some View {
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
        .padding(.vertical, 8)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}