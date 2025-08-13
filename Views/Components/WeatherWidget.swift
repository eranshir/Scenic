import SwiftUI

struct WeatherWidget: View {
    var body: some View {
        HStack(spacing: 16) {
            WeatherItem(icon: "thermometer", value: "18°C", label: "Temp")
            WeatherItem(icon: "cloud", value: "25%", label: "Clouds")
            WeatherItem(icon: "wind", value: "5 m/s", label: "Wind")
            WeatherItem(icon: "eye", value: "10 km", label: "Visibility")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct WeatherItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
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
    WeatherWidget()
        .padding()
}