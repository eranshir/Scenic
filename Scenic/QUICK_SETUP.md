# Quick CoreData Setup - Copy/Paste Method

Instead of manually entering dozens of attributes, here's the fastest way:

## Option 1: Run the Setup Script
```bash
cd /Users/eranshir/Documents/Projects/scenic/Scenic
./setup_coredata.sh
```

## Option 2: Manual Quick Setup (5 minutes)

1. **Create Data Model in Xcode:**
   - Right-click project → New File → Data Model
   - Name: `ScenicDataModel`

2. **Copy-Paste Entity Definitions:**

### 🎯 CDSpot Entity (Copy this list):
```
id (UUID, Required)
title (String, Required)  
latitude (Double, Required)
longitude (Double, Required)
headingDegrees (Integer 16, Default: -1)
elevationMeters (Integer 16, Default: -1)  
difficulty (Integer 16, Default: 3)
privacy (String, Default: "public")
license (String, Required)
status (String, Default: "active")
createdAt (Date, Required)
updatedAt (Date, Required)
subjectTagsString (String, Default: "[]")
serverSpotId (String, Optional)
isPublished (Boolean, Default: NO)
lastSynced (Date, Optional)
cacheExpiry (Date, Optional)
isLocalOnly (Boolean, Default: YES)
createdBy (UUID, Required)
voteCount (Integer 32, Default: 0)
```

### 🎯 CDMedia Entity (Copy this list):
```
id (UUID, Required)
userId (UUID, Required)
type (String, Required)
url (String, Required)
thumbnailUrl (String, Optional)
captureTimeUTC (Date, Optional)
device (String, Optional)
lens (String, Optional)
focalLengthMM (Float, Default: -1)
aperture (Float, Default: -1)
shutterSpeed (String, Optional)
iso (Integer 32, Default: -1)
resolutionWidth (Integer 32, Default: -1)
resolutionHeight (Integer 32, Default: -1)
presetsString (String, Default: "[]")
filtersString (String, Default: "[]")
headingFromExif (Boolean, Default: NO)
originalFilename (String, Optional)
createdAt (Date, Required)
exifMake (String, Optional)
exifModel (String, Optional)
exifLens (String, Optional)
exifFocalLength (Float, Default: -1)
exifFNumber (Float, Default: -1)
exifExposureTime (String, Optional)
exifIso (Integer 32, Default: -1)
exifDateTimeOriginal (Date, Optional)
exifGpsLatitude (Double, Default: NaN)
exifGpsLongitude (Double, Default: NaN)
exifGpsAltitude (Double, Default: NaN)
exifGpsDirection (Float, Default: -1)
exifWidth (Integer 32, Default: -1)
exifHeight (Integer 32, Default: -1)
exifColorSpace (String, Optional)
exifSoftware (String, Optional)
serverMediaId (String, Optional)
localFilePath (String, Optional)
isDownloaded (Boolean, Default: YES)
thumbnailDownloaded (Boolean, Default: YES)
lastSynced (Date, Optional)
```

### 🎯 Minimal Setup (Just these 2 entities work!)
If you want to test quickly, **just create CDSpot and CDMedia** - that's enough to save and display spots!

The other entities (CDSunSnapshot, CDWeatherSnapshot, CDAccessInfo, CDComment) can be added later as needed.

## Option 3: Skip CoreData for Now
If you want to test the data flow first, temporarily modify `PersistenceController.swift`:

```swift
// Comment out the CoreData loading temporarily
container.loadPersistentStores(completionHandler: { (storeDescription, error) in
    print("Using in-memory store for testing")
})
```

This lets you test the save/load flow without creating the full model first.

## 🎯 Relationships Quick Setup
After creating entities, add these relationships:

**CDSpot relationships:**
- `media` → To Many CDMedia (Cascade)
- `sunSnapshot` → To One CDSunSnapshot (Cascade) 
- `weatherSnapshot` → To One CDWeatherSnapshot (Cascade)
- `accessInfo` → To One CDAccessInfo (Cascade)
- `comments` → To Many CDComment (Cascade)

**CDMedia relationships:**
- `spot` → To One CDSpot (Nullify)

## ⚡ The Fastest Path
1. Create `ScenicDataModel.xcdatamodeld`
2. Add **just CDSpot and CDMedia entities** with the attributes above
3. Set **Codegen to "Manual/None"** for both entities  
4. Build and test - the app should save spots!
5. Add other entities later when needed

This gets you 80% of the functionality in 20% of the setup time!