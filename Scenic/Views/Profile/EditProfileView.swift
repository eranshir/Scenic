import SwiftUI
import Supabase

struct EditProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Profile Information")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Your Name", text: $displayName)
                            .textContentType(.name)
                            .autocapitalization(.words)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("@username", text: $username)
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bio")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $bio)
                            .frame(minHeight: 100)
                    }
                }
                
                Section {
                    Text("Your Apple ID handle: @\(appState.currentUser?.handle ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveProfile()
                        }
                    }
                    .disabled(isLoading || displayName.isEmpty)
                }
            }
            .onAppear {
                loadCurrentProfile()
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                        }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func loadCurrentProfile() {
        guard let userId = appState.currentUser?.id else { return }
        
        Task {
            do {
                let profile: EditProfileData = try await supabase
                    .from("profiles")
                    .select()
                    .eq("id", value: userId.uuidString)
                    .single()
                    .execute()
                    .value
                
                await MainActor.run {
                    self.displayName = profile.display_name ?? appState.currentUser?.name ?? ""
                    self.username = profile.username ?? appState.currentUser?.handle ?? ""
                    self.bio = profile.bio ?? appState.currentUser?.bio ?? ""
                }
            } catch {
                // If profile doesn't exist, use defaults from appState
                await MainActor.run {
                    self.displayName = appState.currentUser?.name ?? ""
                    self.username = appState.currentUser?.handle ?? ""
                    self.bio = appState.currentUser?.bio ?? ""
                }
            }
        }
    }
    
    private func saveProfile() async {
        guard let userId = appState.currentUser?.id else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Check if profile exists
            let profileExists = try? await supabase
                .from("profiles")
                .select("id")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
            
            if profileExists != nil {
                // Update existing profile
                try await supabase
                    .from("profiles")
                    .update([
                        "display_name": displayName,
                        "username": username,
                        "bio": bio
                    ])
                    .eq("id", value: userId.uuidString)
                    .execute()
            } else {
                // Create new profile
                try await supabase
                    .from("profiles")
                    .insert([
                        "id": userId.uuidString,
                        "display_name": displayName,
                        "username": username,
                        "bio": bio
                    ])
                    .execute()
            }
            
            // Update appState with new values
            await MainActor.run {
                if var user = appState.currentUser {
                    user.name = displayName
                    user.handle = username
                    user.bio = bio
                    appState.currentUser = user
                }
                
                isLoading = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save profile: \(error.localizedDescription)"
                showError = true
                isLoading = false
            }
        }
    }
}

// Profile data model for decoding
private struct EditProfileData: Codable {
    let id: UUID
    let username: String?
    let display_name: String?
    let bio: String?
}

#Preview {
    EditProfileView()
        .environmentObject(AppState())
}