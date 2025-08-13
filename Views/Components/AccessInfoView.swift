import SwiftUI

struct AccessInfoView: View {
    let difficulty: Spot.Difficulty
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Parking Available", systemImage: "car.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("Free street parking")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Text("Get Directions")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "figure.hiking")
                    Text("Trail Info")
                        .font(.footnote)
                        .fontWeight(.semibold)
                }
                
                HStack(spacing: 20) {
                    RouteItem(label: "Distance", value: "2.5 km")
                    RouteItem(label: "Elevation", value: "+120m")
                    RouteItem(label: "Time", value: "45 min")
                    RouteItem(label: "Difficulty", value: difficulty.displayName)
                }
            }
            
            if !hazards.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Label("Hazards", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    ForEach(hazards, id: \.self) { hazard in
                        Text("• \(hazard)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private let hazards = ["Steep cliffs", "Slippery when wet"]
}

struct RouteItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.footnote)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    AccessInfoView(difficulty: .moderate)
        .padding()
}