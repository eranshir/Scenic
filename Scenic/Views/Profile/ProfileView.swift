import SwiftUI
import Supabase

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingSettings = false
    @State private var showingEditProfile = false
    @State private var profileData: ProfileData?
    @State private var userStats: UserStats?
    @State private var isLoadingProfile = false
    @State private var profileError: String?
    
    private var authProviderIcon: String {
        switch appState.authProvider {
        case .apple:
            return "applelogo"
        case .google:
            return "g.circle.fill"
        case .guest:
            return "person.fill.questionmark"
        case .none:
            return "person.circle"
        }
    }
    
    private var authProviderColor: Color {
        switch appState.authProvider {
        case .apple:
            return .black
        case .google:
            return .blue
        case .guest:
            return .orange
        case .none:
            return .gray
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                    
                    statsSection
                    
                    badgesSection
                    
                    contributionsSection
                    
                    settingsButton
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(profileData?.displayName ?? appState.currentUser?.name ?? "Profile")
                            .font(.headline)
                        if !appState.isGuestMode {
                            Text("@\(profileData?.username ?? appState.currentUser?.handle ?? "")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingEditProfile, onDismiss: {
                Task {
                    await loadProfileData()
                }
            }) {
                EditProfileView()
                    .environmentObject(appState)
            }
            .onAppear {
                Task {
                    await loadProfileData()
                }
            }
            .refreshable {
                await loadProfileData()
            }
        }
    }
    
    private func loadProfileData() async {
        // Skip loading for guest users
        guard !appState.isGuestMode else {
            // Set default guest stats
            await MainActor.run {
                userStats = UserStats(
                    spotsCreated: 0,
                    photosShared: 0,
                    plansCreated: 0,
                    explorerScore: 0,
                    explorerLevel: "Guest"
                )
            }
            return
        }
        
        guard let userId = appState.currentUser?.id else { return }
        
        await MainActor.run {
            isLoadingProfile = true
            profileError = nil
        }
        
        do {
            // Fetch profile data from profiles table
            let profile: ProfileResponse = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            // Debug logging
            print("📱 ProfileView - Fetched Profile Data:")
            print("  - ID: \(profile.id)")
            print("  - Username: \(profile.username ?? "nil")")
            print("  - Display Name: \(profile.display_name ?? "nil")")
            print("  - Bio: \(profile.bio ?? "nil")")
            print("  - Current AppState Name: \(appState.currentUser?.name ?? "nil")")
            print("  - Current AppState Handle: \(appState.currentUser?.handle ?? "nil")")
            
            // Fetch user statistics
            let stats = try await fetchUserStatistics(userId: userId)
            
            await MainActor.run {
                // Smart display name logic:
                // 1. If profile.display_name exists and is different from username, use it
                // 2. Otherwise, prefer AppState name if it exists and is not just the username
                // 3. Fall back to username as last resort
                
                let username = profile.username ?? appState.currentUser?.handle ?? "user"
                let appStateName = appState.currentUser?.name ?? ""
                
                var displayName: String
                
                // Check if display_name from DB is actually a proper name (not same as username)
                if let dbDisplayName = profile.display_name,
                   !dbDisplayName.isEmpty,
                   dbDisplayName.lowercased() != username.lowercased() {
                    // Database has a real display name
                    displayName = dbDisplayName
                    print("  Using display_name from database: \(displayName)")
                } else if !appStateName.isEmpty && 
                         appStateName.lowercased() != username.lowercased() {
                    // AppState has a real name (from auth provider)
                    displayName = appStateName
                    print("  Using name from AppState: \(displayName)")
                } else {
                    // Fall back to username
                    displayName = username.capitalized
                    print("  Falling back to username: \(displayName)")
                }
                
                self.profileData = ProfileData(
                    id: profile.id,
                    username: username,
                    displayName: displayName,
                    bio: profile.bio ?? appState.currentUser?.bio,
                    avatarUrl: profile.avatar_url ?? appState.currentUser?.avatarUrl,
                    explorerScore: profile.explorer_score ?? 0,
                    explorerLevel: profile.explorer_level ?? "Novice"
                )
                
                print("📱 ProfileView - Set ProfileData:")
                print("  - Display Name: \(self.profileData?.displayName ?? "nil")")
                print("  - Username: \(self.profileData?.username ?? "nil")")
                
                self.userStats = stats
                isLoadingProfile = false
            }
        } catch {
            await MainActor.run {
                profileError = "Failed to load profile"
                isLoadingProfile = false
                print("Error loading profile: \(error)")
            }
        }
    }
    
    private func levelColor(for level: String) -> Color {
        switch level {
        case "Guest": return .gray
        case "Novice": return .blue
        case "Explorer": return .green
        case "Adventurer": return .orange
        case "Master": return .purple
        case "Legend": return .red
        default: return .gray
        }
    }
    
    private func nextLevelPoints(for level: String) -> Int {
        switch level {
        case "Guest": return 0
        case "Novice": return 100
        case "Explorer": return 500
        case "Adventurer": return 1500
        case "Master": return 5000
        case "Legend": return 10000
        default: return 100
        }
    }
    
    private func fetchUserStatistics(userId: UUID) async throws -> UserStats {
        // Fetch counts from different tables
        async let spotsCount = try supabase
            .from("spots")
            .select("id", head: true, count: .exact)
            .eq("created_by", value: userId.uuidString)
            .execute()
            .count
        
        async let mediaCount = try supabase
            .from("media")
            .select("id", head: true, count: .exact)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .count
        
        async let plansCount = try supabase
            .from("plans")
            .select("id", head: true, count: .exact)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .count
        
        let (spots, media, plans) = try await (spotsCount, mediaCount, plansCount)
        
        return UserStats(
            spotsCreated: spots ?? 0,
            photosShared: media ?? 0,
            plansCreated: plans ?? 0,
            explorerScore: profileData?.explorerScore ?? 0,
            explorerLevel: profileData?.explorerLevel ?? "Novice"
        )
    }
    
    private var profileHeader: some View {
        VStack(spacing: 12) {
            // Profile image with provider indicator
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(appState.isGuestMode ? .gray.opacity(0.5) : .gray)
                
                // Auth provider badge
                if appState.authProvider != .none {
                    Image(systemName: authProviderIcon)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(authProviderColor)
                        .clipShape(Circle())
                        .offset(x: 5, y: 5)
                }
            }
            
            Text(profileData?.displayName ?? appState.currentUser?.name ?? "User")
                .font(.title2)
                .bold()
            
            if !appState.isGuestMode {
                Text("@\(profileData?.username ?? appState.currentUser?.handle ?? "username")")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                Text("Guest Mode")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(12)
            }
            
            if let bio = profileData?.bio ?? appState.currentUser?.bio, !bio.isEmpty {
                Text(bio)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else if isLoadingProfile {
                ProgressView()
                    .scaleEffect(0.8)
            }
            
            HStack(spacing: 30) {
                VStack {
                    Text("\(appState.currentUser?.followersCount ?? 0)")
                        .font(.headline)
                    Text("Followers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(appState.currentUser?.followingCount ?? 0)")
                        .font(.headline)
                    Text("Following")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(appState.currentUser?.spotsCount ?? 0)")
                        .font(.headline)
                    Text("Spots")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if appState.isGuestMode {
                Button(action: { showingSettings = true }) {
                    Label("Sign in for full access", systemImage: "person.crop.circle.badge.plus")
                        .font(.footnote)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                }
            } else {
                Button(action: { showingEditProfile = true }) {
                    Text("Edit Profile")
                        .font(.footnote)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .cornerRadius(20)
                }
            }
        }
    }
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reputation")
                    .font(.headline)
                
                if appState.isGuestMode {
                    Text("(Sign in to track)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("\(userStats?.explorerScore ?? appState.currentUser?.reputationScore ?? 0) points")
                    .font(.subheadline)
                
                Spacer()
                
                Text(userStats?.explorerLevel ?? "Novice")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(levelColor(for: userStats?.explorerLevel ?? "Novice"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            
            let currentScore = Double(userStats?.explorerScore ?? appState.currentUser?.reputationScore ?? 0)
            let nextLevelThreshold = nextLevelPoints(for: userStats?.explorerLevel ?? "Novice")
            
            ProgressView(value: currentScore, total: Double(nextLevelThreshold))
                .tint(.green)
            
            Text("\(nextLevelThreshold - Int(currentScore)) points to next level")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Badges")
                    .font(.headline)
                Spacer()
                Text("View All")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    BadgeView(icon: "star.fill", name: "Explorer", color: .yellow)
                    BadgeView(icon: "sunrise.fill", name: "Early Bird", color: .orange)
                    BadgeView(icon: "mountain.2.fill", name: "Adventurer", color: .green)
                    BadgeView(icon: "camera.fill", name: "Contributor", color: .blue)
                }
            }
        }
    }
    
    private var contributionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Contributions")
                    .font(.headline)
                Spacer()
                if !appState.isGuestMode {
                    NavigationLink(destination: Text("All Contributions")) {
                        Text("See All")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            // Show stats
            if let stats = userStats, !appState.isGuestMode {
                HStack(spacing: 20) {
                    StatItem(value: stats.spotsCreated, label: "Spots")
                    StatItem(value: stats.photosShared, label: "Photos")
                    StatItem(value: stats.plansCreated, label: "Plans")
                }
                .padding(.vertical, 8)
            }
            
            if appState.isGuestMode {
                Text("Sign in to save and track your contributions")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            } else if appState.spots.isEmpty {
                Text("No contributions yet")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            } else {
                ForEach(0..<min(3, appState.spots.count), id: \.self) { index in
                    ContributionRow(spot: appState.spots[index])
                }
            }
        }
    }
    
    private var settingsButton: some View {
        VStack(spacing: 12) {
            Button(action: {}) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Profile")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            
            Button(action: { appState.signOut() }) {
                Text(appState.isGuestMode ? "Exit Guest Mode" : "Sign Out")
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
        }
    }
}

struct StatItem: View {
    let value: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct BadgeView: View {
    let icon: String
    let name: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            Text(name)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct ContributionRow: View {
    var spot: Spot? = nil
    
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.green.opacity(0.3))
                .frame(width: 50, height: 50)
                .cornerRadius(8)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.white.opacity(0.5))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(spot?.title ?? "Mountain Peak Vista")
                    .font(.footnote)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(timeAgo(from: spot?.createdAt ?? Date()))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack {
                Image(systemName: "arrow.up")
                    .font(.caption)
                Text("24")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// Helper function for time formatting
func timeAgo(from date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}

// MARK: - Extensions

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}

// MARK: - Data Models

struct ProfileData {
    let id: UUID
    let username: String
    let displayName: String
    let bio: String?
    let avatarUrl: String?
    let explorerScore: Int
    let explorerLevel: String
}

struct UserStats {
    let spotsCreated: Int
    let photosShared: Int
    let plansCreated: Int
    let explorerScore: Int
    let explorerLevel: String
}

struct ProfileResponse: Codable {
    let id: UUID
    let username: String?
    let display_name: String?
    let bio: String?
    let avatar_url: String?
    let explorer_score: Int?
    let explorer_level: String?
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
}