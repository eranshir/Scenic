import SwiftUI

struct FilterView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    let availableTags = [
        "Sunrise", "Sunset", "Mountains", "Ocean", "Forest",
        "Desert", "Urban", "Wildlife", "Waterfall", "Lake",
        "Bridge", "Architecture", "Night Sky", "Beach", "Trail"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Light Conditions") {
                    Toggle("Golden Hour", isOn: $appState.filterSettings.showGoldenHour)
                    Toggle("Blue Hour", isOn: $appState.filterSettings.showBlueHour)
                }
                
                Section("Difficulty") {
                    Picker("Difficulty", selection: $appState.filterSettings.selectedDifficulty) {
                        Text("Any").tag(nil as Spot.Difficulty?)
                        ForEach(Spot.Difficulty.allCases, id: \.self) { difficulty in
                            Text(difficulty.displayName).tag(difficulty as Spot.Difficulty?)
                        }
                    }
                }
                
                Section("Subject Tags") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                        ForEach(availableTags, id: \.self) { tag in
                            TagButton(
                                tag: tag,
                                isSelected: appState.filterSettings.selectedTags.contains(tag),
                                action: {
                                    if appState.filterSettings.selectedTags.contains(tag) {
                                        appState.filterSettings.selectedTags.remove(tag)
                                    } else {
                                        appState.filterSettings.selectedTags.insert(tag)
                                    }
                                }
                            )
                        }
                    }
                }
                
                Section("Distance") {
                    HStack {
                        Text("Max Distance")
                        Spacer()
                        if let distance = appState.filterSettings.maxDistance {
                            Text("\(Int(distance)) km")
                        } else {
                            Text("Any")
                        }
                    }
                    
                    Slider(
                        value: Binding(
                            get: { appState.filterSettings.maxDistance ?? 50 },
                            set: { appState.filterSettings.maxDistance = $0 }
                        ),
                        in: 1...100,
                        step: 1
                    )
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        appState.filterSettings = FilterSettings()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TagButton: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.green : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(15)
        }
    }
}

#Preview {
    FilterView()
        .environmentObject(AppState())
}