import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("useMetricUnits") private var useMetricUnits = true
    @AppStorage("downloadOverCellular") private var downloadOverCellular = false
    @AppStorage("autoBackup") private var autoBackup = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    NavigationLink(destination: Text("Edit Profile")) {
                        Label("Edit Profile", systemImage: "person.circle")
                    }
                    
                    NavigationLink(destination: Text("Privacy Settings")) {
                        Label("Privacy", systemImage: "lock")
                    }
                    
                    NavigationLink(destination: Text("Notifications")) {
                        Label("Notifications", systemImage: "bell")
                    }
                }
                
                Section("Preferences") {
                    Toggle("Use Metric Units", isOn: $useMetricUnits)
                    
                    Toggle("Download over Cellular", isOn: $downloadOverCellular)
                    
                    Toggle("Auto Backup Photos", isOn: $autoBackup)
                    
                    NavigationLink(destination: Text("Default License")) {
                        HStack {
                            Text("Default License")
                            Spacer()
                            Text("CC-BY-NC")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Data") {
                    Button(action: {}) {
                        Label("Export My Data", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: {}) {
                        Label("Clear Cache", systemImage: "trash")
                    }
                    
                    HStack {
                        Text("Cache Size")
                        Spacer()
                        Text("124 MB")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Support") {
                    NavigationLink(destination: Text("Help Center")) {
                        Label("Help Center", systemImage: "questionmark.circle")
                    }
                    
                    NavigationLink(destination: Text("Contact Support")) {
                        Label("Contact Support", systemImage: "envelope")
                    }
                    
                    NavigationLink(destination: Text("Terms of Service")) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                    
                    NavigationLink(destination: Text("Privacy Policy")) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Build 1)")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {}) {
                        Label("Rate Scenic", systemImage: "star")
                    }
                    
                    Button(action: {}) {
                        Label("Share Scenic", systemImage: "square.and.arrow.up")
                    }
                }
                
                Section {
                    Button(action: {}) {
                        Text("Delete Account")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}