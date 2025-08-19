# Scenic Scripts Reference Guide

This document provides a comprehensive reference for all scripts in the Scenic project, including their purpose, usage, and command-line options.

## 📋 Table of Contents

- [🏗️ Setup Scripts](#️-setup-scripts)
- [📥 Import Scripts](#-import-scripts)  
- [🗃️ Data Management Scripts](#️-data-management-scripts)
- [🧪 Development & Testing Scripts](#-development--testing-scripts)
- [🔍 Utility Scripts](#-utility-scripts)

---

## 🏗️ Setup Scripts

### `setup_env.sh`
**Purpose**: Environment setup and validation for local development  
**When to use**: Initial project setup, credential validation  
**Prerequisites**: None

```bash
# Make executable and run
chmod +x setup_env.sh
./setup_env.sh

# Options:
# --validate    # Only validate existing environment
# --create      # Create new .env.local from template
```

**What it does:**
- Creates `.env.local` from template if missing
- Validates required environment variables
- Checks connectivity to Supabase and Cloudinary
- Provides setup guidance for missing credentials

### `setup_coredata.sh`
**Purpose**: Initialize Core Data model and migrations  
**When to use**: iOS development setup, model updates  
**Prerequisites**: Xcode project setup

```bash
chmod +x setup_coredata.sh
./setup_coredata.sh
```

**What it does:**
- Validates Core Data model consistency
- Generates model versions and migrations
- Updates Xcode project configurations
- Provides Core Data debugging information

### `create_cloudinary_preset.sh`
**Purpose**: Create Cloudinary upload presets for the project  
**When to use**: Initial Cloudinary setup  
**Prerequisites**: Cloudinary account and API credentials

```bash
chmod +x create_cloudinary_preset.sh
./create_cloudinary_preset.sh
```

**What it does:**
- Creates upload presets for different image sizes
- Configures transformations and quality settings
- Sets up folder structure in Cloudinary
- Validates preset creation

---

## 📥 Import Scripts

### `flickr-bulk-import.js` ⭐ **Primary Import Tool**
**Purpose**: Import curated Flickr photo collections with full metadata  
**When to use**: Populate database with scenic photography locations  
**Prerequisites**: Node.js, Supabase service key, Cloudinary credentials

```bash
# Basic usage
node flickr-bulk-import.js

# Common options
node flickr-bulk-import.js --dry-run --max-photos=5      # Test run
node flickr-bulk-import.js --batch-size=5 --max-photos=50  # Custom batch
node flickr-bulk-import.js --start-index=100            # Resume import
node flickr-bulk-import.js --no-database-check          # Fast mode

# All options
--dry-run              # Run without making changes
--batch-size=N         # Photos per batch (default: 10)
--max-photos=N         # Limit total photos imported
--start-index=N        # Start from specific photo index
--no-database-check    # Disable database proximity checking
--help                 # Show comprehensive help
```

**Features:**
- Database-aware duplicate prevention
- Smart proximity grouping (100m threshold)
- Comprehensive error handling and resumption
- Complete metadata preservation including attribution

### `flickr_enhanced_scraper.py`
**Purpose**: Enhanced scraping from Flickr with metadata extraction  
**When to use**: Collect photos for bulk import preparation  
**Prerequisites**: Python 3.7+, pip requirements

```bash
# Install dependencies
pip install -r requirements.txt

# Basic usage  
python flickr_enhanced_scraper.py

# Options
python flickr_enhanced_scraper.py --limit 100       # Limit photos
python flickr_enhanced_scraper.py --query "scenic"  # Search query
python flickr_enhanced_scraper.py --output ./data   # Output directory
```

### `geograph_scraper.py`
**Purpose**: Scrape photos from Geograph.org.uk (British/Irish photography)  
**When to use**: Import UK/Ireland specific scenic locations  
**Prerequisites**: Python 3.7+, pip requirements

```bash
# Basic usage (downloads 50 photos by default)
python geograph_scraper.py

# Options
python geograph_scraper.py -n 100            # Download 100 photos
python geograph_scraper.py -o /path/to/output # Custom output directory
```

**Output Structure:**
- `photos_with_GPS/` - Photos with GPS coordinates
- `photos_without_GPS/` - Photos without GPS
- `metadata.json` - Complete photo metadata

---

## 🗃️ Data Management Scripts

### `cleanup-duplicate-spots.js`
**Purpose**: Remove duplicate spots from database  
**When to use**: After imports to clean up duplicates  
**Prerequisites**: Node.js, Supabase service key

```bash
# Dry run first (recommended)
node cleanup-duplicate-spots.js

# Execute cleanup
node cleanup-duplicate-spots.js --execute
```

**What it does:**
- Identifies spots with identical coordinates
- Keeps oldest spot for each location
- Removes associated media and sun snapshots
- Provides detailed cleanup report

### `cleanup-all-data.js`
**Purpose**: Complete database cleanup (⚠️ DESTRUCTIVE)  
**When to use**: Development reset, start fresh  
**Prerequisites**: Node.js, Supabase service key

```bash
# CAUTION: This deletes all data
node cleanup-all-data.js --confirm-destructive
```

**What it does:**
- Deletes ALL spots, media, and sun snapshots
- Clears Cloudinary references
- Resets database to clean state
- Requires explicit confirmation flag

### `cleanup-flickr-data.js`
**Purpose**: Remove only Flickr-imported data  
**When to use**: Clean up Flickr imports while keeping user data  
**Prerequisites**: Node.js, Supabase service key

```bash
# Removes Flickr-imported spots and media only
node cleanup-flickr-data.js
```

### `check-duplicate-spots.js`
**Purpose**: Analyze database for duplicate spots  
**When to use**: Database health checks, before cleanup  
**Prerequisites**: Node.js, Supabase service key

```bash
# Check for duplicates without making changes
node check-duplicate-spots.js
```

**Output:**
- Summary of duplicate groups
- Detailed list of duplicate spots
- Coordinate analysis and recommendations

---

## 🧪 Development & Testing Scripts

### `check_coords.js`
**Purpose**: Validate GPS coordinates in database  
**When to use**: Debug coordinate issues, data validation  
**Prerequisites**: Node.js, Supabase service key

```bash
# Check first 15 spots for coordinate validity
node check_coords.js
```

**What it checks:**
- Coordinate data types and finite values
- Latitude range (-90 to +90)
- Longitude range (-180 to +180)
- NaN and undefined detection

---

## 🔍 Utility Scripts

### Legacy Flickr Scripts

These scripts are preserved for reference but not actively used:

- **`flickr_api_scraper.py`**: Direct Flickr API scraping
- **`flickr_html_scraper.py`**: HTML-based Flickr scraping  
- **`flickr_scraper.py`**: Basic Flickr photo collection

```bash
# Basic usage (if needed)
python flickr_api_scraper.py --key YOUR_API_KEY
```

---

## 🚀 Common Workflows

### Initial Project Setup
```bash
1. ./setup_env.sh                    # Environment setup
2. ./setup_coredata.sh              # Core Data setup  
3. ./create_cloudinary_preset.sh    # Cloudinary configuration
```

### Import Photo Collection
```bash
1. node flickr-bulk-import.js --dry-run --max-photos=5  # Test
2. node check-duplicate-spots.js                        # Verify clean
3. node flickr-bulk-import.js                          # Full import
4. node cleanup-duplicate-spots.js --execute           # Clean duplicates
```

### Database Maintenance
```bash
1. node check_coords.js              # Validate coordinates
2. node check-duplicate-spots.js     # Check for duplicates
3. node cleanup-duplicate-spots.js   # Clean if needed
```

### Development Reset
```bash
1. node cleanup-all-data.js --confirm-destructive  # ⚠️ Clean slate
2. node flickr-bulk-import.js --max-photos=10      # Small test dataset
```

---

## ⚙️ Configuration Files

### Required Files
- **`.env`**: Environment variables (Supabase, Cloudinary credentials)
- **`package.json`**: Node.js dependencies for import scripts
- **`requirements.txt`**: Python dependencies for scraping scripts

### Optional Files  
- **`.env.local`**: Local development overrides
- **`flickr_collection/`**: Photo data directory for imports

---

## 🛡️ Safety & Best Practices

### Before Running Scripts
1. **Always run `--dry-run` first** for import and cleanup scripts
2. **Backup important data** before destructive operations
3. **Check your credentials** in `.env` file
4. **Start with small batches** (`--max-photos=5`) for testing

### Error Handling
- Most scripts include comprehensive error logging
- Import scripts support resumption with `--start-index`
- Cleanup scripts require explicit confirmation for destructive operations
- All database operations respect foreign key constraints

### Performance Tips
- Use `--batch-size=5` for slower, more stable imports
- Enable `--no-database-check` for large initial imports
- Run imports during off-peak hours for better API performance
- Monitor API quotas (Supabase, Cloudinary) during large operations

---

## 🆘 Troubleshooting

### Common Issues

**"SUPABASE_SERVICE_KEY is required"**
```bash
# Check your .env file
cat .env
# Run environment setup
./setup_env.sh --validate
```

**"Cloudinary upload failed"**
```bash  
# Verify Cloudinary credentials
./create_cloudinary_preset.sh
# Check upload quotas in Cloudinary dashboard
```

**Import hangs or fails**
```bash
# Resume from last successful index
node flickr-bulk-import.js --start-index=50
# Use smaller batch size
node flickr-bulk-import.js --batch-size=3
```

**Too many duplicate spots**
```bash
# Check duplicates first
node check-duplicate-spots.js
# Clean them up
node cleanup-duplicate-spots.js --execute
```

---

## 📚 Additional Resources

- **Main Documentation**: [Data Import & Operations Guide](../Scenic/documents/Scenic_Data_Import_Operations.md)
- **Import Setup**: [README_IMPORT.md](README_IMPORT.md)
- **Project Overview**: [README.md](../README.md)

---

*Last Updated: August 2025*  
*Version: v0.1.2*