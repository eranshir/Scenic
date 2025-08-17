import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var spotDataService: SpotDataService
    @AppStorage("useMetricUnits") private var useMetricUnits = true
    @AppStorage("downloadOverCellular") private var downloadOverCellular = false
    @AppStorage("autoBackup") private var autoBackup = true
    @State private var showingClearConfirmation = false
    @State private var showingSignOutConfirmation = false
    
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
                    
                    Button(action: { showingClearConfirmation = true }) {
                        Label("Clear All Spots (Debug)", systemImage: "exclamationmark.triangle")
                            .foregroundColor(.red)
                    }
                    
                    Button(action: { spotDataService.cleanupPhotoIdentifiers() }) {
                        Label("Fix Photo Identifiers", systemImage: "wrench.and.screwdriver")
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: { PhotoCacheService.shared.listCachedFiles() }) {
                        Label("List Cached Files (Debug)", systemImage: "list.clipboard")
                            .foregroundColor(.orange)
                    }
                    
                    Button(action: { spotDataService.verifyPhotoCacheConsistency() }) {
                        Label("Verify Cache Consistency", systemImage: "checkmark.shield")
                            .foregroundColor(.purple)
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
                    Button(action: { showingSignOutConfirmation = true }) {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                    
                    Button(action: {}) {
                        HStack {
                            Spacer()
                            Text("Delete Account")
                                .foregroundColor(.red)
                            Spacer()
                        }
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
            .confirmationDialog("Clear All Spots", isPresented: $showingClearConfirmation) {
                Button("Clear All Spots", role: .destructive) {
                    spotDataService.clearAllSpots()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all spots and cached photos. This cannot be undone.")
            }
            .confirmationDialog("Sign Out", isPresented: $showingSignOutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    appState.signOut()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

#Preview {
    SettingsView()
}