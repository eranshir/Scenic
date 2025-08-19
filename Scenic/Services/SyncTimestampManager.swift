import Foundation

/// Manages sync timestamps for incremental data synchronization
class SyncTimestampManager {
    static let shared = SyncTimestampManager()
    
    private init() {}
    
    // MARK: - UserDefaults Keys
    
    private enum Keys {
        static let lastSpotsSync = "lastSpotsSync"
        static let lastMediaSync = "lastMediaSync"
        static let lastSunSnapshotsSync = "lastSunSnapshotsSync"
        static let lastWeatherSnapshotsSync = "lastWeatherSnapshotsSync"
        static let lastAccessInfoSync = "lastAccessInfoSync"
        static let lastPlansSync = "lastPlansSync"
    }
    
    // MARK: - Spots Sync
    
    var lastSpotsSync: Date? {
        get {
            UserDefaults.standard.object(forKey: Keys.lastSpotsSync) as? Date
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date, forKey: Keys.lastSpotsSync)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.lastSpotsSync)
            }
        }
    }
    
    func updateLastSpotsSync(to date: Date = Date()) {
        lastSpotsSync = date
        print("📅 Updated last spots sync timestamp to: \(date)")
    }
    
    // MARK: - Media Sync
    
    var lastMediaSync: Date? {
        get {
            UserDefaults.standard.object(forKey: Keys.lastMediaSync) as? Date
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date, forKey: Keys.lastMediaSync)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.lastMediaSync)
            }
        }
    }
    
    func updateLastMediaSync(to date: Date = Date()) {
        lastMediaSync = date
        print("📅 Updated last media sync timestamp to: \(date)")
    }
    
    // MARK: - Sun Snapshots Sync
    
    var lastSunSnapshotsSync: Date? {
        get {
            UserDefaults.standard.object(forKey: Keys.lastSunSnapshotsSync) as? Date
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date, forKey: Keys.lastSunSnapshotsSync)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.lastSunSnapshotsSync)
            }
        }
    }
    
    func updateLastSunSnapshotsSync(to date: Date = Date()) {
        lastSunSnapshotsSync = date
        print("📅 Updated last sun snapshots sync timestamp to: \(date)")
    }
    
    // MARK: - Weather Snapshots Sync
    
    var lastWeatherSnapshotsSync: Date? {
        get {
            UserDefaults.standard.object(forKey: Keys.lastWeatherSnapshotsSync) as? Date
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date, forKey: Keys.lastWeatherSnapshotsSync)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.lastWeatherSnapshotsSync)
            }
        }
    }
    
    func updateLastWeatherSnapshotsSync(to date: Date = Date()) {
        lastWeatherSnapshotsSync = date
        print("📅 Updated last weather snapshots sync timestamp to: \(date)")
    }
    
    // MARK: - Access Info Sync
    
    var lastAccessInfoSync: Date? {
        get {
            UserDefaults.standard.object(forKey: Keys.lastAccessInfoSync) as? Date
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date, forKey: Keys.lastAccessInfoSync)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.lastAccessInfoSync)
            }
        }
    }
    
    func updateLastAccessInfoSync(to date: Date = Date()) {
        lastAccessInfoSync = date
        print("📅 Updated last access info sync timestamp to: \(date)")
    }
    
    // MARK: - Plans Sync
    
    var lastPlansSync: Date? {
        get {
            UserDefaults.standard.object(forKey: Keys.lastPlansSync) as? Date
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date, forKey: Keys.lastPlansSync)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.lastPlansSync)
            }
        }
    }
    
    func updateLastPlansSync(to date: Date = Date()) {
        lastPlansSync = date
        print("📅 Updated last plans sync timestamp to: \(date)")
    }
    
    // MARK: - Utility Methods
    
    /// Clear all sync timestamps (useful for debugging or full resync)
    func clearAllTimestamps() {
        lastSpotsSync = nil
        lastMediaSync = nil
        lastSunSnapshotsSync = nil
        lastWeatherSnapshotsSync = nil
        lastAccessInfoSync = nil
        lastPlansSync = nil
        print("🗑️ Cleared all sync timestamps")
    }
    
    /// Get summary of all sync timestamps
    func getSyncSummary() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        var summary = "Sync Timestamps:\n"
        summary += "• Spots: \(lastSpotsSync.map { formatter.string(from: $0) } ?? "Never")\n"
        summary += "• Media: \(lastMediaSync.map { formatter.string(from: $0) } ?? "Never")\n"
        summary += "• Sun Snapshots: \(lastSunSnapshotsSync.map { formatter.string(from: $0) } ?? "Never")\n"
        summary += "• Weather Snapshots: \(lastWeatherSnapshotsSync.map { formatter.string(from: $0) } ?? "Never")\n"
        summary += "• Access Info: \(lastAccessInfoSync.map { formatter.string(from: $0) } ?? "Never")\n"
        summary += "• Plans: \(lastPlansSync.map { formatter.string(from: $0) } ?? "Never")"
        
        return summary
    }
    
    /// Check if enough time has passed since last sync (for rate limiting)
    func shouldAllowSync(for syncType: SyncType, minimumInterval: TimeInterval = 300) -> Bool {
        let lastSync: Date?
        
        switch syncType {
        case .spots:
            lastSync = lastSpotsSync
        case .media:
            lastSync = lastMediaSync
        case .sunSnapshots:
            lastSync = lastSunSnapshotsSync
        case .weatherSnapshots:
            lastSync = lastWeatherSnapshotsSync
        case .accessInfo:
            lastSync = lastAccessInfoSync
        case .plans:
            lastSync = lastPlansSync
        }
        
        guard let lastSyncTime = lastSync else {
            return true // Never synced before
        }
        
        let timeSinceLastSync = Date().timeIntervalSince(lastSyncTime)
        return timeSinceLastSync >= minimumInterval
    }
}

// MARK: - Supporting Types

enum SyncType {
    case spots
    case media
    case sunSnapshots
    case weatherSnapshots
    case accessInfo
    case plans
}