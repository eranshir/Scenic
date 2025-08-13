import SwiftUI

struct ExifDataView: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Camera")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Canon EOS R5")
                        .font(.footnote)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Lens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("RF 24-70mm f/2.8")
                        .font(.footnote)
                        .fontWeight(.medium)
                }
            }
            
            Divider()
            
            HStack(spacing: 20) {
                ExifItem(label: "Focal", value: "35mm")
                ExifItem(label: "Aperture", value: "f/8")
                ExifItem(label: "Shutter", value: "1/125s")
                ExifItem(label: "ISO", value: "100")
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Resolution")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("8192 × 5464")
                        .font(.footnote)
                        .fontDesign(.monospaced)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Captured")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("2 hours ago")
                        .font(.footnote)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ExifItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.footnote)
                .fontWeight(.semibold)
                .fontDesign(.monospaced)
        }
    }
}

#Preview {
    ExifDataView()
        .padding()
}