import Foundation
import CoreData
import SwiftUI
import CoreLocation

@MainActor
class SpotDataService: ObservableObject {
    private let persistenceController: PersistenceController
    private var viewContext: NSManagedObjectContext {
        persistenceController.container.viewContext
    }
    
    @Published var spots: [Spot] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    init(persistenceController: PersistenceController = PersistenceController.shared) {
        self.persistenceController = persistenceController
        loadSpots()
    }
    
    // MARK: - Spot Operations
    
    func clearAllSpots() {
        do {
            let request: NSFetchRequest<CDSpot> = CDSpot.fetchRequest()
            let spots = try viewContext.fetch(request)
            
            for spot in spots {
                viewContext.delete(spot)
            }
            
            try viewContext.save()
            
            // Also clear photo cache
            PhotoCacheService.shared.clearCache()
            
            loadSpots() // Refresh
            print("✅ Cleared all spots and cached photos")
        } catch {
            self.error = error
            print("❌ Failed to clear spots: \(error)")
        }
    }
    
    func cleanupPhotoIdentifiers() {
        do {
            let request: NSFetchRequest<CDMedia> = CDMedia.fetchRequest()
            let mediaItems = try viewContext.fetch(request)
            
            var updatedCount = 0
            
            for media in mediaItems {
                guard let currentUrl = media.url else { continue }
                
                let cleanedUrl: String
                if currentUrl.hasPrefix("photo_") {
                    cleanedUrl = "local_" + currentUrl.replacingOccurrences(of: "photo_", with: "")
                } else if !currentUrl.hasPrefix("local_") && isValidUUID(currentUrl) {
                    cleanedUrl = "local_" + currentUrl
                } else {
                    continue // Already properly formatted
                }
                
                media.url = cleanedUrl
                updatedCount += 1
                print("🔄 Updated photo identifier: \(currentUrl) -> \(cleanedUrl)")
            }
            
            if updatedCount > 0 {
                try viewContext.save()
                loadSpots() // Refresh
                print("✅ Updated \(updatedCount) photo identifiers")
            } else {
                print("✅ All photo identifiers are already properly formatted")
            }
        } catch {
            self.error = error
            print("❌ Failed to cleanup photo identifiers: \(error)")
        }
    }
    
    private func isValidUUID(_ string: String) -> Bool {
        return UUID(uuidString: string) != nil
    }
    
    func loadSpots() {
        isLoading = true
        error = nil
        
        do {
            let request: NSFetchRequest<CDSpot> = CDSpot.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \CDSpot.updatedAt, ascending: false)]
            // Include relationships to avoid faulting
            request.relationshipKeyPathsForPrefetching = ["media", "sunSnapshot", "weatherSnapshot", "accessInfo"]
            
            let cdSpots = try viewContext.fetch(request)
            print("🎯 Loaded \(cdSpots.count) CDSpots from database")
            spots = cdSpots.map { cdSpot in
                print("📦 Processing CDSpot: \(cdSpot.title ?? "Unknown")")
                return convertCDSpotToSpot(cdSpot)
            }
            print("🏁 Final spots array has \(spots.count) spots")
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
            print("Failed to load spots: \(error)")
        }
    }
    
    func saveSpot(_ spot: Spot) {
        do {
            // Check if spot already exists
            let request: NSFetchRequest<CDSpot> = CDSpot.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", spot.id as CVarArg)
            
            let existingSpots = try viewContext.fetch(request)
            
            let cdSpot: CDSpot
            if let existing = existingSpots.first {
                // Update existing
                updateCDSpotFromSpot(existing, spot: spot)
                existing.updatedAt = Date()
                cdSpot = existing
            } else {
                // Create new
                cdSpot = createCDSpotFromSpot(spot, in: viewContext)
                cdSpot.updatedAt = Date()
            }
            
            // Handle media relationships
            print("📸 Saving \(spot.media.count) media items for spot '\(spot.title)'")
            for (index, media) in spot.media.enumerated() {
                print("📷 Saving media \(index + 1): \(media.url)")
                saveMedia(media, to: cdSpot)
            }
            
            // Handle other relationships
            if let sunSnapshot = spot.sunSnapshot {
                saveSunSnapshot(sunSnapshot, to: cdSpot)
            }
            
            if let weatherSnapshot = spot.weatherSnapshot {
                saveWeatherSnapshot(weatherSnapshot, to: cdSpot)
            }
            
            if let accessInfo = spot.accessInfo {
                saveAccessInfo(accessInfo, to: cdSpot)
            }
            
            try viewContext.save()
            loadSpots() // Refresh the spots array
            
            print("✅ Saved spot: \(spot.title)")
        } catch {
            self.error = error
            print("❌ Failed to save spot: \(error)")
        }
    }
    
    func deleteSpot(_ spot: Spot) {
        do {
            let request: NSFetchRequest<CDSpot> = CDSpot.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", spot.id as CVarArg)
            
            let cdSpots = try viewContext.fetch(request)
            for cdSpot in cdSpots {
                viewContext.delete(cdSpot)
            }
            
            try viewContext.save()
            loadSpots()
            
            print("✅ Deleted spot: \(spot.title)")
        } catch {
            self.error = error
            print("❌ Failed to delete spot: \(error)")
        }
    }
    
    func getSpot(by id: UUID) -> Spot? {
        return spots.first { $0.id == id }
    }
    
    // MARK: - Search and Filter
    
    func searchSpots(query: String) -> [Spot] {
        if query.isEmpty {
            return spots
        }
        
        return spots.filter { spot in
            spot.title.localizedCaseInsensitiveContains(query) ||
            spot.subjectTags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
    
    func filterSpots(
        difficulty: Spot.Difficulty? = nil,
        tags: [String] = [],
        nearLocation: (latitude: Double, longitude: Double, radiusKM: Double)? = nil
    ) -> [Spot] {
        var filteredSpots = spots
        
        // Filter by difficulty
        if let difficulty = difficulty {
            filteredSpots = filteredSpots.filter { $0.difficulty == difficulty }
        }
        
        // Filter by tags
        if !tags.isEmpty {
            filteredSpots = filteredSpots.filter { spot in
                tags.allSatisfy { tag in
                    spot.subjectTags.contains { $0.localizedCaseInsensitiveContains(tag) }
                }
            }
        }
        
        // Filter by location
        if let nearLocation = nearLocation {
            filteredSpots = filteredSpots.filter { spot in
                let distance = calculateDistance(
                    from: (nearLocation.latitude, nearLocation.longitude),
                    to: (spot.location.latitude, spot.location.longitude)
                )
                return distance <= nearLocation.radiusKM
            }
        }
        
        return filteredSpots
    }
    
    // MARK: - Cache Management for Server Spots
    
    func cacheServerSpot(_ spot: Spot, expiry: Date) {
        do {
            let cdSpot = createCDSpotFromSpot(spot, in: viewContext)
            cdSpot.isLocalOnly = false
            cdSpot.serverSpotId = spot.id.uuidString // For server spots, use the spot ID as server ID
            cdSpot.cacheExpiry = expiry
            cdSpot.lastSynced = Date()
            
            try viewContext.save()
            loadSpots()
            
            print("✅ Cached server spot: \(spot.title)")
        } catch {
            print("❌ Failed to cache server spot: \(error)")
        }
    }
    
    func getExpiredCacheSpots() -> [Spot] {
        do {
            let request: NSFetchRequest<CDSpot> = CDSpot.fetchRequest()
            request.predicate = NSPredicate(
                format: "isLocalOnly == NO AND cacheExpiry != nil AND cacheExpiry < %@",
                Date() as CVarArg
            )
            
            let cdSpots = try viewContext.fetch(request)
            return cdSpots.map { convertCDSpotToSpot($0) }
        } catch {
            print("Failed to fetch expired cache spots: \(error)")
            return []
        }
    }
    
    func getUserSpots() -> [Spot] {
        return spots.filter { spot in
            // Find the corresponding CDSpot
            do {
                let request: NSFetchRequest<CDSpot> = CDSpot.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", spot.id as CVarArg)
                let cdSpots = try viewContext.fetch(request)
                return cdSpots.first?.isLocalOnly == true
            } catch {
                return false
            }
        }
    }
    
    func getPendingPublishSpots() -> [Spot] {
        return spots.filter { spot in
            // Find spots that are local-only and not published
            do {
                let request: NSFetchRequest<CDSpot> = CDSpot.fetchRequest()
                request.predicate = NSPredicate(
                    format: "id == %@ AND isLocalOnly == YES AND isPublished == NO",
                    spot.id as CVarArg
                )
                let cdSpots = try viewContext.fetch(request)
                return !cdSpots.isEmpty
            } catch {
                return false
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveMedia(_ media: Media, to spot: CDSpot) {
        do {
            print("💿 Saving media with ID: \(media.id) and URL: \(media.url)")
            let request: NSFetchRequest<CDMedia> = CDMedia.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", media.id as CVarArg)
            
            let existingMedia = try viewContext.fetch(request)
            
            let cdMedia: CDMedia
            if let existing = existingMedia.first {
                print("🔄 Updating existing media")
                updateCDMediaFromMedia(existing, media: media)
                cdMedia = existing
            } else {
                print("🆕 Creating new CDMedia")
                cdMedia = createCDMediaFromMedia(media, in: viewContext)
            }
            
            cdMedia.spot = spot
            print("🔗 Linked media to spot")
        } catch {
            print("❌ Failed to save media: \(error)")
        }
    }
    
    private func saveSunSnapshot(_ sunSnapshot: SunSnapshot, to spot: CDSpot) {
        do {
            let request: NSFetchRequest<CDSunSnapshot> = CDSunSnapshot.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", sunSnapshot.id as CVarArg)
            
            let existingSunSnapshots = try viewContext.fetch(request)
            
            let cdSunSnapshot: CDSunSnapshot
            if let existing = existingSunSnapshots.first {
                updateCDSunSnapshotFromSunSnapshot(existing, sunSnapshot: sunSnapshot)
                cdSunSnapshot = existing
            } else {
                cdSunSnapshot = createCDSunSnapshotFromSunSnapshot(sunSnapshot, in: viewContext)
            }
            
            cdSunSnapshot.spot = spot
            spot.sunSnapshot = cdSunSnapshot
        } catch {
            print("Failed to save sun snapshot: \(error)")
        }
    }
    
    private func saveWeatherSnapshot(_ weatherSnapshot: WeatherSnapshot, to spot: CDSpot) {
        do {
            let request: NSFetchRequest<CDWeatherSnapshot> = CDWeatherSnapshot.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", weatherSnapshot.id as CVarArg)
            
            let existingWeatherSnapshots = try viewContext.fetch(request)
            
            let cdWeatherSnapshot: CDWeatherSnapshot
            if let existing = existingWeatherSnapshots.first {
                updateCDWeatherSnapshotFromWeatherSnapshot(existing, weatherSnapshot: weatherSnapshot)
                cdWeatherSnapshot = existing
            } else {
                cdWeatherSnapshot = createCDWeatherSnapshotFromWeatherSnapshot(weatherSnapshot, in: viewContext)
            }
            
            cdWeatherSnapshot.spot = spot
            spot.weatherSnapshot = cdWeatherSnapshot
        } catch {
            print("Failed to save weather snapshot: \(error)")
        }
    }
    
    private func saveAccessInfo(_ accessInfo: AccessInfo, to spot: CDSpot) {
        do {
            let request: NSFetchRequest<CDAccessInfo> = CDAccessInfo.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", accessInfo.id as CVarArg)
            
            let existingAccessInfo = try viewContext.fetch(request)
            
            let cdAccessInfo: CDAccessInfo
            if let existing = existingAccessInfo.first {
                updateCDAccessInfoFromAccessInfo(existing, accessInfo: accessInfo)
                cdAccessInfo = existing
            } else {
                cdAccessInfo = createCDAccessInfoFromAccessInfo(accessInfo, in: viewContext)
            }
            
            cdAccessInfo.spot = spot
            spot.accessInfo = cdAccessInfo
        } catch {
            print("Failed to save access info: \(error)")
        }
    }
    
    private func calculateDistance(from: (Double, Double), to: (Double, Double)) -> Double {
        let earthRadius = 6371.0 // Earth's radius in kilometers
        
        let lat1Rad = from.0 * .pi / 180.0
        let lat2Rad = to.0 * .pi / 180.0
        let deltaLatRad = (to.0 - from.0) * .pi / 180.0
        let deltaLonRad = (to.1 - from.1) * .pi / 180.0
        
        let a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLonRad / 2) * sin(deltaLonRad / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return earthRadius * c
    }
    
    // MARK: - CoreData Conversion Helpers
    
    private func convertCDSpotToSpot(_ cdSpot: CDSpot) -> Spot {
        // Load media from CoreData relationship
        print("🔍 CDSpot.toSpot() - Converting spot '\(cdSpot.title ?? "Unknown")' with media count: \(cdSpot.media?.count ?? 0)")
        let mediaArray: [Media] = (cdSpot.media?.allObjects as? [CDMedia])?.map { cdMedia in
            print("🎬 Converting CDMedia with URL: \(cdMedia.url ?? "no URL")")
            return convertCDMediaToMedia(cdMedia)
        } ?? []
        print("✅ Converted to \(mediaArray.count) media items")
        
        return Spot(
            id: cdSpot.id ?? UUID(),
            title: cdSpot.title ?? "",
            location: CLLocationCoordinate2D(
                latitude: cdSpot.latitude,
                longitude: cdSpot.longitude
            ),
            headingDegrees: cdSpot.headingDegrees == -1 ? nil : Int(cdSpot.headingDegrees),
            elevationMeters: cdSpot.elevationMeters == -1 ? nil : Int(cdSpot.elevationMeters),
            subjectTags: parseTagsString(cdSpot.subjectTagsString ?? "[]"),
            difficulty: Spot.Difficulty(rawValue: Int(cdSpot.difficulty)) ?? .moderate,
            createdBy: cdSpot.createdBy ?? UUID(),
            privacy: Spot.Privacy(rawValue: cdSpot.privacy ?? "public") ?? .publicSpot,
            license: cdSpot.license ?? "CC-BY-NC",
            status: Spot.SpotStatus(rawValue: cdSpot.status ?? "active") ?? .active,
            createdAt: cdSpot.createdAt ?? Date(),
            updatedAt: cdSpot.updatedAt ?? Date(),
            media: mediaArray,
            sunSnapshot: cdSpot.sunSnapshot.map { convertCDSunSnapshotToSunSnapshot($0) },
            weatherSnapshot: cdSpot.weatherSnapshot.map { convertCDWeatherSnapshotToWeatherSnapshot($0) },
            accessInfo: cdSpot.accessInfo.map { convertCDAccessInfoToAccessInfo($0) },
            voteCount: Int(cdSpot.voteCount)
        )
    }
    
    private func createCDSpotFromSpot(_ spot: Spot, in context: NSManagedObjectContext) -> CDSpot {
        let cdSpot = CDSpot(context: context)
        updateCDSpotFromSpot(cdSpot, spot: spot)
        return cdSpot
    }
    
    private func updateCDSpotFromSpot(_ cdSpot: CDSpot, spot: Spot) {
        cdSpot.id = spot.id
        cdSpot.title = spot.title
        cdSpot.latitude = spot.location.latitude
        cdSpot.longitude = spot.location.longitude
        cdSpot.headingDegrees = Int16(spot.headingDegrees ?? -1)
        cdSpot.elevationMeters = Int16(spot.elevationMeters ?? -1)
        cdSpot.subjectTagsString = encodeTagsArray(spot.subjectTags)
        cdSpot.difficulty = Int16(spot.difficulty.rawValue)
        cdSpot.createdBy = spot.createdBy
        cdSpot.privacy = spot.privacy.rawValue
        cdSpot.license = spot.license
        cdSpot.status = spot.status.rawValue
        cdSpot.createdAt = spot.createdAt
        cdSpot.updatedAt = spot.updatedAt
        cdSpot.voteCount = Int32(spot.voteCount)
        
        // Local-first properties
        if cdSpot.isLocalOnly == false {
            // This is a server spot, preserve cache settings
        } else {
            cdSpot.isLocalOnly = true
            cdSpot.isPublished = false
        }
    }
    
    private func convertCDMediaToMedia(_ cdMedia: CDMedia) -> Media {
        let exifData = ExifData(
            make: cdMedia.exifMake,
            model: cdMedia.exifModel,
            lens: cdMedia.exifLens,
            focalLength: cdMedia.exifFocalLength == -1 ? nil : cdMedia.exifFocalLength,
            fNumber: cdMedia.exifFNumber == -1 ? nil : cdMedia.exifFNumber,
            exposureTime: cdMedia.exifExposureTime,
            iso: cdMedia.exifIso == -1 ? nil : Int(cdMedia.exifIso),
            dateTimeOriginal: cdMedia.exifDateTimeOriginal,
            gpsLatitude: cdMedia.exifGpsLatitude == 0 ? nil : cdMedia.exifGpsLatitude,
            gpsLongitude: cdMedia.exifGpsLongitude == 0 ? nil : cdMedia.exifGpsLongitude,
            gpsAltitude: cdMedia.exifGpsAltitude == 0 ? nil : cdMedia.exifGpsAltitude,
            gpsDirection: cdMedia.exifGpsDirection == -1 ? nil : cdMedia.exifGpsDirection,
            width: cdMedia.exifWidth == -1 ? nil : Int(cdMedia.exifWidth),
            height: cdMedia.exifHeight == -1 ? nil : Int(cdMedia.exifHeight),
            colorSpace: cdMedia.exifColorSpace,
            software: cdMedia.exifSoftware
        )
        
        return Media(
            id: cdMedia.id ?? UUID(),
            spotId: cdMedia.spot?.id,
            userId: cdMedia.userId ?? UUID(),
            type: Media.MediaType(rawValue: cdMedia.type ?? "photo") ?? .photo,
            url: cdMedia.url ?? "",
            thumbnailUrl: cdMedia.thumbnailUrl,
            captureTimeUTC: cdMedia.captureTimeUTC,
            exifData: exifData,
            device: cdMedia.device,
            lens: cdMedia.lens,
            focalLengthMM: cdMedia.focalLengthMM == -1 ? nil : cdMedia.focalLengthMM,
            aperture: cdMedia.aperture == -1 ? nil : cdMedia.aperture,
            shutterSpeed: cdMedia.shutterSpeed,
            iso: cdMedia.iso == -1 ? nil : Int(cdMedia.iso),
            resolutionWidth: cdMedia.resolutionWidth == -1 ? nil : Int(cdMedia.resolutionWidth),
            resolutionHeight: cdMedia.resolutionHeight == -1 ? nil : Int(cdMedia.resolutionHeight),
            presets: parseStringArray(cdMedia.presetsString ?? "[]"),
            filters: parseStringArray(cdMedia.filtersString ?? "[]"),
            headingFromExif: cdMedia.headingFromExif,
            originalFilename: cdMedia.originalFilename,
            createdAt: cdMedia.createdAt ?? Date()
        )
    }
    
    private func createCDMediaFromMedia(_ media: Media, in context: NSManagedObjectContext) -> CDMedia {
        let cdMedia = CDMedia(context: context)
        cdMedia.id = media.id
        cdMedia.userId = media.userId
        cdMedia.type = media.type.rawValue
        cdMedia.url = media.url
        cdMedia.thumbnailUrl = media.thumbnailUrl
        cdMedia.captureTimeUTC = media.captureTimeUTC
        cdMedia.device = media.device
        cdMedia.lens = media.lens
        cdMedia.focalLengthMM = media.focalLengthMM ?? -1
        cdMedia.aperture = media.aperture ?? -1
        cdMedia.shutterSpeed = media.shutterSpeed
        cdMedia.iso = Int32(media.iso ?? -1)
        cdMedia.resolutionWidth = Int32(media.resolutionWidth ?? -1)
        cdMedia.resolutionHeight = Int32(media.resolutionHeight ?? -1)
        cdMedia.presetsString = encodeStringArray(media.presets)
        cdMedia.filtersString = encodeStringArray(media.filters)
        cdMedia.headingFromExif = media.headingFromExif
        cdMedia.originalFilename = media.originalFilename
        cdMedia.createdAt = media.createdAt
        
        // EXIF data
        if let exif = media.exifData {
            cdMedia.exifMake = exif.make
            cdMedia.exifModel = exif.model
            cdMedia.exifLens = exif.lens
            cdMedia.exifFocalLength = exif.focalLength ?? -1
            cdMedia.exifFNumber = exif.fNumber ?? -1
            cdMedia.exifExposureTime = exif.exposureTime
            cdMedia.exifIso = Int32(exif.iso ?? -1)
            cdMedia.exifDateTimeOriginal = exif.dateTimeOriginal
            cdMedia.exifGpsLatitude = exif.gpsLatitude ?? 0
            cdMedia.exifGpsLongitude = exif.gpsLongitude ?? 0
            cdMedia.exifGpsAltitude = exif.gpsAltitude ?? 0
            cdMedia.exifGpsDirection = exif.gpsDirection ?? -1
            cdMedia.exifWidth = Int32(exif.width ?? -1)
            cdMedia.exifHeight = Int32(exif.height ?? -1)
            cdMedia.exifColorSpace = exif.colorSpace
            cdMedia.exifSoftware = exif.software
        }
        
        cdMedia.isDownloaded = true
        cdMedia.thumbnailDownloaded = true
        return cdMedia
    }
    
    private func updateCDMediaFromMedia(_ cdMedia: CDMedia, media: Media) {
        cdMedia.id = media.id
        cdMedia.userId = media.userId
        cdMedia.type = media.type.rawValue
        cdMedia.url = media.url
        cdMedia.thumbnailUrl = media.thumbnailUrl
        cdMedia.captureTimeUTC = media.captureTimeUTC
        cdMedia.device = media.device
        cdMedia.lens = media.lens
        cdMedia.focalLengthMM = media.focalLengthMM ?? -1
        cdMedia.aperture = media.aperture ?? -1
        cdMedia.shutterSpeed = media.shutterSpeed
        cdMedia.iso = Int32(media.iso ?? -1)
        cdMedia.resolutionWidth = Int32(media.resolutionWidth ?? -1)
        cdMedia.resolutionHeight = Int32(media.resolutionHeight ?? -1)
        cdMedia.presetsString = encodeStringArray(media.presets)
        cdMedia.filtersString = encodeStringArray(media.filters)
        cdMedia.headingFromExif = media.headingFromExif
        cdMedia.originalFilename = media.originalFilename
        cdMedia.createdAt = media.createdAt
        
        // EXIF data
        if let exif = media.exifData {
            cdMedia.exifMake = exif.make
            cdMedia.exifModel = exif.model
            cdMedia.exifLens = exif.lens
            cdMedia.exifFocalLength = exif.focalLength ?? -1
            cdMedia.exifFNumber = exif.fNumber ?? -1
            cdMedia.exifExposureTime = exif.exposureTime
            cdMedia.exifIso = Int32(exif.iso ?? -1)
            cdMedia.exifDateTimeOriginal = exif.dateTimeOriginal
            cdMedia.exifGpsLatitude = exif.gpsLatitude ?? 0
            cdMedia.exifGpsLongitude = exif.gpsLongitude ?? 0
            cdMedia.exifGpsAltitude = exif.gpsAltitude ?? 0
            cdMedia.exifGpsDirection = exif.gpsDirection ?? -1
            cdMedia.exifWidth = Int32(exif.width ?? -1)
            cdMedia.exifHeight = Int32(exif.height ?? -1)
            cdMedia.exifColorSpace = exif.colorSpace
            cdMedia.exifSoftware = exif.software
        }
        
        cdMedia.isDownloaded = true
        cdMedia.thumbnailDownloaded = true
    }
    
    private func createCDSunSnapshotFromSunSnapshot(_ sunSnapshot: SunSnapshot, in context: NSManagedObjectContext) -> CDSunSnapshot {
        let cdSunSnapshot = CDSunSnapshot(context: context)
        cdSunSnapshot.id = sunSnapshot.id
        cdSunSnapshot.date = sunSnapshot.date
        cdSunSnapshot.sunriseUTC = sunSnapshot.sunriseUTC
        cdSunSnapshot.sunsetUTC = sunSnapshot.sunsetUTC
        cdSunSnapshot.goldenHourStartUTC = sunSnapshot.goldenHourStartUTC
        cdSunSnapshot.goldenHourEndUTC = sunSnapshot.goldenHourEndUTC
        cdSunSnapshot.blueHourStartUTC = sunSnapshot.blueHourStartUTC
        cdSunSnapshot.blueHourEndUTC = sunSnapshot.blueHourEndUTC
        cdSunSnapshot.closestEventString = sunSnapshot.closestEvent?.rawValue
        cdSunSnapshot.relativeMinutesToEvent = Int32(sunSnapshot.relativeMinutesToEvent ?? Int.max)
        return cdSunSnapshot
    }
    
    private func updateCDSunSnapshotFromSunSnapshot(_ cdSunSnapshot: CDSunSnapshot, sunSnapshot: SunSnapshot) {
        cdSunSnapshot.id = sunSnapshot.id
        cdSunSnapshot.date = sunSnapshot.date
        cdSunSnapshot.sunriseUTC = sunSnapshot.sunriseUTC
        cdSunSnapshot.sunsetUTC = sunSnapshot.sunsetUTC
        cdSunSnapshot.goldenHourStartUTC = sunSnapshot.goldenHourStartUTC
        cdSunSnapshot.goldenHourEndUTC = sunSnapshot.goldenHourEndUTC
        cdSunSnapshot.blueHourStartUTC = sunSnapshot.blueHourStartUTC
        cdSunSnapshot.blueHourEndUTC = sunSnapshot.blueHourEndUTC
        cdSunSnapshot.closestEventString = sunSnapshot.closestEvent?.rawValue
        cdSunSnapshot.relativeMinutesToEvent = Int32(sunSnapshot.relativeMinutesToEvent ?? Int.max)
    }
    
    private func createCDWeatherSnapshotFromWeatherSnapshot(_ weatherSnapshot: WeatherSnapshot, in context: NSManagedObjectContext) -> CDWeatherSnapshot {
        let cdWeatherSnapshot = CDWeatherSnapshot(context: context)
        cdWeatherSnapshot.id = weatherSnapshot.id
        cdWeatherSnapshot.timeUTC = weatherSnapshot.timeUTC
        cdWeatherSnapshot.temperatureCelsius = weatherSnapshot.temperatureCelsius ?? 0
        cdWeatherSnapshot.humidity = Int32(weatherSnapshot.humidity ?? -1)
        cdWeatherSnapshot.precipitationMM = weatherSnapshot.precipitationMM ?? 0
        cdWeatherSnapshot.windSpeedMPS = weatherSnapshot.windSpeedMPS ?? 0
        cdWeatherSnapshot.pressure = weatherSnapshot.pressure ?? 0
        cdWeatherSnapshot.visibilityMeters = Int32(weatherSnapshot.visibilityMeters ?? -1)
        cdWeatherSnapshot.cloudCoveragePercent = Int32(weatherSnapshot.cloudCoveragePercent ?? -1)
        cdWeatherSnapshot.conditionCode = weatherSnapshot.conditionCode
        cdWeatherSnapshot.conditionDescription = weatherSnapshot.conditionDescription
        cdWeatherSnapshot.source = weatherSnapshot.source
        return cdWeatherSnapshot
    }
    
    private func updateCDWeatherSnapshotFromWeatherSnapshot(_ cdWeatherSnapshot: CDWeatherSnapshot, weatherSnapshot: WeatherSnapshot) {
        cdWeatherSnapshot.id = weatherSnapshot.id
        cdWeatherSnapshot.timeUTC = weatherSnapshot.timeUTC
        cdWeatherSnapshot.temperatureCelsius = weatherSnapshot.temperatureCelsius ?? 0
        cdWeatherSnapshot.humidity = Int32(weatherSnapshot.humidity ?? -1)
        cdWeatherSnapshot.precipitationMM = weatherSnapshot.precipitationMM ?? 0
        cdWeatherSnapshot.windSpeedMPS = weatherSnapshot.windSpeedMPS ?? 0
        cdWeatherSnapshot.pressure = weatherSnapshot.pressure ?? 0
        cdWeatherSnapshot.visibilityMeters = Int32(weatherSnapshot.visibilityMeters ?? -1)
        cdWeatherSnapshot.cloudCoveragePercent = Int32(weatherSnapshot.cloudCoveragePercent ?? -1)
        cdWeatherSnapshot.conditionCode = weatherSnapshot.conditionCode
        cdWeatherSnapshot.conditionDescription = weatherSnapshot.conditionDescription
        cdWeatherSnapshot.source = weatherSnapshot.source
    }
    
    private func createCDAccessInfoFromAccessInfo(_ accessInfo: AccessInfo, in context: NSManagedObjectContext) -> CDAccessInfo {
        let cdAccessInfo = CDAccessInfo(context: context)
        cdAccessInfo.id = accessInfo.id
        
        if let parking = accessInfo.parkingLocation {
            cdAccessInfo.parkingLatitude = parking.latitude
            cdAccessInfo.parkingLongitude = parking.longitude
        } else {
            cdAccessInfo.parkingLatitude = 0
            cdAccessInfo.parkingLongitude = 0
        }
        
        cdAccessInfo.routePolyline = accessInfo.routePolyline
        cdAccessInfo.hazardsString = encodeStringArray(accessInfo.hazards)
        cdAccessInfo.feesString = encodeStringArray(accessInfo.fees)
        cdAccessInfo.accessNotes = accessInfo.notes
        cdAccessInfo.estimatedWalkingMinutes = Int16(accessInfo.estimatedHikingTimeMinutes ?? -1)
        return cdAccessInfo
    }
    
    private func updateCDAccessInfoFromAccessInfo(_ cdAccessInfo: CDAccessInfo, accessInfo: AccessInfo) {
        cdAccessInfo.id = accessInfo.id
        
        if let parking = accessInfo.parkingLocation {
            cdAccessInfo.parkingLatitude = parking.latitude
            cdAccessInfo.parkingLongitude = parking.longitude
        } else {
            cdAccessInfo.parkingLatitude = 0
            cdAccessInfo.parkingLongitude = 0
        }
        
        cdAccessInfo.routePolyline = accessInfo.routePolyline
        cdAccessInfo.hazardsString = encodeStringArray(accessInfo.hazards)
        cdAccessInfo.feesString = encodeStringArray(accessInfo.fees)
        cdAccessInfo.accessNotes = accessInfo.notes
        cdAccessInfo.estimatedWalkingMinutes = Int16(accessInfo.estimatedHikingTimeMinutes ?? -1)
    }
    
    private func convertCDSunSnapshotToSunSnapshot(_ cdSunSnapshot: CDSunSnapshot) -> SunSnapshot {
        return SunSnapshot(
            id: cdSunSnapshot.id ?? UUID(),
            spotId: cdSunSnapshot.spot?.id ?? UUID(),
            date: cdSunSnapshot.date ?? Date(),
            sunriseUTC: cdSunSnapshot.sunriseUTC,
            sunsetUTC: cdSunSnapshot.sunsetUTC,
            goldenHourStartUTC: cdSunSnapshot.goldenHourStartUTC,
            goldenHourEndUTC: cdSunSnapshot.goldenHourEndUTC,
            blueHourStartUTC: cdSunSnapshot.blueHourStartUTC,
            blueHourEndUTC: cdSunSnapshot.blueHourEndUTC,
            closestEvent: cdSunSnapshot.closestEventString.flatMap { SunSnapshot.SolarEvent(rawValue: $0) },
            relativeMinutesToEvent: cdSunSnapshot.relativeMinutesToEvent == Int32(Int.max) ? nil : Int(cdSunSnapshot.relativeMinutesToEvent)
        )
    }
    
    private func convertCDWeatherSnapshotToWeatherSnapshot(_ cdWeatherSnapshot: CDWeatherSnapshot) -> WeatherSnapshot {
        return WeatherSnapshot(
            id: cdWeatherSnapshot.id ?? UUID(),
            spotId: cdWeatherSnapshot.spot?.id ?? UUID(),
            timeUTC: cdWeatherSnapshot.timeUTC ?? Date(),
            source: cdWeatherSnapshot.source ?? "unknown",
            temperatureCelsius: cdWeatherSnapshot.temperatureCelsius == 0 ? nil : cdWeatherSnapshot.temperatureCelsius,
            windSpeedMPS: cdWeatherSnapshot.windSpeedMPS == 0 ? nil : cdWeatherSnapshot.windSpeedMPS,
            cloudCoveragePercent: cdWeatherSnapshot.cloudCoveragePercent == -1 ? nil : Int(cdWeatherSnapshot.cloudCoveragePercent),
            precipitationMM: cdWeatherSnapshot.precipitationMM == 0 ? nil : cdWeatherSnapshot.precipitationMM,
            visibilityMeters: cdWeatherSnapshot.visibilityMeters == -1 ? nil : Int(cdWeatherSnapshot.visibilityMeters),
            conditionCode: cdWeatherSnapshot.conditionCode,
            conditionDescription: cdWeatherSnapshot.conditionDescription,
            humidity: cdWeatherSnapshot.humidity == -1 ? nil : Int(cdWeatherSnapshot.humidity),
            pressure: cdWeatherSnapshot.pressure == 0 ? nil : cdWeatherSnapshot.pressure
        )
    }
    
    private func convertCDAccessInfoToAccessInfo(_ cdAccessInfo: CDAccessInfo) -> AccessInfo {
        let parkingLocation = (cdAccessInfo.parkingLatitude != 0 || cdAccessInfo.parkingLongitude != 0) ?
            CLLocationCoordinate2D(latitude: cdAccessInfo.parkingLatitude, longitude: cdAccessInfo.parkingLongitude) : nil
        
        return AccessInfo(
            id: cdAccessInfo.id ?? UUID(),
            spotId: cdAccessInfo.spot?.id ?? UUID(),
            parkingLocation: parkingLocation,
            routePolyline: cdAccessInfo.routePolyline,
            routeDistanceMeters: nil,
            routeElevationGainMeters: nil,
            routeDifficulty: nil,
            hazards: parseStringArray(cdAccessInfo.hazardsString ?? "[]"),
            fees: parseStringArray(cdAccessInfo.feesString ?? "[]"),
            notes: cdAccessInfo.accessNotes,
            estimatedHikingTimeMinutes: cdAccessInfo.estimatedWalkingMinutes == -1 ? nil : Int(cdAccessInfo.estimatedWalkingMinutes)
        )
    }
    
    private func parseTagsString(_ tagsString: String) -> [String] {
        guard let data = tagsString.data(using: .utf8),
              let tags = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return tags
    }
    
    private func encodeTagsArray(_ tags: [String]) -> String {
        guard let data = try? JSONEncoder().encode(tags),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
    
    private func parseStringArray(_ string: String) -> [String] {
        guard let data = string.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }
    
    private func encodeStringArray(_ array: [String]) -> String {
        guard let data = try? JSONEncoder().encode(array),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
    
    // MARK: - Debug Functions
    
    func verifyPhotoCacheConsistency() {
        do {
            let request: NSFetchRequest<CDMedia> = CDMedia.fetchRequest()
            let mediaItems = try viewContext.fetch(request)
            let photoCache = PhotoCacheService.shared
            
            print("🔍 Checking cache consistency for \(mediaItems.count) media items:")
            
            var existsCount = 0
            var missingCount = 0
            
            for media in mediaItems {
                guard let urlString = media.url else { continue }
                
                let cleanedId = urlString.replacingOccurrences(of: "local_", with: "")
                let filename = "\(cleanedId).jpg"
                let fileExists = photoCache.fileExists(filename: filename)
                
                if fileExists {
                    existsCount += 1
                    print("   ✅ \(filename) - EXISTS")
                } else {
                    missingCount += 1
                    print("   ❌ \(filename) - MISSING")
                }
            }
            
            print("📊 Cache consistency summary:")
            print("   ✅ Files exist: \(existsCount)")
            print("   ❌ Files missing: \(missingCount)")
            
            if missingCount > 0 {
                print("💡 Recommendation: Clear spots and re-add photos to rebuild cache")
            }
            
        } catch {
            print("❌ Failed to verify cache consistency: \(error)")
        }
    }
}