import SwiftUI

struct SunTimesWidget: View {
    @State private var currentTime = Date()
    
    let sunrise = Calendar.current.date(bySettingHour: 6, minute: 45, second: 0, of: Date())!
    let sunset = Calendar.current.date(bySettingHour: 18, minute: 30, second: 0, of: Date())!
    let goldenHourStart = Calendar.current.date(bySettingHour: 17, minute: 30, second: 0, of: Date())!
    let goldenHourEnd = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date())!
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                SunTimeRow(icon: "sunrise.fill", label: "Sunrise", time: sunrise, color: .orange)
                Spacer()
                SunTimeRow(icon: "sunset.fill", label: "Sunset", time: sunset, color: .orange)
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Label("Golden Hour", systemImage: "sun.max.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("\(formatTime(goldenHourStart)) - \(formatTime(goldenHourEnd))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Label("Blue Hour", systemImage: "moon.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("18:30 - 19:15")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SunTimeRow: View {
    let icon: String
    let label: String
    let time: Date
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(formatTime(time))
                .font(.footnote)
                .fontWeight(.medium)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    SunTimesWidget()
        .padding()
}