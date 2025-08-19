# Flickr Bulk Import Scripts

This directory contains scripts for bulk importing the Flickr photo collection into the Scenic app's Supabase backend.

## Setup

### 1. Install Dependencies

```bash
cd scripts
npm install
```

### 2. Database Schema Migration

First, run the SQL migration in Supabase:

```sql
-- Run this in Supabase SQL Editor
-- File: /Scenic/Config/supabase_schema_6_attribution.sql
```

### 3. Environment Variables

Create a `.env` file in the scripts directory:

```bash
# Required: Supabase service role key (not anon key)
SUPABASE_SERVICE_KEY=your_service_role_key_here

# Required: Cloudinary API secret
CLOUDINARY_API_SECRET=your_cloudinary_secret_here

# Optional: Override defaults
SUPABASE_URL=https://joamynsevhhhiwynidxp.supabase.co
CLOUDINARY_CLOUD_NAME=dwq5rsria
CLOUDINARY_API_KEY=442752772473387
```

### 4. Verify Data Structure

Ensure your flickr_collection folder has this structure:
```
scripts/
├── flickr_collection/
│   ├── metadata.json          # Photo metadata (940 entries)
│   └── photos/               # Photo files
│       ├── flickr_12345_photographer.jpg
│       └── ...
├── flickr-bulk-import.js     # Main import script
├── package.json             # Dependencies
└── README_IMPORT.md         # This file
```

## Usage

### Test Run (Recommended First)

```bash
# Dry run - no actual changes made
npm run import:dry-run

# Test with small batch
npm run test
```

### Full Import

```bash
# Import all GPS-enabled photos
npm run import

# Custom batch size
node flickr-bulk-import.js --batch-size=5

# Resume from specific index
node flickr-bulk-import.js --start-index=100
```

### Command Line Options

- `--dry-run` - Run without making actual changes
- `--batch-size=N` - Process N photos per batch (default: 10)  
- `--max-photos=N` - Limit import to N photos total
- `--start-index=N` - Start from photo index N (for resuming)
- `--no-database-check` - Disable database proximity checking (faster, cache-only)
- `--help` - Show full help message

### Key Features

✅ **Database-Aware Duplicate Prevention**: Checks existing spots to prevent duplicates on re-imports  
⚡ **Performance Optimized**: In-memory cache + optional database checking  
📊 **Comprehensive Reporting**: Tracks created vs reused spots with detailed statistics  
🎯 **Smart Proximity Grouping**: Photos within 100m grouped into same spot  
🔧 **Configurable**: Multiple options for different use cases

## What the Script Does

### 1. Data Processing
- Filters 334 GPS-enabled photos from 940 total photos
- Groups photos within 100m into the same spot
- Generates meaningful spot titles from photo metadata

### 2. Photographer Accounts
- Creates Flickr placeholder accounts for each unique photographer
- Generates usernames like `flickr_photographer_name`
- Marks accounts as claimable for future verification

### 3. Photo Upload
- Uploads photos to Cloudinary with organized folder structure
- Preserves metadata and attribution information
- Creates optimized versions for app performance

### 4. Database Records
- Creates spot records with GPS coordinates and reverse geocoding
- Links media records to spots and photographers
- Stores complete attribution and licensing information

## Expected Results

After successful import:
- **~334 new spots** with GPS coordinates
- **~50 placeholder photographer accounts** 
- **334 photos** uploaded to Cloudinary and linked in database
- **Proper attribution** displayed in app photo details

## Monitoring Progress

The script provides detailed logging:
```
🚀 Starting Flickr bulk import...
📋 Loaded 940 total photos, 334 with GPS coordinates
📦 Batch 1/34
📷 Processing: Beautiful mountain landscape
👤 Found existing photographer: nature_photographer
☁️  Uploaded to Cloudinary: flickr_12345_nature_photographer.jpg
🗺️  Created spot: Beautiful mountain landscape
📸 Created media record: flickr_12345_nature_photographer.jpg
✅ Successfully processed: Beautiful mountain landscape
```

## Error Handling

- **Resume Capability**: Use `--start-index` to resume interrupted imports
- **Rate Limiting**: 2-second delays between batches to avoid API limits
- **Error Logging**: Failed photos are logged with specific error messages
- **Rollback**: Database changes can be manually reverted using backup queries

## Troubleshooting

### Common Issues

1. **"SUPABASE_SERVICE_KEY is required"**
   - Get service role key from Supabase Dashboard > Settings > API
   - Make sure it's the service role key, not anon key

2. **"CLOUDINARY_API_SECRET is required"**
   - Get API secret from Cloudinary Dashboard > Settings > Security

3. **"Photo file not found"**
   - Verify flickr_collection/photos/ directory exists
   - Check photo filenames match metadata.json entries

4. **"Failed to create photographer"**
   - Ensure database migration was run successfully
   - Check Supabase connection and permissions

### Performance Tips

- Start with `--dry-run` to validate data and logic
- Use smaller batch sizes (`--batch-size=5`) for more stable uploads
- Monitor Cloudinary upload quota and Supabase database limits
- Run during off-peak hours for better API performance

## Security Notes

- Service role key has elevated permissions - keep secure
- Script creates public spots by default
- All Flickr photos maintain original Creative Commons licensing
- Photographer accounts are marked as claimable for future verification

## Next Steps

After import completion:
1. Verify spot and photo display in the Scenic app
2. Test attribution display in photo details
3. Implement photographer claiming mechanism
4. Consider additional content sources for future imports