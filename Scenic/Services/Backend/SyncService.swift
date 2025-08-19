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
    
    // MARK: - Sync Down (Remote to Local)
    
    /// Fetch remote spots from Supabase and store them locally using incremental sync
    func syncRemoteSpotsToLocal() async {
        guard !isSyncing else {
            print("⚠️ Sync already in progress")
            return
        }
        
        // Rate limiting: Don't sync more than once every 5 minutes
        let minimumSyncInterval: TimeInterval = 5 * 60 // 5 minutes
        
        if !SyncTimestampManager.shared.shouldAllowSync(for: .spots, minimumInterval: minimumSyncInterval) {
            print("⏱️ Spots sync rate limited. Skipping sync.")
            return
        }
        
        isSyncing = true
        syncProgress = 0
        syncStatus = "Fetching remote spots..."
        syncErrors.removeAll()
        
        print("🔄 Starting sync down: Fetching remote spots from Supabase...")
        
        do {
            // Get the last sync timestamp for incremental sync
            let lastSyncTimestamp = SyncTimestampManager.shared.lastSpotsSync
            let syncStartTime = Date() // Record when this sync started
            
            if let lastSync = lastSyncTimestamp {
                print("🔄 Performing incremental sync: fetching spots updated since \(lastSync)")
                syncStatus = "Fetching spots updated since last sync..."
            } else {
                print("🔄 Performing initial sync: fetching all spots")
                syncStatus = "Fetching all spots (first time sync)..."
            }
            
            // Fetch spots from Supabase using incremental sync
            let remoteSpots = try await spotService.fetchSpots(
                limit: 1000,
                updatedSince: lastSyncTimestamp
            )
            
            // Debug first few spots' coordinates
            print("🗺️ DEBUG: First 3 remote spots coordinates:")
            for (index, spot) in remoteSpots.prefix(3).enumerated() {
                print("  [\(index)] \(spot.title): lat=\(spot.latitude), lng=\(spot.longitude)")
                print("    Are finite: lat=\(spot.latitude.isFinite), lng=\(spot.longitude.isFinite)")
                print("    Are NaN: lat=\(spot.latitude.isNaN), lng=\(spot.longitude.isNaN)")
            }
            
            guard !remoteSpots.isEmpty else {
                syncStatus = "No remote spots found"
                isSyncing = false
                print("ℹ️ No remote spots to sync")
                return
            }
            
            syncStatus = "Processing \(remoteSpots.count) remote spots..."
            print("📥 Found \(remoteSpots.count) remote spots to sync")
            
            let context = persistenceController.container.viewContext
            var newSpotsCount = 0
            
            for (index, remoteSpot) in remoteSpots.enumerated() {
                syncProgress = Double(index) / Double(remoteSpots.count)
                
                do {
                    // Check if spot already exists locally
                    let request: NSFetchRequest<CDSpot> = CDSpot.fetchRequest()
                    request.predicate = NSPredicate(format: "serverSpotId == %@", remoteSpot.id.uuidString)
                    
                    let existingSpots = try context.fetch(request)
                    
                    if existingSpots.isEmpty {
                        // Create new local spot from remote data
                        let cdSpot = createCDSpotFromRemoteSpot(remoteSpot, in: context)
                        
                        // Fetch and create media records for this spot
                        await fetchAndCreateMediaForSpot(cdSpot, spotId: remoteSpot.id, in: context)
                        
                        // Fetch and create sun snapshots for this spot
                        await fetchAndCreateSunSnapshotsForSpot(cdSpot, spotId: remoteSpot.id, in: context)
                        
                        newSpotsCount += 1
                        print("➕ Created local spot: \(remoteSpot.title)")
                    } else {
                        let existingSpot = existingSpots[0]
                        
                        // For incremental sync, update the existing spot with latest data
                        if lastSyncTimestamp != nil {
                            print("🔄 Updating existing spot: \(remoteSpot.title)")
                            updateCDSpotFromRemoteSpot(existingSpot, remoteSpot: remoteSpot)
                        } else {
                            print("⏭️ Spot already exists locally: \(remoteSpot.title)")
                        }
                        
                        // Check if existing spot has invalid coordinates and fix them
                        if existingSpot.latitude.isNaN || existingSpot.longitude.isNaN {
                            print("🔧 Fixing NaN coordinates for existing spot: \(remoteSpot.title)")
                            print("  Old coordinates: lat=\(existingSpot.latitude), lng=\(existingSpot.longitude)")
                            if remoteSpot.latitude.isFinite && remoteSpot.longitude.isFinite {
                                existingSpot.latitude = remoteSpot.latitude
                                existingSpot.longitude = remoteSpot.longitude
                                print("  New coordinates: lat=\(existingSpot.latitude), lng=\(existingSpot.longitude)")
                            } else {
                                print("  Using fallback coordinates")
                                existingSpot.latitude = 37.7749
                                existingSpot.longitude = -122.4194
                            }
                        }
                        
                        // Always fetch and update media for existing spots (to get enhanced metadata)
                        print("📸 Updating existing spot media with enhanced metadata...")
                        await fetchAndCreateMediaForSpot(existingSpot, spotId: remoteSpot.id, in: context)
                        
                        // Always sync sun snapshots for existing spots (they may have been added)
                        await fetchAndCreateSunSnapshotsForSpot(existingSpot, spotId: remoteSpot.id, in: context)
                    }
                    
                    syncStatus = "Processed \(index + 1) of \(remoteSpots.count) spots"
                } catch {
                    let errorMsg = "Failed to process remote spot '\(remoteSpot.title)': \(error.localizedDescription)"
                    syncErrors.append(errorMsg)
                    print("❌ \(errorMsg)")
                }
            }
            
            // Save all changes
            try context.save()
            syncProgress = 1.0
            
            if syncErrors.isEmpty {
                syncStatus = "✅ Successfully synced \(newSpotsCount) new remote spots"
                print("✅ Sync down completed: \(newSpotsCount) new spots added locally")
            } else {
                syncStatus = "⚠️ Synced with \(syncErrors.count) errors, added \(newSpotsCount) spots"
                print("⚠️ Sync down completed with \(syncErrors.count) errors")
            }
            
            // Record successful sync timestamp for incremental sync
            SyncTimestampManager.shared.updateLastSpotsSync(to: syncStartTime)
            
            // Also keep the old rate limiting mechanism for backward compatibility
            UserDefaults.standard.set(Date(), forKey: "lastSyncDownTime")
            
            // Post notification to reload spots
            await MainActor.run {
                NotificationCenter.default.post(name: .spotsDidSync, object: nil)
                print("🔄 Posted notification to reload spots after sync down")
            }
            
        } catch {
            syncStatus = "❌ Sync down failed: \(error.localizedDescription)"
            syncErrors.append(error.localizedDescription)
            print("❌ Sync down failed: \(error)")
        }
        
        isSyncing = false
    }
    
    /// Create a CDSpot from a remote SpotModel
    private func createCDSpotFromRemoteSpot(_ remoteSpot: SpotModel, in context: NSManagedObjectContext) -> CDSpot {
        let cdSpot = CDSpot(context: context)
        
        cdSpot.id = remoteSpot.id
        cdSpot.title = remoteSpot.title
        // Note: CDSpot doesn't have a description field yet - skipping for now
        // cdSpot.description = remoteSpot.description
        // Debug coordinate values from remote spot
        print("🗺️ DEBUG: Setting coordinates for '\(remoteSpot.title)':")
        print("  Remote latitude: \(remoteSpot.latitude)")
        print("  Remote longitude: \(remoteSpot.longitude)")
        print("  Are finite: lat=\(remoteSpot.latitude.isFinite), lng=\(remoteSpot.longitude.isFinite)")
        
        // Add safeguard against NaN coordinates
        if remoteSpot.latitude.isFinite && remoteSpot.longitude.isFinite {
            cdSpot.latitude = remoteSpot.latitude
            cdSpot.longitude = remoteSpot.longitude
        } else {
            print("❌ WARNING: Received non-finite coordinates for spot '\(remoteSpot.title)', using fallback")
            cdSpot.latitude = 37.7749  // San Francisco fallback
            cdSpot.longitude = -122.4194
        }
        
        // Verify what was actually stored
        print("  Stored latitude: \(cdSpot.latitude)")
        print("  Stored longitude: \(cdSpot.longitude)")
        print("  Location property: \(cdSpot.location)")
        cdSpot.headingDegrees = Int16(remoteSpot.headingDegrees ?? -1) // -1 means nil
        cdSpot.elevationMeters = Int16(remoteSpot.elevationMeters ?? -1) // -1 means nil
        cdSpot.subjectTags = remoteSpot.subjectTags
        cdSpot.difficulty = Int16(remoteSpot.difficulty)
        cdSpot.createdBy = remoteSpot.createdBy
        cdSpot.privacy = remoteSpot.privacy
        cdSpot.license = remoteSpot.license
        cdSpot.status = remoteSpot.status
        cdSpot.voteCount = Int32(remoteSpot.voteCount)
        cdSpot.createdAt = remoteSpot.createdAt
        cdSpot.updatedAt = remoteSpot.updatedAt
        cdSpot.serverSpotId = remoteSpot.id.uuidString // Mark as synced from server
        cdSpot.isLocalOnly = false // These are remote spots
        cdSpot.isPublished = true // Remote spots are already published
        
        return cdSpot
    }
    
    /// Update an existing CDSpot with data from a remote SpotModel
    private func updateCDSpotFromRemoteSpot(_ cdSpot: CDSpot, remoteSpot: SpotModel) {
        // Update all fields that might have changed
        cdSpot.title = remoteSpot.title
        
        // Update coordinates if they are valid
        if remoteSpot.latitude.isFinite && remoteSpot.longitude.isFinite {
            cdSpot.latitude = remoteSpot.latitude
            cdSpot.longitude = remoteSpot.longitude
        }
        
        cdSpot.headingDegrees = Int16(remoteSpot.headingDegrees ?? -1)
        cdSpot.elevationMeters = Int16(remoteSpot.elevationMeters ?? -1)
        cdSpot.subjectTags = remoteSpot.subjectTags
        cdSpot.difficulty = Int16(remoteSpot.difficulty)
        cdSpot.privacy = remoteSpot.privacy
        cdSpot.license = remoteSpot.license
        cdSpot.status = remoteSpot.status
        cdSpot.voteCount = Int32(remoteSpot.voteCount)
        cdSpot.updatedAt = remoteSpot.updatedAt
        
        print("🔄 Updated local spot data for: \(remoteSpot.title)")
    }
    
    /// Fetch media records from Supabase and create local CDMedia records
    private func fetchAndCreateMediaForSpot(_ cdSpot: CDSpot, spotId: UUID, in context: NSManagedObjectContext) async {
        do {
            // Fetch media records for this spot from Supabase
            let mediaRecords: [SupabaseMedia] = try await SupabaseManager.shared.client
                .from("media")
                .select("*")
                .eq("spot_id", value: spotId.uuidString)
                .execute()
                .value
            
            print("📸 Found \(mediaRecords.count) media records for spot: \(cdSpot.title)")
            
            for mediaRecord in mediaRecords {
                // Check if CDMedia record already exists
                let existingMediaRequest: NSFetchRequest<CDMedia> = CDMedia.fetchRequest()
                existingMediaRequest.predicate = NSPredicate(format: "id == %@", mediaRecord.id as CVarArg)
                
                let cdMedia: CDMedia
                let existingMedia = try context.fetch(existingMediaRequest)
                if let existing = existingMedia.first {
                    // Update existing record with enhanced metadata
                    cdMedia = existing
                    print("🔄 Updating existing media record: \(mediaRecord.cloudinarySecureUrl)")
                } else {
                    // Create new CDMedia record
                    cdMedia = CDMedia(context: context)
                    cdMedia.id = mediaRecord.id
                    cdMedia.createdAt = Date()
                    print("🆕 Creating new media record: \(mediaRecord.cloudinarySecureUrl)")
                }
                
                // Set/update all properties
                cdMedia.userId = mediaRecord.userId
                cdMedia.url = mediaRecord.cloudinarySecureUrl
                cdMedia.thumbnailUrl = generateCloudinaryThumbnailUrl(publicId: mediaRecord.cloudinaryPublicId)
                cdMedia.type = Media.MediaType.photo.rawValue
                cdMedia.spot = cdSpot
                
                // Initialize all numeric fields with -1 (nil indicators) to prevent crashes
                cdMedia.focalLengthMM = -1
                cdMedia.aperture = -1
                cdMedia.iso = -1
                cdMedia.resolutionWidth = -1
                cdMedia.resolutionHeight = -1
                cdMedia.headingFromExif = false
                
                // Initialize EXIF fields
                cdMedia.exifFocalLength = -1
                cdMedia.exifFNumber = -1
                cdMedia.exifIso = -1
                // Use original GPS coordinates from media record (stored from Flickr photo GPS data)
                cdMedia.exifGpsLatitude = mediaRecord.gpsLatitude ?? Double.nan
                cdMedia.exifGpsLongitude = mediaRecord.gpsLongitude ?? Double.nan
                cdMedia.exifGpsAltitude = Double.nan  // We don't have altitude data
                cdMedia.exifGpsDirection = -1
                cdMedia.exifWidth = -1
                cdMedia.exifHeight = -1
                
                // Server sync properties
                cdMedia.serverMediaId = mediaRecord.cloudinaryPublicId
                cdMedia.isDownloaded = false  // Remote media not downloaded locally
                cdMedia.thumbnailDownloaded = false
                cdMedia.lastSynced = Date()
                
                // Initialize JSON string fields
                cdMedia.presetsString = "[]"
                cdMedia.filtersString = "[]"
                
                // Map enhanced metadata from SupabaseMedia
                if let captureTimeString = mediaRecord.captureTimeUtc {
                    cdMedia.captureTimeUTC = ISO8601DateFormatter().date(from: captureTimeString)
                }
                
                // Map attribution and source information (only set if Core Data model supports it)
                if cdMedia.responds(to: #selector(setter: CDMedia.attributionText)) {
                    cdMedia.attributionText = mediaRecord.attributionText
                }
                if cdMedia.responds(to: #selector(setter: CDMedia.originalSource)) {
                    cdMedia.originalSource = mediaRecord.originalSource
                }
                if cdMedia.responds(to: #selector(setter: CDMedia.originalPhotoId)) {
                    cdMedia.originalPhotoId = mediaRecord.originalPhotoId
                }
                if cdMedia.responds(to: #selector(setter: CDMedia.licenseType)) {
                    cdMedia.licenseType = mediaRecord.licenseType
                }
                
                // Set dimensions if available (with bounds checking for Int32)
                if let width = mediaRecord.width {
                    cdMedia.resolutionWidth = width > Int32.max ? Int32.max : Int32(width)
                }
                if let height = mediaRecord.height {
                    cdMedia.resolutionHeight = height > Int32.max ? Int32.max : Int32(height)
                }
                
                print("✅ Processed media record: \(mediaRecord.cloudinarySecureUrl)")
                if cdMedia.captureTimeUTC != nil {
                    print("   📅 Capture time: \(cdMedia.captureTimeUTC!)")
                }
            }
            
        } catch {
            print("⚠️ Failed to fetch media for spot \(cdSpot.title): \(error)")
        }
    }
    
    /// Fetch sun snapshots from Supabase and create local CDSunSnapshot records
    private func fetchAndCreateSunSnapshotsForSpot(_ cdSpot: CDSpot, spotId: UUID, in context: NSManagedObjectContext) async {
        do {
            // Fetch sun snapshot records for this spot from Supabase
            struct SupabaseSunSnapshot: Codable {
                let id: UUID
                let spotId: UUID
                let date: String
                let sunriseUtc: String
                let sunsetUtc: String
                
                enum CodingKeys: String, CodingKey {
                    case id
                    case spotId = "spot_id"
                    case date
                    case sunriseUtc = "sunrise_utc"
                    case sunsetUtc = "sunset_utc"
                }
            }
            
            let sunSnapshots: [SupabaseSunSnapshot] = try await SupabaseManager.shared.client
                .from("sun_snapshots")
                .select("id, spot_id, date, sunrise_utc, sunset_utc")
                .eq("spot_id", value: spotId.uuidString)
                .execute()
                .value
            
            print("🌅 Found \(sunSnapshots.count) sun snapshots for spot: \(cdSpot.title)")
            
            for sunSnapshot in sunSnapshots {
                // Check if this sun snapshot already exists locally
                let existingRequest: NSFetchRequest<CDSunSnapshot> = CDSunSnapshot.fetchRequest()
                existingRequest.predicate = NSPredicate(format: "id == %@", sunSnapshot.id as CVarArg)
                
                let existingSnapshots = try context.fetch(existingRequest)
                if !existingSnapshots.isEmpty {
                    print("⏭️ Sun snapshot already exists locally: \(sunSnapshot.date)")
                    continue
                }
                
                // Create CDSunSnapshot record
                let cdSunSnapshot = CDSunSnapshot(context: context)
                cdSunSnapshot.id = sunSnapshot.id
                
                // Convert date string to Date object
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                cdSunSnapshot.date = dateFormatter.date(from: sunSnapshot.date) ?? Date()
                
                cdSunSnapshot.sunriseUTC = ISO8601DateFormatter().date(from: sunSnapshot.sunriseUtc)
                cdSunSnapshot.sunsetUTC = ISO8601DateFormatter().date(from: sunSnapshot.sunsetUtc)
                
                // Initialize required fields to prevent crashes
                cdSunSnapshot.relativeMinutesToEvent = Int32.max // Indicates nil value
                cdSunSnapshot.closestEventString = nil
                
                cdSunSnapshot.spot = cdSpot
                
                print("☀️ Created local sun snapshot: \(sunSnapshot.date)")
            }
            
        } catch {
            print("⚠️ Failed to fetch sun snapshots for spot \(cdSpot.title): \(error)")
        }
    }
    
    /// Generate Cloudinary thumbnail URL from public ID
    private func generateCloudinaryThumbnailUrl(publicId: String) -> String {
        // Use the same cloud name and generate a 150x150 thumbnail
        return "https://res.cloudinary.com/scenic-app/image/upload/c_thumb,w_150,h_150,g_auto,q_auto,f_auto/\(publicId)"
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

