import SwiftUI

struct SpotListView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(mockSpots) { spot in
                    NavigationLink(destination: SpotDetailView(spot: spot)) {
                        SpotListCard(spot: spot)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct SpotListCard: View {
    let spot: Spot
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color.green.opacity(0.6), Color.blue.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(height: 200)
                
                VStack(alignment: .leading) {
                    HStack {
                        ForEach(spot.subjectTags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                    }
                    .padding()
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(spot.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Label(spot.difficulty.displayName, systemImage: "figure.hiking")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.caption)
                        Text("\(spot.voteCount)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                            .font(.caption)
                        Text("\(spot.comments.count)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                if let snapshot = spot.sunSnapshot {
                    HStack(spacing: 12) {
                        if let sunrise = snapshot.sunriseUTC {
                            Label(formatTime(sunrise), systemImage: "sunrise.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        if let sunset = snapshot.sunsetUTC {
                            Label(formatTime(sunset), systemImage: "sunset.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                if let weather = spot.weatherSnapshot {
                    HStack(spacing: 8) {
                        Image(systemName: weather.weatherIcon)
                            .font(.caption)
                        if let temp = weather.temperatureCelsius {
                            Text("\(Int(temp))°C")
                                .font(.caption)
                        }
                        if let clouds = weather.cloudCoveragePercent {
                            Text("\(clouds)% clouds")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        SpotListView()
            .environmentObject(AppState())
    }
}