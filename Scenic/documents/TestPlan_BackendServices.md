# Backend Services Test Validation Plan

## Quick Test Sequence

### 1. SpotService Basic Test
```swift
// In HomeView or test view, add test button:
Button("Test SpotService") {
    Task {
        do {
            // Create test spot
            let newSpot = try await SpotService.shared.createSpot(
                title: "Test Spot \(Date().timeIntervalSince1970)",
                description: "Test description",
                latitude: 37.7749,
                longitude: -122.4194,
                tags: ["sunset", "cityscape"],
                difficulty: 3
            )
            print("✅ Created spot: \(newSpot.id)")
            
            // Fetch spots
            let spots = try await SpotService.shared.fetchSpots(
                tags: ["sunset"],
                difficulty: 3,
                limit: 10
            )
            print("✅ Found \(spots.count) spots")
            
        } catch {
            print("❌ SpotService error: \(error)")
        }
    }
}
```

### 2. MediaService Upload Test
```swift
Button("Test Media Upload") {
    Task {
        do {
            // Use existing spot or create new
            let spotId = UUID() // Replace with actual spot ID
            
            // Create test image
            let testImage = UIImage(systemName: "photo.fill")!
            
            // Upload with metadata
            let mediaRecords = try await MediaService.shared.uploadMedia(
                for: spotId,
                images: [testImage],
                metadata: [MediaMetadata(
                    capturedAt: Date(),
                    headingDegrees: 45,
                    elevationMeters: 100,
                    description: "Test photo"
                )]
            )
            print("✅ Uploaded \(mediaRecords.count) media items")
            
        } catch {
            print("❌ MediaService error: \(error)")
        }
    }
}
```

### 3. PlanService Test
```swift
Button("Test PlanService") {
    Task {
        do {
            // Create plan
            let plan = try await PlanService.shared.createPlan(
                title: "Weekend Photography Trip",
                description: "Testing plan service",
                startDate: Date(),
                endDate: Date().addingTimeInterval(86400 * 2)
            )
            print("✅ Created plan: \(plan.id)")
            
            // Add spots to plan
            if let firstSpot = try await SpotService.shared.fetchSpots(limit: 1).first {
                try await PlanService.shared.addSpotToPlan(
                    planId: plan.id,
                    spotId: firstSpot.id,
                    order: 1,
                    scheduledTime: Date().addingTimeInterval(3600)
                )
                print("✅ Added spot to plan")
            }
            
            // Fetch user plans
            let userPlans = try await PlanService.shared.getUserPlans()
            print("✅ User has \(userPlans.count) plans")
            
        } catch {
            print("❌ PlanService error: \(error)")
        }
    }
}
```

## Expected Results

### Success Indicators
- ✅ All CRUD operations complete without errors
- ✅ Data persists in Supabase database
- ✅ Media uploads to Cloudinary with valid URLs
- ✅ Proper error messages for validation failures
- ✅ User can only modify their own content

### Common Issues to Watch For
- ⚠️ Authentication token expiry
- ⚠️ Network connectivity issues
- ⚠️ Image size limits (50MB max)
- ⚠️ Rate limiting on API calls
- ⚠️ Missing required fields in requests

## Test Data Cleanup
```sql
-- Run in Supabase SQL editor after testing
DELETE FROM media WHERE cloudinary_url LIKE '%test%';
DELETE FROM plan_items WHERE plan_id IN (SELECT id FROM plans WHERE title LIKE 'Test%');
DELETE FROM plans WHERE title LIKE 'Test%';
DELETE FROM spots WHERE title LIKE 'Test%';
```

## Debugging Tips
1. Check Xcode console for detailed error messages
2. Verify Supabase logs at: project.supabase.com/logs
3. Check Cloudinary dashboard for upload status
4. Use Network Link Conditioner to test poor connectivity
5. Test with different user accounts for permission testing