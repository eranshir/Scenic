# CoreData Model Creation Instructions

Since I cannot create .xcdatamodeld files directly, you need to manually create the CoreData model in Xcode. Here are the exact specifications:

## 1. Create New Data Model

1. In Xcode, right-click on the project
2. Add New File → Data Model
3. Name it `ScenicDataModel`

## 2. Entity Definitions

### CDSpot Entity

**Attributes:**
- `id` (UUID, Required)
- `title` (String, Required)
- `latitude` (Double, Required)
- `longitude` (Double, Required)
- `headingDegrees` (Integer 16, Default: -1) // -1 means nil
- `elevationMeters` (Integer 16, Default: -1) // -1 means nil
- `difficulty` (Integer 16, Required, Default: 3)
- `privacy` (String, Required, Default: "public")
- `license` (String, Required)
- `status` (String, Required, Default: "active")
- `createdAt` (Date, Required)
- `updatedAt` (Date, Required)
- `subjectTagsString` (String, Required, Default: "[]")
- `serverSpotId` (String, Optional)
- `isPublished` (Boolean, Required, Default: NO)
- `lastSynced` (Date, Optional)
- `cacheExpiry` (Date, Optional)
- `isLocalOnly` (Boolean, Required, Default: YES)
- `createdBy` (UUID, Required)
- `voteCount` (Integer 32, Required, Default: 0)

**Relationships:**
- `media` (To Many → CDMedia, Delete Rule: Cascade)
- `sunSnapshot` (To One → CDSunSnapshot, Delete Rule: Cascade)
- `weatherSnapshot` (To One → CDWeatherSnapshot, Delete Rule: Cascade)
- `accessInfo` (To One → CDAccessInfo, Delete Rule: Cascade)
- `comments` (To Many → CDComment, Delete Rule: Cascade)

### CDMedia Entity

**Attributes:**
- `id` (UUID, Required)
- `userId` (UUID, Required)
- `type` (String, Required)
- `url` (String, Required)
- `thumbnailUrl` (String, Optional)
- `captureTimeUTC` (Date, Optional)
- `device` (String, Optional)
- `lens` (String, Optional)
- `focalLengthMM` (Float, Default: -1) // -1 means nil
- `aperture` (Float, Default: -1) // -1 means nil
- `shutterSpeed` (String, Optional)
- `iso` (Integer 32, Default: -1) // -1 means nil
- `resolutionWidth` (Integer 32, Default: -1) // -1 means nil
- `resolutionHeight` (Integer 32, Default: -1) // -1 means nil
- `presetsString` (String, Default: "[]")
- `filtersString` (String, Default: "[]")
- `headingFromExif` (Boolean, Default: NO)
- `originalFilename` (String, Optional)
- `createdAt` (Date, Required)

**EXIF Data Attributes:**
- `exifMake` (String, Optional)
- `exifModel` (String, Optional)
- `exifLens` (String, Optional)
- `exifFocalLength` (Float, Default: -1) // -1 means nil
- `exifFNumber` (Float, Default: -1) // -1 means nil
- `exifExposureTime` (String, Optional)
- `exifIso` (Integer 32, Default: -1) // -1 means nil
- `exifDateTimeOriginal` (Date, Optional)
- `exifGpsLatitude` (Double, Default: NaN) // NaN means nil
- `exifGpsLongitude` (Double, Default: NaN) // NaN means nil
- `exifGpsAltitude` (Double, Default: NaN) // NaN means nil
- `exifGpsDirection` (Float, Default: -1) // -1 means nil
- `exifWidth` (Integer 32, Default: -1) // -1 means nil
- `exifHeight` (Integer 32, Default: -1) // -1 means nil
- `exifColorSpace` (String, Optional)
- `exifSoftware` (String, Optional)

**Server Sync Attributes:**
- `serverMediaId` (String, Optional)
- `localFilePath` (String, Optional)
- `isDownloaded` (Boolean, Default: YES)
- `thumbnailDownloaded` (Boolean, Default: YES)
- `lastSynced` (Date, Optional)

**Relationships:**
- `spot` (To One → CDSpot, Delete Rule: Nullify)

### CDSunSnapshot Entity

**Attributes:**
- `id` (UUID, Required)
- `date` (Date, Required)
- `sunriseUTC` (Date, Optional)
- `sunsetUTC` (Date, Optional)
- `goldenHourStartUTC` (Date, Optional)
- `goldenHourEndUTC` (Date, Optional)
- `blueHourStartUTC` (Date, Optional)
- `blueHourEndUTC` (Date, Optional)
- `closestEventString` (String, Optional)
- `relativeMinutesToEvent` (Integer 32, Default: 2147483647) // Int32.max means nil

**Relationships:**
- `spot` (To One → CDSpot, Delete Rule: Nullify)

### CDWeatherSnapshot Entity

**Attributes:**
- `id` (UUID, Required)
- `timeUTC` (Date, Required)
- `source` (String, Optional)
- `temperatureCelsius` (Double, Default: NaN) // NaN means nil
- `windSpeedMPS` (Double, Default: NaN) // NaN means nil
- `cloudCoveragePercent` (Integer 32, Default: -1) // -1 means nil
- `precipitationMM` (Double, Default: NaN) // NaN means nil
- `visibilityMeters` (Integer 32, Default: -1) // -1 means nil
- `conditionCode` (String, Optional)
- `conditionDescription` (String, Optional)
- `humidity` (Integer 32, Default: -1) // -1 means nil
- `pressure` (Double, Default: NaN) // NaN means nil

**Relationships:**
- `spot` (To One → CDSpot, Delete Rule: Nullify)

### CDAccessInfo Entity

**Attributes:**
- `id` (UUID, Required)
- `parkingLatitude` (Double, Default: NaN) // NaN means nil
- `parkingLongitude` (Double, Default: NaN) // NaN means nil
- `routePolyline` (String, Optional)
- `hazardsString` (String, Default: "[]")
- `feesString` (String, Default: "[]")
- `accessNotes` (String, Optional)
- `estimatedWalkingMinutes` (Integer 16, Default: -1) // -1 means nil

**Relationships:**
- `spot` (To One → CDSpot, Delete Rule: Nullify)

### CDComment Entity

**Attributes:**
- `id` (UUID, Required)
- `userId` (UUID, Required)
- `body` (String, Required)
- `attachmentsString` (String, Default: "[]")
- `parentId` (UUID, Optional)
- `repliesString` (String, Default: "[]")
- `voteCount` (Integer 32, Default: 0)
- `createdAt` (Date, Required)
- `updatedAt` (Date, Required)
- `serverCommentId` (String, Optional)
- `lastSynced` (Date, Optional)

**Relationships:**
- `spot` (To One → CDSpot, Delete Rule: Nullify)

## 3. Codegen Settings

For each entity, set Codegen to "Manual/None" since we're providing custom NSManagedObject subclasses.

## 4. After Creating the Model

Once the .xcdatamodeld file is created:
1. Build the project to ensure CoreData compiles correctly
2. The PersistenceController and SpotDataService should work automatically
3. Test creating and saving spots through the AddSpotView

## 5. Migration Strategy

This initial model is version 1. When we add server sync features later, we'll create model version 2 and implement lightweight migration.

## Key Benefits

- **Local-First**: All data works offline immediately
- **Cache-Ready**: Built-in support for server data caching
- **Sync-Prepared**: Ready for eventual server synchronization
- **Performance**: Optimized for scenic photography app usage patterns
- **Scenic Conditions**: Poor reception support through local caching