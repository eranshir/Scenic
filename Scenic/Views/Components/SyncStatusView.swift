import SwiftUI

struct SyncStatusView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var syncService = SyncService.shared
    @State private var syncStatus: SyncStatus = .synced
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Status Icon
                statusIcon
                
                // Status Text
                Text(syncStatus.displayText)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Progress
                if syncService.isSyncing {
                    VStack(spacing: 12) {
                        ProgressView(value: syncService.syncProgress)
                            .progressViewStyle(.linear)
                            .padding(.horizontal)
                        
                        Text(syncService.syncStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Error List
                if !syncService.syncErrors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sync Errors:")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(syncService.syncErrors, id: \.self) { error in
                                    HStack(alignment: .top) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.caption)
                                        Text(error)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .padding()
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    if case .pending(let count) = syncStatus {
                        Button(action: {
                            Task {
                                await syncService.syncLocalSpotsToSupabase()
                                await updateStatus()
                            }
                        }) {
                            Label("Sync \(count) Spot\(count == 1 ? "" : "s")", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(syncService.isSyncing)
                    }
                    
                    Button("Done") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
                    .disabled(syncService.isSyncing)
                }
                .padding()
            }
            .navigationTitle("Sync Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !syncService.isSyncing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
            }
            .task {
                await updateStatus()
            }
        }
    }
    
    private var statusIcon: some View {
        Group {
            switch syncStatus {
            case .synced:
                Image(systemName: "checkmark.icloud.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
            case .pending:
                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
            case .syncing:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .symbolEffect(.rotate)
            case .error:
                Image(systemName: "exclamationmark.icloud.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
    
    private func updateStatus() async {
        if syncService.isSyncing {
            syncStatus = .syncing
        } else {
            syncStatus = await syncService.checkSyncStatus()
        }
    }
}

#Preview {
    SyncStatusView()
}