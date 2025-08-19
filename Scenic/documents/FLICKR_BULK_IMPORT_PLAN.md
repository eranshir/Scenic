# Flickr Bulk Import Implementation Plan

## Overview

This document outlines the implementation plan for bulk importing 334 scenic photos from Flickr into the Scenic app's Supabase backend, complete with proper attribution and dummy account creation for future photographer claims.

## Data Analysis Summary

- **Total Photos**: 940 in collection
- **GPS-Enabled Photos**: 334 (36%) - these will be imported
- **Null Location Photos**: 606 (64%) - will be skipped for now
- **Unique Photographers**: ~50+ different Flickr users
- **Attribution Data**: Complete with usernames, photo IDs, and Creative Commons licensing

## Architecture Design

### 1. Database Schema Updates

#### Profiles Table Extensions
```sql
-- Add Flickr account support to profiles table
ALTER TABLE profiles ADD COLUMN account_type TEXT DEFAULT 'user';
ALTER TABLE profiles ADD COLUMN flickr_user_id TEXT;
ALTER TABLE profiles ADD COLUMN flickr_username TEXT;  
ALTER TABLE profiles ADD COLUMN claimable BOOLEAN DEFAULT false;
ALTER TABLE profiles ADD COLUMN original_source TEXT DEFAULT 'user_signup';

-- Create index for Flickr lookups
CREATE INDEX profiles_flickr_user_id_idx ON profiles(flickr_user_id);
```

#### Media Table Extensions
```sql  
-- Add attribution fields to media table
ALTER TABLE media ADD COLUMN attribution_text TEXT;
ALTER TABLE media ADD COLUMN original_source TEXT DEFAULT 'user_upload';
ALTER TABLE media ADD COLUMN original_photo_id TEXT;
ALTER TABLE media ADD COLUMN license_type TEXT DEFAULT 'All Rights Reserved';

-- Create indexes
CREATE INDEX media_original_photo_id_idx ON media(original_photo_id);
CREATE INDEX media_original_source_idx ON media(original_source);
```

### 2. Swift Model Updates

#### Profile Model Extension
```swift
struct Profile {
    // ... existing fields
    var accountType: AccountType = .user
    var flickrUserId: String?
    var flickrUsername: String?
    var claimable: Bool = false
    var originalSource: String = "user_signup"
    
    enum AccountType: String, Codable {
        case user = "user"
        case flickrPlaceholder = "flickr_placeholder"
        case claimed = "claimed"
    }
}
```

#### Media Model Extension
```swift
struct Media {
    // ... existing fields
    var attributionText: String?        // "Photo by photographer_name"
    var originalSource: String = "user_upload"  // "flickr", "user_upload"
    var originalPhotoId: String?        // Flickr photo ID
    var licenseType: String = "All Rights Reserved"
}
```

### 3. UI Enhancement - Simple Attribution Display

#### PhotoMetadataCard Update
Add attribution field after device information:

```swift
struct PhotoMetadataCard: View {
    let media: Media
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photo Information")
                .font(.headline)
            
            VStack(spacing: 8) {
                // ... existing fields (captured, resolution, device)
                
                // NEW: Attribution field
                if let attributionText = media.attributionText {
                    CopyableMetadataRow(label: "Attribution", value: attributionText)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}
```

## Implementation Phases

### Phase 1: Database Schema Setup
**Estimated Time**: 2 hours

1. **Update Supabase Schema**
   - Run SQL migrations for profiles and media table extensions
   - Create necessary indexes
   - Update RLS policies if needed

2. **Update Swift Models**
   - Add new fields to Profile and Media structs
   - Update Codable implementations
   - Update Core Data models to match

3. **Test Schema Changes**
   - Verify existing app functionality still works
   - Test model serialization/deserialization

### Phase 2: Attribution UI Implementation
**Estimated Time**: 3 hours

1. **Update PhotoMetadataCard**
   - Add attribution field display
   - Ensure proper styling matches existing design
   - Handle optional attribution gracefully

2. **Test Attribution Display**
   - Create test media with attribution
   - Verify display in photo details screen
   - Test with various attribution text lengths

### Phase 3: Bulk Import Script Development
**Estimated Time**: 8 hours

#### Import Script Architecture (Node.js)
```javascript
// flickr-import.js
const { createClient } = require('@supabase/supabase-js');
const { v2: cloudinary } = require('cloudinary');
const fs = require('fs');
const path = require('path');

// Configuration
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY; // Service role key
const BATCH_SIZE = 10; // Process 10 photos at a time
const RATE_LIMIT_MS = 2000; // 2 second delay between batches

class FlickrImporter {
    constructor() {
        this.supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
        this.setupCloudinary();
        this.metadata = this.loadMetadata();
    }
    
    async importAll() {
        const gpsPhotos = this.metadata.filter(item => item.location !== null);
        console.log(`Starting import of ${gpsPhotos.length} photos...`);
        
        for (let i = 0; i < gpsPhotos.length; i += BATCH_SIZE) {
            const batch = gpsPhotos.slice(i, i + BATCH_SIZE);
            await this.processBatch(batch);
            await this.sleep(RATE_LIMIT_MS);
        }
    }
    
    async processBatch(batch) {
        for (const item of batch) {
            try {
                const photographer = await this.ensurePhotographer(item);
                const cloudinaryResult = await this.uploadToCloudinary(item);
                const spot = await this.createSpot(item, photographer.id, cloudinaryResult);
                await this.createMedia(item, spot.id, photographer.id, cloudinaryResult);
                
                console.log(`✅ Imported: ${item.title}`);
            } catch (error) {
                console.error(`❌ Failed: ${item.title}`, error.message);
            }
        }
    }
}
```

#### Key Import Functions
1. **Photographer Creation**
   - Check if Flickr username already exists
   - Create dummy profile with special account type
   - Generate unique username with prefix

2. **Cloudinary Upload**
   - Upload original photo with metadata preservation
   - Generate optimized versions
   - Store Cloudinary URLs and public IDs

3. **Spot Creation**
   - Use photo location as spot coordinates
   - Reverse geocode for location names
   - Generate meaningful spot titles from photo titles
   - Group nearby photos (within 100m) into same spots

4. **Media Record Creation**
   - Link to spot and photographer
   - Store attribution text and original IDs
   - Preserve EXIF data and licensing info

### Phase 4: Data Processing Pipeline
**Estimated Time**: 4 hours

#### Data Processing Features

1. **Duplicate Detection**
   - Check for existing photos by Flickr ID
   - Prevent duplicate imports
   - Handle photographer account merging

2. **Location Grouping**
   - Cluster photos within 100m radius into single spots
   - Prioritize best photo as primary for each spot
   - Create meaningful spot names from photo titles

3. **Attribution Generation**
   ```javascript
   function generateAttribution(flickrData) {
       if (flickrData.photographer_name) {
           return `Photo by ${flickrData.photographer_name} on Flickr`;
       } else {
           return `Photo by ${flickrData.username} on Flickr`;
       }
   }
   ```

4. **Error Handling & Logging**
   - Comprehensive error logging
   - Resume capability for interrupted imports
   - Success/failure statistics

### Phase 5: Testing & Validation
**Estimated Time**: 3 hours

1. **Import Verification**
   - Verify all 334 photos imported successfully
   - Check spot creation and media linking
   - Validate attribution display in app

2. **Data Integrity Checks**
   - Ensure all foreign key relationships are correct
   - Verify GPS coordinates and location data
   - Check Cloudinary URL accessibility

3. **Performance Testing**
   - Test app performance with bulk data
   - Verify map loading with many spots
   - Check photo loading and caching

## Future Account Claiming Mechanism

### Claim Process Design
1. **User Verification**
   - User signs in and provides Flickr username
   - OAuth verification with Flickr (future implementation)
   - Match flickr_user_id to existing placeholder account

2. **Account Migration**
   ```sql
   -- Update placeholder account to claimed status
   UPDATE profiles 
   SET account_type = 'claimed',
       display_name = $1,
       avatar_url = $2,
       claimable = false,
       updated_at = NOW()
   WHERE flickr_user_id = $3 AND account_type = 'flickr_placeholder';
   ```

3. **Attribution Updates**
   - Update attribution to point to verified user
   - Maintain original Flickr attribution for legal compliance
   - Show "Verified Photographer" badge in UI

## Data Preservation & Legal Compliance

### Attribution Requirements
- Maintain original Flickr photo IDs and URLs
- Store complete Creative Commons license information
- Preserve photographer names and attribution text
- Ensure proper attribution display in all contexts

### Data Backup
- Export metadata before import for rollback capability
- Document all data transformations
- Maintain audit trail of import process

## Expected Outcomes

### Immediate Benefits
- **334 scenic photos** with GPS coordinates added to app
- **~50 placeholder photographer accounts** created
- **Proper attribution system** in place for all photos
- **Legal compliance** with Creative Commons licensing

### Long-term Value
- **Rich content foundation** for app launch
- **Photographer engagement** opportunity through claim system
- **Proven bulk import pipeline** for future content sources
- **Attribution framework** ready for public profiles feature

## Technical Specifications

### Environment Requirements
- Node.js 18+ for import script
- Supabase service role key for database access
- Cloudinary account with sufficient upload quota
- Local copy of flickr_collection folder with 334 photos

### Performance Considerations
- **Batch Processing**: 10 photos per batch to avoid rate limits
- **Rate Limiting**: 2-second delays between batches
- **Memory Management**: Process photos sequentially to avoid memory issues
- **Error Recovery**: Resume capability for interrupted imports

### Security Considerations
- Use Supabase service role key (not anon key) for bulk operations
- Store sensitive keys in environment variables
- Implement proper error handling to avoid credential exposure
- Audit log all import operations

## Success Metrics

### Technical Metrics
- ✅ 334 photos successfully imported
- ✅ All photos display with proper attribution
- ✅ Zero broken Cloudinary URLs
- ✅ All GPS coordinates properly stored
- ✅ ~50 photographer profiles created

### User Experience Metrics
- ✅ Photo details screen shows attribution
- ✅ App performance unaffected by bulk data
- ✅ Map view displays new spots correctly
- ✅ Photo loading times remain optimal

This comprehensive plan provides a foundation for enriching the Scenic app with curated photography content while maintaining proper attribution and creating opportunities for future photographer engagement.