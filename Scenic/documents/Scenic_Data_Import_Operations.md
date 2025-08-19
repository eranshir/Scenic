# Scenic — Data Import & Operations Guide

This guide covers data import procedures, database operations, and administrative tasks for the Scenic photography platform.

## Overview

Scenic supports importing photography data from external sources to populate the platform with scenic locations and photos. This guide documents the procedures for safe, reliable data imports and ongoing operations.

## Table of Contents

1. [Flickr Bulk Import System](#flickr-bulk-import-system)
2. [Database Operations](#database-operations)  
3. [Maintenance & Troubleshooting](#maintenance--troubleshooting)
4. [Security & Best Practices](#security--best-practices)

---

## Flickr Bulk Import System

### Overview

The Flickr bulk import system processes curated photo collections and imports them into Scenic's database with proper attribution, GPS coordinates, and metadata preservation.

**Location**: `/scripts/flickr-bulk-import.js`  
**Documentation**: `/scripts/README_IMPORT.md`

### Key Features

✅ **Database-Aware Duplicate Prevention**: Prevents duplicate spots on re-imports  
⚡ **Performance Optimized**: In-memory cache + configurable database checking  
📊 **Comprehensive Reporting**: Detailed progress tracking and error handling  
🎯 **Smart Proximity Grouping**: Groups photos within 100m into same spots  
🔧 **Configurable Options**: Multiple modes for different use cases

### Quick Start

#### Prerequisites

```bash
cd scripts
npm install

# Create .env file with required credentials
cp .env.example .env
# Edit .env with your Supabase service key and Cloudinary credentials
```

#### Basic Usage

```bash
# Test run (recommended first)
node flickr-bulk-import.js --dry-run --max-photos=5

# Full import
node flickr-bulk-import.js

# Import with specific options
node flickr-bulk-import.js --batch-size=5 --max-photos=50
```

### Command Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `--dry-run` | Run without making changes | `--dry-run` |
| `--batch-size=N` | Photos per batch (default: 10) | `--batch-size=5` |
| `--max-photos=N` | Limit total photos imported | `--max-photos=100` |
| `--start-index=N` | Start from specific photo index | `--start-index=50` |
| `--no-database-check` | Disable database proximity checking | `--no-database-check` |
| `--help` | Show comprehensive help | `--help` |

### Expected Results

After successful import:
- **~255 new spots** with GPS coordinates and metadata
- **~311 photos** uploaded to Cloudinary with attribution
- **Complete sun position data** for optimal timing recommendations
- **Proper licensing** and attribution information preserved

### Proximity Grouping Logic

- **100-meter threshold**: Photos within 100m are grouped into the same spot
- **Database-aware**: Checks existing spots to prevent duplicates on re-imports  
- **Smart caching**: In-memory cache for performance, database fallback for accuracy
- **Configurable**: Use `--no-database-check` for faster cache-only mode

---

## Database Operations

### Duplicate Management

The system includes utilities for managing duplicate data:

#### Check for Duplicates
```bash
cd scripts
node check-duplicate-spots.js
```

#### Clean Up Duplicates
```bash
# Dry run first
node cleanup-duplicate-spots.js

# Execute cleanup
node cleanup-duplicate-spots.js --execute
```

### Database Schema

Import operations require the enhanced schema with attribution fields:

```sql
-- Run in Supabase SQL Editor
-- File: /Scenic/Config/supabase_schema_6_attribution.sql
```

Key tables affected:
- `spots`: Photography locations with GPS coordinates
- `media`: Photos with attribution and enhanced metadata  
- `sun_snapshots`: Cached solar position calculations
- `profiles`: Photographer attribution information

### Data Verification

After imports, verify data integrity:

1. **GPS Coordinates**: Check for valid lat/lng values (no NaN)
2. **Attribution**: Verify photographer credits are displayed
3. **Media URLs**: Confirm Cloudinary links are accessible
4. **Sun Data**: Ensure solar calculations completed successfully

---

## Maintenance & Troubleshooting

### Common Issues

#### 1. Import Failures

**Symptom**: "SUPABASE_SERVICE_KEY is required"  
**Solution**: 
- Get service role key from Supabase Dashboard > Settings > API
- Ensure it's the service role key, not anon key
- Add to `.env` file in scripts directory

**Symptom**: "Cloudinary upload failed"  
**Solution**:
- Check Cloudinary API secret in `.env`
- Verify upload quota not exceeded
- Check photo file integrity

#### 2. Duplicate Spots

**Symptom**: iOS app shows more spots than expected  
**Solution**:
```bash
cd scripts
node check-duplicate-spots.js
node cleanup-duplicate-spots.js --execute
```

#### 3. Invalid Coordinates

**Symptom**: "nan, nan" coordinates in iOS app  
**Solution**: 
- Run import with GPS coordinate validation enabled (default)
- Check source photo GPS metadata quality
- Verify database proximity checking is enabled

### Performance Optimization

#### Large Imports (1000+ photos)
- Use `--batch-size=5` for stability
- Enable `--no-database-check` for initial bulk imports
- Run during off-peak hours
- Monitor API quotas (Supabase, Cloudinary)

#### Re-imports and Updates
- Keep database checking enabled (default)
- Use `--start-index` to resume interrupted imports
- Verify proximity threshold suitable for data density

### Monitoring

The import system provides detailed logging:

```
🚀 Starting Flickr bulk import...
📋 Loaded 940 total photos, 334 with GPS coordinates  
🎯 Found nearby spot in database: "Mountain View" (45m away)
📍 Using existing nearby spot from database: Mountain View
📸 Created media record: flickr_12345_photographer.jpg
✅ Successfully processed: Mountain View

📊 IMPORT SUMMARY
Created spots: 123 🆕
Reused existing spots: 45 ♻️
Database proximity checking: ✅ Enabled (100m threshold)
```

---

## Security & Best Practices

### Credential Management

- **Service Role Key**: Keep secure, has elevated database permissions
- **Cloudinary Secret**: Required for media uploads
- **Environment Variables**: Never commit `.env` files to version control

### Data Privacy

- **Attribution**: All imports preserve original photographer credits
- **Licensing**: Maintains Creative Commons licensing from source
- **GPS Data**: Only public locations with photographer consent

### Backup Strategy

Before major imports:
1. **Database Backup**: Export current spots/media tables
2. **Cloudinary**: Document current usage/quotas  
3. **Rollback Plan**: Prepare cleanup queries if needed

### Production Considerations

- **Rate Limiting**: Built-in delays prevent API abuse
- **Error Recovery**: Resumable imports with `--start-index`
- **Monitoring**: Detailed logs for audit trails
- **Testing**: Always run `--dry-run` first

---

## Future Enhancements

### Planned Features

- **PostGIS Optimization**: Use ST_DWithin for efficient proximity queries
- **Multi-source Support**: Import from additional photo platforms
- **Batch Attribution**: Automated photographer account claiming
- **Admin Dashboard**: Web interface for import management

### Performance Improvements

- **Streaming Processing**: Handle larger datasets efficiently
- **Parallel Uploads**: Multiple Cloudinary uploads simultaneously  
- **Smart Caching**: Persistent cache between import sessions
- **Delta Imports**: Only process new/changed photos

---

## Support & Resources

### Documentation References
- [**Scripts Reference Guide**](../../scripts/SCRIPTS_REFERENCE.md) - Complete script documentation & usage
- [Import Setup Guide](../../scripts/README_IMPORT.md) - Detailed setup instructions
- [Database Schema](../Config/) - SQL migration files
- [CLAUDE.md](../CLAUDE.md) - Development context

### Getting Help

1. **Logs**: Check import logs for specific error messages
2. **Dry Run**: Use `--dry-run` to validate before executing  
3. **Small Batches**: Test with `--max-photos=5` first
4. **Documentation**: Review `/scripts/README_IMPORT.md` for detailed guidance

### Version History

- **v0.1.2**: Enhanced import system with database-aware duplicate prevention
- **v0.1.1**: Initial Flickr import pipeline with attribution support
- **v0.1.0**: Basic import framework with Cloudinary integration

---

*Last Updated: August 2025*  
*Version: v0.1.2*