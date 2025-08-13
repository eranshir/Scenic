import SwiftUI

struct PlanDetailView: View {
    let plan: Plan
    @State private var selectedDate: Date = Date()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                dateSelector
                
                timeline
                
                downloadOfflineButton
            }
            .padding()
        }
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {}) {
                        Label("Edit Plan", systemImage: "pencil")
                    }
                    Button(action: {}) {
                        Label("Export GPX", systemImage: "square.and.arrow.up")
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
    
    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(plan.sortedItems) { item in
                PlanItemRow(item: item)
                
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
            
            addSpotButton
        }
    }
    
    private var addSpotButton: some View {
        Button(action: {}) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
                Text("Add Spot")
                    .font(.footnote)
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding(.top, 12)
    }
    
    private var downloadOfflineButton: some View {
        Button(action: {}) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                Text("Download for Offline")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
    
    private func dayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

struct PlanItemRow: View {
    let item: PlanItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.isCompleted ? Color.green : Color(.systemGray5))
                    .frame(width: 36, height: 36)
                
                Image(systemName: item.isCompleted ? "checkmark" : "camera.fill")
                    .font(.caption)
                    .foregroundColor(item.isCompleted ? .white : .primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.spot?.title ?? "Unknown Spot")
                    .font(.headline)
                
                if let arrival = item.plannedArrivalUTC {
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
            
            Menu {
                Button(action: {}) {
                    Label("View Spot", systemImage: "eye")
                }
                Button(action: {}) {
                    Label("Edit Time", systemImage: "clock")
                }
                Button(action: {}) {
                    Label("Mark as Backup", systemImage: "star")
                }
                Button(role: .destructive, action: {}) {
                    Label("Remove", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
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