import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingSettings = false
    
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
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text(appState.currentUser?.name ?? "User")
                .font(.title2)
                .bold()
            
            Text("@\(appState.currentUser?.handle ?? "username")")
                .font(.footnote)
                .foregroundColor(.secondary)
            
            if let bio = appState.currentUser?.bio {
                Text(bio)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
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
            
            Button(action: {}) {
                Text("Edit Profile")
                    .font(.footnote)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    .cornerRadius(20)
            }
        }
    }
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reputation")
                .font(.headline)
            
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("\(appState.currentUser?.reputationScore ?? 0) points")
                    .font(.subheadline)
                
                Spacer()
                
                Text("Level 3")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            
            ProgressView(value: Double(appState.currentUser?.reputationScore ?? 0), total: 500)
                .tint(.green)
            
            Text("120 points to Level 4")
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
                NavigationLink(destination: Text("All Contributions")) {
                    Text("See All")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            ForEach(0..<3) { _ in
                ContributionRow()
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
            
            Button(action: {}) {
                Text("Sign Out")
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
        }
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
                Text("Mountain Peak Vista")
                    .font(.footnote)
                    .fontWeight(.medium)
                Text("2 hours ago")
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

#Preview {
    ProfileView()
        .environmentObject(AppState())
}