import SwiftUI
import CoreLocation
import Photos

struct BackendServiceTestView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isTestingServices: Bool
    @Binding var testResults: String
    
    @State private var selectedTest = TestType.spotService
    @State private var testLog: [TestLogEntry] = []
    @State private var createdSpotId: UUID?
    @State private var createdPlanId: UUID?
    
    enum TestType: String, CaseIterable {
        case spotService = "SpotService"
        case mediaService = "MediaService"
        case planService = "PlanService"
        case integration = "Integration"
        
        var icon: String {
            switch self {
            case .spotService: return "mappin.circle.fill"
            case .mediaService: return "photo.fill"
            case .planService: return "calendar"
            case .integration: return "link.circle.fill"
            }
        }
    }
    
    struct TestLogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let type: LogType
        
        enum LogType {
            case success, error, info
            
            var color: Color {
                switch self {
                case .success: return .green
                case .error: return .red
                case .info: return .blue
                }
            }
            
            var icon: String {
                switch self {
                case .success: return "checkmark.circle.fill"
                case .error: return "xmark.circle.fill"
                case .info: return "info.circle.fill"
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Test Type Selector
                Picker("Test Type", selection: $selectedTest) {
                    ForEach(TestType.allCases, id: \.self) { type in
                        Label(type.rawValue, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Test Buttons
                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedTest {
                        case .spotService:
                            spotServiceTests
                        case .mediaService:
                            mediaServiceTests
                        case .planService:
                            planServiceTests
                        case .integration:
                            integrationTests
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // Test Log
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Test Log")
                            .font(.headline)
                        Spacer()
                        Button("Clear") {
                            testLog.removeAll()
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(testLog.reversed()) { entry in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: entry.type.icon)
                                        .foregroundColor(entry.type.color)
                                        .font(.caption)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.message)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                        Text(entry.timestamp, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationTitle("Backend Service Tests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .disabled(isTestingServices)
            .overlay {
                if isTestingServices {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Testing...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                }
            }
        }
    }
    
    // MARK: - SpotService Tests
    
    private var spotServiceTests: some View {
        VStack(spacing: 12) {
            TestSection(title: "Create Operations") {
                VStack(spacing: 8) {
                    TestButton(title: "Create Basic Spot", icon: "plus.circle") {
                        await testCreateBasicSpot()
                    }
                    
                    TestButton(title: "Create Full Spot", icon: "plus.circle.fill") {
                        await testCreateFullSpot()
                    }
                }
            }
            
            TestSection(title: "Fetch Operations") {
                VStack(spacing: 8) {
                    TestButton(title: "Fetch All Spots", icon: "list.bullet") {
                        await testFetchAllSpots()
                    }
                    
                    TestButton(title: "Filter by Difficulty", icon: "figure.hiking") {
                        await testFilterByDifficulty()
                    }
                    
                    TestButton(title: "Filter by Tags", icon: "tag") {
                        await testFilterByTags()
                    }
                    
                    TestButton(title: "Filter by Location", icon: "location") {
                        await testFilterByLocation()
                    }
                }
            }
            
            TestSection(title: "Update/Delete Operations") {
                VStack(spacing: 8) {
                    TestButton(title: "Update Spot", icon: "pencil.circle") {
                        await testUpdateSpot()
                    }
                    
                    TestButton(title: "Delete Spot", icon: "trash") {
                        await testDeleteSpot()
                    }
                }
            }
        }
    }
    
    // MARK: - MediaService Tests
    
    private var mediaServiceTests: some View {
        VStack(spacing: 12) {
            TestSection(title: "Upload Operations") {
                VStack(spacing: 8) {
                    TestButton(title: "Upload Test Image", icon: "photo.badge.plus") {
                        await testUploadImage()
                    }
                    
                    TestButton(title: "Upload Multiple Images", icon: "photo.stack") {
                        await testUploadMultipleImages()
                    }
                    
                    TestButton(title: "Upload with Metadata", icon: "photo.badge.arrow.down") {
                        await testUploadWithMetadata()
                    }
                }
            }
            
            TestSection(title: "PHAsset Operations") {
                VStack(spacing: 8) {
                    TestButton(title: "Request Photo Access", icon: "photo.on.rectangle") {
                        await testRequestPhotoAccess()
                    }
                    
                    TestButton(title: "Upload from Photos", icon: "photo.stack.fill") {
                        await testUploadFromPhotos()
                    }
                }
            }
            
            TestSection(title: "Management Operations") {
                VStack(spacing: 8) {
                    TestButton(title: "Get Spot Media", icon: "photo.circle") {
                        await testGetSpotMedia()
                    }
                    
                    TestButton(title: "Delete Media", icon: "photo.badge.minus") {
                        await testDeleteMedia()
                    }
                    
                    TestButton(title: "Add Annotation", icon: "text.badge.plus") {
                        await testAddAnnotation()
                    }
                }
            }
        }
    }
    
    // MARK: - PlanService Tests
    
    private var planServiceTests: some View {
        VStack(spacing: 12) {
            TestSection(title: "Plan Operations") {
                VStack(spacing: 8) {
                    TestButton(title: "Create Plan", icon: "calendar.badge.plus") {
                        await testCreatePlan()
                    }
                    
                    TestButton(title: "Get User Plans", icon: "calendar") {
                        await testGetUserPlans()
                    }
                    
                    TestButton(title: "Update Plan", icon: "calendar.badge.clock") {
                        await testUpdatePlan()
                    }
                }
            }
            
            TestSection(title: "Plan Items") {
                VStack(spacing: 8) {
                    TestButton(title: "Add Spot to Plan", icon: "plus.app") {
                        await testAddSpotToPlan()
                    }
                    
                    TestButton(title: "Reorder Spots", icon: "arrow.up.arrow.down") {
                        await testReorderSpots()
                    }
                    
                    TestButton(title: "Remove Spot", icon: "minus.circle") {
                        await testRemoveSpotFromPlan()
                    }
                }
            }
            
            TestSection(title: "Plan Management") {
                VStack(spacing: 8) {
                    TestButton(title: "Delete Plan", icon: "trash") {
                        await testDeletePlan()
                    }
                }
            }
        }
    }
    
    // MARK: - Integration Tests
    
    private var integrationTests: some View {
        VStack(spacing: 12) {
            TestSection(title: "End-to-End Workflows") {
                VStack(spacing: 8) {
                    TestButton(title: "Complete Spot Creation Flow", icon: "sparkles") {
                        await testCompleteSpotFlow()
                    }
                    
                    TestButton(title: "Complete Plan Creation Flow", icon: "map") {
                        await testCompletePlanFlow()
                    }
                    
                    TestButton(title: "Search and Add to Plan", icon: "magnifyingglass") {
                        await testSearchAndAddFlow()
                    }
                }
            }
            
            TestSection(title: "Sync Operations") {
                VStack(spacing: 8) {
                    TestButton(title: "Sync Down Remote Spots", icon: "arrow.down.circle") {
                        await testSyncDownRemoteSpots()
                    }
                    
                    TestButton(title: "Sync Up Local Spots", icon: "arrow.up.circle") {
                        await testSyncUpLocalSpots()
                    }
                }
            }
            
            TestSection(title: "Performance Tests") {
                VStack(spacing: 8) {
                    TestButton(title: "Upload 10 Images", icon: "speedometer") {
                        await testBulkUpload()
                    }
                    
                    TestButton(title: "Fetch 100 Spots", icon: "arrow.down.circle") {
                        await testLargeFetch()
                    }
                }
            }
            
            TestSection(title: "Error Handling") {
                VStack(spacing: 8) {
                    TestButton(title: "Test Network Failure", icon: "wifi.slash") {
                        await testNetworkFailure()
                    }
                    
                    TestButton(title: "Test Auth Failure", icon: "lock.slash") {
                        await testAuthFailure()
                    }
                }
            }
        }
    }
    
    // MARK: - Test Implementation Methods
    
    private func testCreateBasicSpot() async {
        isTestingServices = true
        logInfo("Starting basic spot creation test...")
        
        do {
            let timestamp = Date().timeIntervalSince1970
            let spot = try await SpotService.shared.createSpot(
                title: "Test Spot \(Int(timestamp))",
                location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                description: "Basic test spot",
                subjectTags: ["test"],
                difficulty: 2
            )
            
            createdSpotId = spot.id
            logSuccess("Created spot with ID: \(spot.id)")
            testResults = "✅ Basic spot created successfully"
        } catch {
            logError("Failed to create spot: \(error.localizedDescription)")
            testResults = "❌ Spot creation failed: \(error)"
        }
        
        isTestingServices = false
    }
    
    private func testCreateFullSpot() async {
        isTestingServices = true
        logInfo("Starting full spot creation test...")
        
        do {
            let timestamp = Date().timeIntervalSince1970
            let spot = try await SpotService.shared.createSpot(
                title: "Full Test Spot \(Int(timestamp))",
                location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                description: "Comprehensive test spot with all metadata",
                headingDegrees: 270,
                elevationMeters: 50,
                subjectTags: ["sunset", "cityscape", "golden-gate"],
                difficulty: 4,
                privacy: "public"
            )
            
            createdSpotId = spot.id
            logSuccess("Created full spot with ID: \(spot.id)")
            logInfo("Tags: \(spot.subjectTags.joined(separator: ", "))")
            logInfo("Difficulty: \(spot.difficulty)")
        } catch {
            logError("Failed to create full spot: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testFetchAllSpots() async {
        isTestingServices = true
        logInfo("Fetching all spots...")
        
        do {
            let spots = try await SpotService.shared.fetchSpots(limit: 20)
            logSuccess("Fetched \(spots.count) spots")
            
            if let first = spots.first {
                logInfo("First spot: \(first.title)")
            }
        } catch {
            logError("Failed to fetch spots: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testFilterByDifficulty() async {
        isTestingServices = true
        logInfo("Testing difficulty filter (level 3)...")
        
        do {
            let spots = try await SpotService.shared.fetchSpots(
                difficulty: 3,
                limit: 10
            )
            logSuccess("Found \(spots.count) spots with difficulty 3")
        } catch {
            logError("Failed to filter by difficulty: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testFilterByTags() async {
        isTestingServices = true
        logInfo("Testing tag filter (sunset, landscape)...")
        
        do {
            let spots = try await SpotService.shared.fetchSpots(
                tags: ["sunset", "landscape"],
                limit: 10
            )
            logSuccess("Found \(spots.count) spots with matching tags")
        } catch {
            logError("Failed to filter by tags: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testFilterByLocation() async {
        isTestingServices = true
        logInfo("Testing location filter (San Francisco, 10km radius)...")
        
        do {
            let spots = try await SpotService.shared.fetchSpots(
                nearLocation: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                radiusKm: 10,
                limit: 20
            )
            logSuccess("Found \(spots.count) spots within 10km")
        } catch {
            logError("Failed to filter by location: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testUpdateSpot() async {
        isTestingServices = true
        
        guard let spotId = createdSpotId else {
            logError("No spot ID available. Create a spot first.")
            isTestingServices = false
            return
        }
        
        logInfo("Updating spot \(spotId)...")
        
        do {
            let updates = SpotUpdate(
                title: "Updated Test Spot",
                description: "This spot has been updated",
                subjectTags: ["updated", "test"],
                difficulty: nil
            )
            try await SpotService.shared.updateSpot(
                id: spotId,
                updates: updates
            )
            logSuccess("Spot updated successfully")
        } catch {
            logError("Failed to update spot: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testDeleteSpot() async {
        isTestingServices = true
        
        guard let spotId = createdSpotId else {
            logError("No spot ID available. Create a spot first.")
            isTestingServices = false
            return
        }
        
        logInfo("Deleting spot \(spotId)...")
        
        do {
            try await SpotService.shared.deleteSpot(id: spotId)
            logSuccess("Spot deleted successfully")
            createdSpotId = nil
        } catch {
            logError("Failed to delete spot: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testUploadImage() async {
        isTestingServices = true
        logInfo("Testing image upload...")
        
        let spotId: UUID
        if let existingSpotId = createdSpotId {
            spotId = existingSpotId
        } else {
            // Create a spot first
            do {
                let spot = try await SpotService.shared.createSpot(
                    title: "Media Test Spot",
                    location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    description: "Spot for media testing",
                    subjectTags: ["test"],
                    difficulty: 1
                )
                createdSpotId = spot.id
                spotId = spot.id
                logInfo("Created spot for media test: \(spot.id)")
            } catch {
                logError("Failed to create spot for media test: \(error)")
                isTestingServices = false
                return
            }
        }
        
        // Create test image
        let testImage = createTestImage()
        
        do {
            let mediaRecords = try await MediaService.shared.uploadMedia(
                for: spotId,
                images: [testImage],
                metadata: []
            )
            logSuccess("Uploaded \(mediaRecords.count) image(s)")
            if let first = mediaRecords.first {
                logInfo("Cloudinary URL: \(first.cloudinaryUrl)")
            }
        } catch {
            logError("Failed to upload image: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testUploadMultipleImages() async {
        isTestingServices = true
        logInfo("Testing multiple image upload...")
        
        guard let spotId = createdSpotId else {
            logError("No spot ID available. Create a spot first.")
            isTestingServices = false
            return
        }
        
        // Create test images
        let images = (0..<3).map { _ in createTestImage() }
        
        do {
            MediaService.shared.uploadProgress = 0
            let mediaRecords = try await MediaService.shared.uploadMedia(
                for: spotId,
                images: images,
                metadata: []
            )
            logSuccess("Uploaded \(mediaRecords.count) images")
            logInfo("Final progress: \(Int(MediaService.shared.uploadProgress * 100))%")
        } catch {
            logError("Failed to upload multiple images: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testUploadWithMetadata() async {
        isTestingServices = true
        logInfo("Testing upload with metadata...")
        
        guard let spotId = createdSpotId else {
            logError("No spot ID available. Create a spot first.")
            isTestingServices = false
            return
        }
        
        let testImage = createTestImage()
        let metadata = MediaMetadata(
            capturedAt: Date(),
            cameraSettings: [
                "aperture": "f/2.8",
                "shutter_speed": "1/125",
                "iso": 400,
                "focal_length": "50mm"
            ],
            headingDegrees: 45,
            elevationMeters: 100,
            description: "Test photo with full metadata"
        )
        
        do {
            let mediaRecords = try await MediaService.shared.uploadMedia(
                for: spotId,
                images: [testImage],
                metadata: [metadata]
            )
            logSuccess("Uploaded image with metadata")
            if let first = mediaRecords.first {
                logInfo("Heading: \(first.headingDegrees ?? 0)°")
                logInfo("Elevation: \(first.elevationMeters ?? 0)m")
            }
        } catch {
            logError("Failed to upload with metadata: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testRequestPhotoAccess() async {
        isTestingServices = true
        logInfo("Requesting photo library access...")
        
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            logSuccess("Photo access already granted")
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            if newStatus == .authorized || newStatus == .limited {
                logSuccess("Photo access granted")
            } else {
                logError("Photo access denied")
            }
        default:
            logError("Photo access denied or restricted")
        }
        
        isTestingServices = false
    }
    
    private func testUploadFromPhotos() async {
        isTestingServices = true
        logInfo("Testing upload from Photos library...")
        
        guard let spotId = createdSpotId else {
            logError("No spot ID available. Create a spot first.")
            isTestingServices = false
            return
        }
        
        // Check photo access
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized ||
              PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited else {
            logError("Photo access not granted")
            isTestingServices = false
            return
        }
        
        // Fetch first photo from library
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        guard assets.count > 0 else {
            logError("No photos found in library")
            isTestingServices = false
            return
        }
        
        do {
            let mediaRecords = try await MediaService.shared.uploadMediaFromAssets(
                for: spotId,
                assets: Array(assets.objects(at: IndexSet(integer: 0)))
            )
            logSuccess("Uploaded \(mediaRecords.count) photo(s) from library")
        } catch {
            logError("Failed to upload from Photos: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testGetSpotMedia() async {
        isTestingServices = true
        
        guard let spotId = createdSpotId else {
            logError("No spot ID available. Create a spot first.")
            isTestingServices = false
            return
        }
        
        logInfo("Fetching media for spot...")
        
        do {
            let media = try await MediaService.shared.getMediaForSpot(spotId)
            logSuccess("Found \(media.count) media items")
        } catch {
            logError("Failed to fetch media: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testDeleteMedia() async {
        isTestingServices = true
        logInfo("Testing media deletion...")
        
        // This would need a media ID from previous upload
        logInfo("Media deletion test placeholder - need media ID")
        
        isTestingServices = false
    }
    
    private func testAddAnnotation() async {
        isTestingServices = true
        logInfo("Testing annotation creation...")
        
        // This would need a media ID from previous upload
        logInfo("Annotation test placeholder - need media ID")
        
        isTestingServices = false
    }
    
    private func testCreatePlan() async {
        isTestingServices = true
        logInfo("Creating test plan...")
        
        do {
            let plan = try await PlanService.shared.createPlan(
                title: "Weekend Photography Trip",
                description: "Testing plan service - Remember to bring tripod",
                plannedDate: Date()
            )
            
            createdPlanId = plan.id
            logSuccess("Created plan: \(plan.id)")
            logInfo("Title: \(plan.title)")
        } catch {
            logError("Failed to create plan: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testGetUserPlans() async {
        isTestingServices = true
        logInfo("Fetching user plans...")
        
        do {
            // fetchUserPlans doesn't return a value, it updates the @Published property
            try await PlanService.shared.fetchUserPlans()
            let plans = PlanService.shared.userPlans
            logSuccess("Found \(plans.count) plan(s)")
            
            for plan in plans.prefix(3) {
                logInfo("• \(plan.title)")
            }
        } catch {
            logError("Failed to fetch plans: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testUpdatePlan() async {
        isTestingServices = true
        
        guard let planId = createdPlanId else {
            logError("No plan ID available. Create a plan first.")
            isTestingServices = false
            return
        }
        
        logInfo("Updating plan...")
        
        do {
            try await PlanService.shared.updatePlan(
                id: planId,
                title: "Updated Photography Trip",
                description: "Plan has been updated - Don't forget camera batteries"
            )
            logSuccess("Plan updated successfully")
        } catch {
            logError("Failed to update plan: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testAddSpotToPlan() async {
        isTestingServices = true
        
        guard let planId = createdPlanId else {
            logError("No plan ID available. Create a plan first.")
            isTestingServices = false
            return
        }
        
        logInfo("Adding spot to plan...")
        
        do {
            // Get a spot to add
            let spots = try await SpotService.shared.fetchSpots(limit: 1)
            guard let spot = spots.first else {
                logError("No spots available to add")
                isTestingServices = false
                return
            }
            
            try await PlanService.shared.addSpotToPlan(
                planId: planId,
                spotId: spot.id,
                orderIndex: 1,
                plannedArrival: Date().addingTimeInterval(3600),
                notes: "Arrive early for best light"
            )
            
            logSuccess("Added spot '\(spot.title)' to plan")
        } catch {
            logError("Failed to add spot to plan: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testReorderSpots() async {
        isTestingServices = true
        
        guard let planId = createdPlanId else {
            logError("No plan ID available. Create a plan first.")
            isTestingServices = false
            return
        }
        
        logInfo("Testing spot reordering...")
        
        do {
            // Get plan with items
            _ = try await PlanService.shared.getPlan(id: planId)
            
            // Note: PlanModel doesn't have items property in the current implementation
            // This would need to be fetched from plan_spots relationship
            logInfo("Spot reordering test needs plan_spots implementation")
        } catch {
            logError("Failed to reorder spots: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testRemoveSpotFromPlan() async {
        isTestingServices = true
        
        guard let planId = createdPlanId else {
            logError("No plan ID available. Create a plan first.")
            isTestingServices = false
            return
        }
        
        logInfo("Removing spot from plan...")
        
        do {
            // Get plan with items
            _ = try await PlanService.shared.getPlan(id: planId)
            
            // Note: PlanModel doesn't have items property in the current implementation
            // Would need to fetch spots separately
            logInfo("Remove spot test needs plan_spots implementation")
        } catch {
            logError("Failed to remove spot: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testDeletePlan() async {
        isTestingServices = true
        
        guard let planId = createdPlanId else {
            logError("No plan ID available. Create a plan first.")
            isTestingServices = false
            return
        }
        
        logInfo("Deleting plan...")
        
        do {
            try await PlanService.shared.deletePlan(id: planId)
            logSuccess("Plan deleted successfully")
            createdPlanId = nil
        } catch {
            logError("Failed to delete plan: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testCompleteSpotFlow() async {
        isTestingServices = true
        logInfo("Starting complete spot creation flow...")
        
        do {
            // 1. Create spot
            let spot = try await SpotService.shared.createSpot(
                title: "Integration Test Spot",
                location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                description: "Complete flow test",
                subjectTags: ["integration", "test"],
                difficulty: 3
            )
            logSuccess("✓ Spot created")
            
            // 2. Upload media
            let testImage = createTestImage()
            let media = try await MediaService.shared.uploadMedia(
                for: spot.id,
                images: [testImage],
                metadata: [MediaMetadata(description: "Integration test photo")]
            )
            logSuccess("✓ Media uploaded (\(media.count) items)")
            
            // 3. Create plan
            let plan = try await PlanService.shared.createPlan(
                title: "Integration Test Plan",
                description: "Testing complete flow",
                plannedDate: Date()
            )
            logSuccess("✓ Plan created")
            
            // 4. Add spot to plan
            try await PlanService.shared.addSpotToPlan(
                planId: plan.id,
                spotId: spot.id,
                orderIndex: 1
            )
            logSuccess("✓ Spot added to plan")
            
            logSuccess("Complete flow test successful!")
            
        } catch {
            logError("Complete flow failed: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testCompletePlanFlow() async {
        isTestingServices = true
        logInfo("Starting complete plan creation flow...")
        
        do {
            // 1. Create multiple spots
            var spotIds: [UUID] = []
            for i in 1...3 {
                let spot = try await SpotService.shared.createSpot(
                    title: "Plan Test Spot \(i)",
                    location: CLLocationCoordinate2D(
                        latitude: 37.7749 + Double(i) * 0.01,
                        longitude: -122.4194 + Double(i) * 0.01
                    ),
                    description: "Spot for plan testing",
                    subjectTags: ["plan-test"],
                    difficulty: i
                )
                spotIds.append(spot.id)
                logInfo("Created spot \(i) of 3")
            }
            
            // 2. Create plan
            let plan = try await PlanService.shared.createPlan(
                title: "Multi-Spot Photography Plan",
                description: "Plan with multiple spots - Visit all spots in sequence",
                plannedDate: Date()
            )
            logSuccess("✓ Plan created")
            
            // 3. Add all spots to plan
            for (index, spotId) in spotIds.enumerated() {
                try await PlanService.shared.addSpotToPlan(
                    planId: plan.id,
                    spotId: spotId,
                    orderIndex: index + 1,
                    plannedArrival: Date().addingTimeInterval(Double(index) * 3600)
                )
            }
            logSuccess("✓ Added \(spotIds.count) spots to plan")
            
            // 4. Fetch and verify
            let fetchedPlan = try await PlanService.shared.getPlan(id: plan.id)
            logSuccess("✓ Verified plan created: \(fetchedPlan.title)")
            
            logSuccess("Complete plan flow successful!")
            
        } catch {
            logError("Plan flow failed: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testSearchAndAddFlow() async {
        isTestingServices = true
        logInfo("Testing search and add to plan flow...")
        
        do {
            // 1. Search for spots with specific tags
            let spots = try await SpotService.shared.fetchSpots(
                tags: ["sunset"],
                limit: 5
            )
            logInfo("Found \(spots.count) sunset spots")
            
            if spots.isEmpty {
                logInfo("No sunset spots found, creating one...")
                _ = try await SpotService.shared.createSpot(
                    title: "Sunset Test Spot",
                    location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    description: "Beautiful sunset location",
                    subjectTags: ["sunset", "golden-hour"],
                    difficulty: 2
                )
                logSuccess("✓ Created sunset spot")
            }
            
            // 2. Create or get existing plan
            try await PlanService.shared.fetchUserPlans()
            let plans = PlanService.shared.userPlans
            let plan: PlanModel
            
            if let existingPlan = plans.first {
                plan = existingPlan
                logInfo("Using existing plan: \(plan.title)")
            } else {
                plan = try await PlanService.shared.createPlan(
                    title: "Sunset Photography Plan",
                    description: "Collection of sunset spots",
                    plannedDate: Date()
                )
                logSuccess("✓ Created new plan")
            }
            
            // 3. Add found spots to plan
            let spotsToAdd = spots.isEmpty ? 
                try await SpotService.shared.fetchSpots(limit: 3) : 
                Array(spots.prefix(3))
            
            for (index, spot) in spotsToAdd.enumerated() {
                try await PlanService.shared.addSpotToPlan(
                    planId: plan.id,
                    spotId: spot.id,
                    orderIndex: index + 1
                )
            }
            
            logSuccess("✓ Added \(spotsToAdd.count) spots to plan")
            logSuccess("Search and add flow successful!")
            
        } catch {
            logError("Search and add flow failed: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testBulkUpload() async {
        isTestingServices = true
        logInfo("Starting bulk upload test (10 images)...")
        
        let spotId: UUID
        if let existingSpotId = createdSpotId {
            spotId = existingSpotId
        } else {
            // Create a spot first
            do {
                let spot = try await SpotService.shared.createSpot(
                    title: "Bulk Upload Test Spot",
                    location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    description: "Testing bulk uploads",
                    subjectTags: ["bulk-test"],
                    difficulty: 1
                )
                createdSpotId = spot.id
                spotId = spot.id
            } catch {
                logError("Failed to create spot for bulk test: \(error)")
                isTestingServices = false
                return
            }
        }
        
        let images = (0..<10).map { _ in createTestImage() }
        let startTime = Date()
        
        do {
            MediaService.shared.uploadProgress = 0
            let mediaRecords = try await MediaService.shared.uploadMedia(
                for: spotId,
                images: images,
                metadata: []
            )
            
            let duration = Date().timeIntervalSince(startTime)
            logSuccess("Uploaded \(mediaRecords.count) images in \(String(format: "%.2f", duration))s")
            logInfo("Average: \(String(format: "%.2f", duration/10))s per image")
            
        } catch {
            logError("Bulk upload failed: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testLargeFetch() async {
        isTestingServices = true
        logInfo("Fetching 100 spots...")
        
        let startTime = Date()
        
        do {
            let spots = try await SpotService.shared.fetchSpots(limit: 100)
            let duration = Date().timeIntervalSince(startTime)
            
            logSuccess("Fetched \(spots.count) spots in \(String(format: "%.2f", duration))s")
            
            if spots.count < 100 {
                logInfo("Only \(spots.count) spots available in database")
            }
            
        } catch {
            logError("Large fetch failed: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testNetworkFailure() async {
        isTestingServices = true
        logInfo("Testing network failure handling...")
        
        // This would require mocking network conditions
        logInfo("Network failure test would require airplane mode or network conditioner")
        logInfo("Try: Settings > Developer > Network Link Conditioner > 100% Loss")
        
        isTestingServices = false
    }
    
    private func testSyncDownRemoteSpots() async {
        isTestingServices = true
        logInfo("Starting sync down test - fetching remote spots...")
        
        do {
            await SyncService.shared.syncRemoteSpotsToLocal()
            logSuccess("✓ Sync down completed successfully!")
            logInfo("Check the log for details on synced spots")
        } catch {
            logError("Sync down failed: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testSyncUpLocalSpots() async {
        isTestingServices = true
        logInfo("Starting sync up test - uploading local spots...")
        
        do {
            await SyncService.shared.syncLocalSpotsToSupabase()
            logSuccess("✓ Sync up completed successfully!")
            logInfo("Check the log for details on uploaded spots")
        } catch {
            logError("Sync up failed: \(error.localizedDescription)")
        }
        
        isTestingServices = false
    }
    
    private func testAuthFailure() async {
        isTestingServices = true
        logInfo("Testing auth failure handling...")
        
        // This would require invalidating the auth token
        logInfo("Auth failure test would require signing out and attempting operations")
        
        isTestingServices = false
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Fill background
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add text
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.white
            ]
            
            let text = "TEST"
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
            
            // Add timestamp
            let timestamp = "\(Date().timeIntervalSince1970)"
            let timestampAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.white.withAlphaComponent(0.7)
            ]
            timestamp.draw(at: CGPoint(x: 10, y: size.height - 20), withAttributes: timestampAttributes)
        }
    }
    
    private func logSuccess(_ message: String) {
        testLog.append(TestLogEntry(
            timestamp: Date(),
            message: message,
            type: .success
        ))
    }
    
    private func logError(_ message: String) {
        testLog.append(TestLogEntry(
            timestamp: Date(),
            message: message,
            type: .error
        ))
    }
    
    private func logInfo(_ message: String) {
        testLog.append(TestLogEntry(
            timestamp: Date(),
            message: message,
            type: .info
        ))
    }
}

// MARK: - Supporting Views

struct TestSection<Content: View>: View {
    let title: String
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TestButton: View {
    let title: String
    let icon: String
    let action: () async -> Void
    
    @State private var isRunning = false
    
    var body: some View {
        Button(action: {
            Task {
                isRunning = true
                await action()
                isRunning = false
            }
        }) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                Spacer()
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .disabled(isRunning)
    }
}

#Preview {
    BackendServiceTestView(
        isTestingServices: .constant(false),
        testResults: .constant("")
    )
}