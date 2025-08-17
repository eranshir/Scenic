import Foundation

/// Manages app configuration and environment variables
/// Reads from .env.local in debug, and Info.plist in release
class ConfigurationManager {
    static let shared = ConfigurationManager()
    
    private var config: [String: String] = [:]
    
    private init() {
        loadConfiguration()
    }
    
    private func loadConfiguration() {
        #if DEBUG
        // In debug, try to load from .env.local file
        loadFromEnvFile()
        #endif
        
        // Also load from Info.plist (for production or as fallback)
        loadFromInfoPlist()
    }
    
    private func loadFromEnvFile() {
        // Look for .env.local in the project directory
        let envPath = Bundle.main.path(forResource: ".env", ofType: "local") ??
                     FileManager.default.currentDirectoryPath + "/.env.local"
        
        guard let envString = try? String(contentsOfFile: envPath, encoding: .utf8) else {
            print("⚠️ No .env.local file found at \(envPath)")
            return
        }
        
        // Parse the env file
        envString.enumerateLines { line, _ in
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip comments and empty lines
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                return
            }
            
            // Parse KEY=VALUE format
            let parts = trimmedLine.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                self.config[key] = value
            }
        }
        
        print("✅ Loaded \(config.count) configuration values from .env.local")
    }
    
    private func loadFromInfoPlist() {
        guard let infoDict = Bundle.main.infoDictionary else { return }
        
        // Map Info.plist keys to our config keys
        let mappings = [
            "SUPABASE_URL": "SupabaseURL",
            "SUPABASE_ANON_KEY": "SupabaseAnonKey",
            "CLOUDINARY_CLOUD_NAME": "CloudinaryCloudName",
            "CLOUDINARY_API_KEY": "CloudinaryAPIKey"
        ]
        
        for (envKey, plistKey) in mappings {
            if let value = infoDict[plistKey] as? String {
                // Only override if not already set from env file
                if config[envKey] == nil {
                    config[envKey] = value
                }
            }
        }
    }
    
    // MARK: - Public Accessors
    
    /// Get a configuration value
    func get(_ key: String) -> String? {
        return config[key]
    }
    
    /// Get a configuration value with a default
    func get(_ key: String, default defaultValue: String) -> String {
        return config[key] ?? defaultValue
    }
    
    /// Check if a feature flag is enabled
    func isFeatureEnabled(_ feature: String) -> Bool {
        let key = "ENABLE_\(feature.uppercased())"
        return config[key]?.lowercased() == "true"
    }
    
    // MARK: - Convenience Properties
    
    var supabaseURL: String {
        guard let url = get("SUPABASE_URL") else {
            fatalError("SUPABASE_URL not configured")
        }
        return url
    }
    
    var supabaseAnonKey: String {
        guard let key = get("SUPABASE_ANON_KEY") else {
            fatalError("SUPABASE_ANON_KEY not configured")
        }
        return key
    }
    
    var supabaseServiceKey: String? {
        return get("SUPABASE_SERVICE_KEY")
    }
    
    var cloudinaryCloudName: String {
        guard let name = get("CLOUDINARY_CLOUD_NAME") else {
            fatalError("CLOUDINARY_CLOUD_NAME not configured")
        }
        return name
    }
    
    var cloudinaryAPIKey: String {
        guard let key = get("CLOUDINARY_API_KEY") else {
            fatalError("CLOUDINARY_API_KEY not configured")
        }
        return key
    }
    
    var cloudinaryAPISecret: String? {
        return get("CLOUDINARY_API_SECRET")
    }
    
    var cloudinaryUploadPreset: String {
        return get("CLOUDINARY_UPLOAD_PRESET", default: "scenic_mobile")
    }
    
    var isDebugMode: Bool {
        return get("DEBUG_MODE")?.lowercased() == "true"
    }
    
    var environment: String {
        return get("ENVIRONMENT", default: "production")
    }
    
    // MARK: - Feature Flags
    
    var isOfflineModeEnabled: Bool {
        return isFeatureEnabled("OFFLINE_MODE")
    }
    
    var isSocialFeaturesEnabled: Bool {
        return isFeatureEnabled("SOCIAL_FEATURES")
    }
    
    var isPlanningFeaturesEnabled: Bool {
        return isFeatureEnabled("PLANNING_FEATURES")
    }
    
    var isPaymentFeaturesEnabled: Bool {
        return isFeatureEnabled("PAYMENT_FEATURES")
    }
    
    var isAIFeaturesEnabled: Bool {
        return isFeatureEnabled("AI_FEATURES")
    }
    
    var isWeatherIntegrationEnabled: Bool {
        return isFeatureEnabled("WEATHER_INTEGRATION")
    }
    
    var isAnalyticsEnabled: Bool {
        return isFeatureEnabled("ANALYTICS")
    }
}

// MARK: - Usage Example
/*
 let config = ConfigurationManager.shared
 
 // Get Supabase URL
 let supabaseURL = config.supabaseURL
 
 // Check feature flag
 if config.isPlanningFeaturesEnabled {
     // Show planning features
 }
 
 // Get custom value
 let apiKey = config.get("CUSTOM_API_KEY") ?? "default"
*/