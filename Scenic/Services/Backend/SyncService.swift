import Foundation
import SwiftUI
import CoreData
import Supabase
import CoreLocation

/// Service for syncing local Core Data spots with remote Supabase backend
@MainActor
class SyncService: ObservableObject {
    static let shared = SyncService()
    
    @Published var isSyncing = false
    @Published var syncProgress: Double = 0
    @Published var syncStatus: String = ""
    @Published var syncErrors: [String] = []
    
    private let spotService = SpotService.shared
    private let mediaService = MediaService.shared
    private let persistenceController = PersistenceController.shared
    
    private init() {}
    
    // MARK: - Sync Operations
    
    /// Sync all local spots that haven't been uploaded to Supabase
    func syncLocalSpotsToSupabase() async {
        guard !isSyncing else {
            print("⚠️ Sync already in progress, skipping automatic sync")
            return
        }
        
        isSyncing = true
        syncProgress = 0
        syncStatus = "Starting automatic sync..."
        syncErrors.removeAll()
        
        print("🔄 Starting automatic background sync...")
        
        do {
            // Fetch all local spots that don't have a remote ID
            let localSpots = try await fetchUnsyncedSpots()
            
            guard !localSpots.isEmpty else {
                syncStatus = "All spots are already synced"
                isSyncing = false
                return
            }
            
            syncStatus = "Found \(localSpots.count) spots to sync"
            
            for (index, cdSpot) in localSpots.enumerated() {
                syncProgress = Double(index) / Double(localSpots.count)
                
                do {
                    try await syncSpot(cdSpot)
                    syncStatus = "Synced \(index + 1) of \(localSpots.count) spots"
                } catch {
                    let errorMsg = "Failed to sync spot '\(cdSpot.title)': \(error.localizedDescription)"
                    syncErrors.append(errorMsg)
                    print("❌ \(errorMsg)")
                }
            }
            
            syncProgress = 1.0
            
            if syncErrors.isEmpty {
                syncStatus = "✅ Successfully synced \(localSpots.count) spots"
                print("✅ Automatic sync completed successfully: \(localSpots.count) spot(s) uploaded")
            } else {
                syncStatus = "⚠️ Synced with \(syncErrors.count) errors"
                print("⚠️ Automatic sync completed with \(syncErrors.count) errors")
            }
            
            // Post notification to reload spots
            await MainActor.run {
                NotificationCenter.default.post(name: .spotsDidSync, object: nil)
                print("🔄 Posted notification to reload spots after sync")
            }
            
        } catch {
            syncStatus = "❌ Sync failed: \(error.localizedDescription)"
            syncErrors.append(error.localizedDescription)
        }
        
        isSyncing = false
    }
    
    /// Sync a single spot with its media
    private func syncSpot(_ cdSpot: CDSpot) async throws {
        print("🔄 Syncing spot: \(cdSpot.title)")
        
        // Check if this spot has already been synced by looking for serverSpotId
        if let serverSpotId = cdSpot.serverSpotId, !serverSpotId.isEmpty {
            print("⚠️ Spot already synced with ID: \(serverSpotId)")
            
            // Just sync any remaining local media
            if let mediaSet = cdSpot.media as? Set<CDMedia>, !mediaSet.isEmpty {
                let localMedia = mediaSet.filter { $0.url.hasPrefix("local_") }
                if !localMedia.isEmpty {
                    print("📸 Found \(localMedia.count) local media items to sync...")
                    guard let spotId = UUID(uuidString: serverSpotId) else {
                        throw SyncError.invalidSpotData
                    }
                    
                    for cdMedia in localMedia {
                        do {
                            try await uploadMediaItem(cdMedia, spotId: spotId)
                        } catch {
                            print("⚠️ Failed to upload media: \(error)")
                        }
                    }
                }
            }
            return
        }
        
        // 1. Create spot in Supabase
        let location = CLLocationCoordinate2D(
            latitude: cdSpot.latitude,
            longitude: cdSpot.longitude
        )
        
        let spotModel = try await spotService.createSpot(
            title: cdSpot.title,
            location: location,
            description: nil,  // CDSpot doesn't have notes field
            headingDegrees: cdSpot.headingDegrees > 0 ? Int(cdSpot.headingDegrees) : nil,
            elevationMeters: cdSpot.elevationMeters > 0 ? Int(cdSpot.elevationMeters) : nil,
            subjectTags: cdSpot.subjectTags,
            difficulty: Int(cdSpot.difficulty),
            privacy: cdSpot.privacy
        )
        
        print("✅ Created spot in Supabase with ID: \(spotModel.id)")
        
        // 2. Upload media to Cloudinary
        if let mediaSet = cdSpot.media as? Set<CDMedia>, !mediaSet.isEmpty {
            let mediaArray = Array(mediaSet)
            print("📸 Uploading \(mediaArray.count) media items...")
            
            for cdMedia in mediaArray {
                do {
                    try await uploadMediaItem(cdMedia, spotId: spotModel.id)
                } catch {
                    print("⚠️ Failed to upload media: \(error)")
                    // Continue with other media items even if one fails
                }
            }
        }
        
        // 3. Update local spot with remote ID
        try await updateLocalSpotWithRemoteId(cdSpot, remoteId: spotModel.id)
    }
    
    /// Upload a single media item to Cloudinary and create record in Supabase
    private func uploadMediaItem(_ cdMedia: CDMedia, spotId: UUID) async throws {
        // Check if media uses local URL (starts with "local_")
        guard cdMedia.url.hasPrefix("local_") else {
            print("⚠️ Media already has remote URL or invalid local URL: \(cdMedia.url)")
            return
        }
        
        // Extract the local ID from the URL
        let localId = cdMedia.url.replacingOccurrences(of: "local_", with: "")
        
        // Load image from cache
        guard let image = loadImageFromCache(localId: localId) else {
            print("❌ Image not found in cache for ID: \(localId)")
            throw SyncError.imageNotFoundInCache(localId)
        }
        
        print("📤 Uploading image \(localId) to Cloudinary (spot: \(spotId.uuidString))...")
        
        // Upload to Cloudinary with error handling
        let cloudinaryResult: CloudinaryUploadResult
        do {
            cloudinaryResult = try await CloudinaryManager.shared.uploadImage(
                image,
                spotId: spotId.uuidString
            )
        } catch {
            print("❌ Cloudinary upload failed: \(error.localizedDescription)")
            throw SyncError.uploadFailed("Cloudinary error: \(error.localizedDescription)")
        }
        
        print("✅ Uploaded to Cloudinary: \(cloudinaryResult.publicId)")
        print("   - Secure URL: \(cloudinaryResult.secureUrl)")
        
        // Create media record in Supabase
        struct MediaInsertWithAllFields: Encodable {
            let spot_id: String
            let user_id: String
            let cloudinary_public_id: String
            let cloudinary_url: String
            let cloudinary_secure_url: String
            let thumbnail_url: String?
            let optimized_url: String?
            let type: String
            let width: Int?
            let height: Int?
            let format: String?
            let capture_time_utc: String?
        }
        
        let userId = try await supabase.auth.session.user.id.uuidString
        
        let mediaInsert = MediaInsertWithAllFields(
            spot_id: spotId.uuidString,
            user_id: userId,
            cloudinary_public_id: cloudinaryResult.publicId,
            cloudinary_url: cloudinaryResult.url.isEmpty ? cloudinaryResult.secureUrl : cloudinaryResult.url,
            cloudinary_secure_url: cloudinaryResult.secureUrl,
            thumbnail_url: cloudinaryResult.thumbnailUrl,
            optimized_url: cloudinaryResult.optimizedUrl,
            type: "photo",
            width: cloudinaryResult.width > 0 ? cloudinaryResult.width : nil,
            height: cloudinaryResult.height > 0 ? cloudinaryResult.height : nil,
            format: cloudinaryResult.format.isEmpty ? nil : cloudinaryResult.format,
            capture_time_utc: cdMedia.captureTimeUTC?.ISO8601Format()
        )
        
        do {
            _ = try await supabase
                .from("media")
                .insert(mediaInsert)
                .execute()
            print("✅ Created media record in Supabase")
        } catch {
            print("⚠️ Failed to create media record in Supabase: \(error)")
            // Don't throw - media is uploaded to Cloudinary, just Supabase record failed
        }
        
        // Update local media with remote URL
        await MainActor.run {
            cdMedia.url = cloudinaryResult.secureUrl
            cdMedia.serverMediaId = cloudinaryResult.publicId
            cdMedia.lastSynced = Date()
            cdMedia.thumbnailUrl = cloudinaryResult.thumbnailUrl
            
            do {
                try persistenceController.container.viewContext.save()
                print("✅ Updated local media with remote URL: \(cloudinaryResult.secureUrl)")
            } catch {
                print("⚠️ Failed to update local media: \(error)")
            }
        }
    }
    
    /// Load image from local cache
    private func loadImageFromCache(localId: String) -> UIImage? {
        _ = PhotoCacheService.shared
        let fileName = "\(localId).jpg"
        
        guard let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        
        let fileURL = documentsDirectory
            .appendingPathComponent("PhotoCache")
            .appendingPathComponent(fileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let imageData = try? Data(contentsOf: fileURL),
              let image = UIImage(data: imageData) else {
            print("❌ Failed to load image from cache: \(fileName)")
            return nil
        }
        
        print("✅ Loaded image from cache: \(fileName)")
        return image
    }
    
    // MARK: - Core Data Operations
    
    /// Fetch spots that haven't been synced to Supabase
    private func fetchUnsyncedSpots() async throws -> [CDSpot] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<CDSpot> = CDSpot.fetchRequest()
        
        // For now, fetch all spots since we don't have syncedAt field in Core Data model
        // In production, you'd need to add these fields to the .xcdatamodel file in Xcode
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        // Filter spots that have local URLs (not synced)
        let allSpots = try context.fetch(request)
        return allSpots.filter { spot in
            // Check if spot has local media (not synced)
            if let mediaSet = spot.media as? Set<CDMedia> {
                // Only sync if ALL media still have local URLs
                // If any media has a Cloudinary URL, the spot has been synced
                let hasLocalMedia = mediaSet.contains { media in
                    media.url.hasPrefix("local_")
                }
                let hasCloudinaryMedia = mediaSet.contains { media in
                    media.url.contains("cloudinary") || media.url.contains("res.cloudinary.com")
                }
                
                // Only sync if has local media AND no Cloudinary media
                return hasLocalMedia && !hasCloudinaryMedia
            }
            // Spots without media shouldn't be synced repeatedly
            return false
        }
    }
    
    /// Update local spot with remote ID after successful sync
    private func updateLocalSpotWithRemoteId(_ cdSpot: CDSpot, remoteId: UUID) async throws {
        await MainActor.run {
            // Store the remote ID in serverSpotId field
            cdSpot.serverSpotId = remoteId.uuidString
            cdSpot.isPublished = true
            cdSpot.lastSynced = Date()
            
            do {
                try persistenceController.container.viewContext.save()
                print("✅ Updated local spot with remote ID: \(remoteId)")
            } catch {
                print("❌ Failed to update local spot: \(error)")
            }
        }
    }
    
    // MARK: - Sync Status
    
    /// Check if there are any unsynced spots
    func checkSyncStatus() async -> SyncStatus {
        do {
            let unsyncedSpots = try await fetchUnsyncedSpots()
            let unsyncedCount = unsyncedSpots.count
            
            if unsyncedCount == 0 {
                return .synced
            } else {
                return .pending(count: unsyncedCount)
            }
        } catch {
            return .error(message: error.localizedDescription)
        }
    }
    
    /// Delete local spot and its remote counterpart
    func deleteSpotWithSync(_ cdSpot: CDSpot) async throws {
        // Note: Since we don't have remoteId field in Core Data yet,
        // we can't delete from Supabase. This needs to be implemented
        // after adding the field to the Core Data model in Xcode
        
        // Delete local spot
        let context = persistenceController.container.viewContext
        context.delete(cdSpot)
        try context.save()
        print("✅ Deleted local spot")
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let spotsDidSync = Notification.Name("spotsDidSync")
}

// MARK: - Supporting Types

enum SyncStatus {
    case synced
    case pending(count: Int)
    case syncing
    case error(message: String)
    
    var displayText: String {
        switch self {
        case .synced:
            return "All spots synced"
        case .pending(let count):
            return "\(count) spots pending sync"
        case .syncing:
            return "Syncing..."
        case .error(let message):
            return "Sync error: \(message)"
        }
    }
    
    var needsSync: Bool {
        switch self {
        case .pending:
            return true
        default:
            return false
        }
    }
}

enum SyncError: LocalizedError {
    case notAuthenticated
    case imageNotFoundInCache(String)
    case uploadFailed(String)
    case invalidSpotData
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to sync spots"
        case .imageNotFoundInCache(let id):
            return "Image not found in cache: \(id)"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .invalidSpotData:
            return "Invalid spot data"
        }
    }
}

