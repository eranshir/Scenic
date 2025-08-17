import SwiftUI

struct TestConnectionView: View {
    @StateObject private var supabase = SupabaseManager.shared
    @StateObject private var cloudinary = CloudinaryManager.shared
    
    @State private var supabaseStatus = "Not tested"
    @State private var cloudinaryStatus = "Not tested"
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Service Connection Test")
                .font(.largeTitle)
                .bold()
            
            // Supabase Test
            VStack(alignment: .leading, spacing: 10) {
                Text("Supabase")
                    .font(.headline)
                
                Text("URL: https://joamynsevhhhiwynidxp.supabase.co")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Status: \(supabaseStatus)")
                    .foregroundColor(statusColor(supabaseStatus))
                
                Button("Test Supabase Connection") {
                    testSupabase()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Cloudinary Test
            VStack(alignment: .leading, spacing: 10) {
                Text("Cloudinary")
                    .font(.headline)
                
                Text("Cloud Name: scenic-app")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Status: \(cloudinaryStatus)")
                    .foregroundColor(statusColor(cloudinaryStatus))
                
                Button("Test Cloudinary Config") {
                    testCloudinary()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func testSupabase() {
        Task {
            isLoading = true
            supabaseStatus = "Testing..."
            
            do {
                // Test connection using Supabase client
                try await supabase.testConnection()
                
                supabaseStatus = "✅ Connected successfully!"
            } catch {
                supabaseStatus = "❌ Error: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    private func testCloudinary() {
        cloudinaryStatus = "Testing..."
        
        // Test by generating a URL
        let testUrl = cloudinary.generateThumbnailUrl(publicId: "test")
        
        if testUrl.contains("scenic-app") {
            cloudinaryStatus = "✅ Configuration valid!"
        } else {
            cloudinaryStatus = "❌ Configuration error"
        }
    }
    
    private func statusColor(_ status: String) -> Color {
        if status.contains("✅") {
            return .green
        } else if status.contains("❌") {
            return .red
        } else if status.contains("Testing") {
            return .orange
        } else {
            return .primary
        }
    }
}

#Preview {
    TestConnectionView()
}