# Geograph.org.uk Photo Scraper

This script scrapes photos from Geograph.org.uk's recent photos page and automatically sorts them based on whether they contain GPS coordinates in their EXIF data.

## Features

- Scrapes photos from Geograph.org.uk recent photos page
- Extracts EXIF data from each photo
- Checks for GPS coordinates in EXIF
- Sorts photos into two folders:
  - `photos_with_GPS/` - Photos containing GPS coordinates in EXIF
  - `photos_without_GPS/` - Photos without GPS coordinates in EXIF
- Captures grid references from the website (British/Irish Ordnance Survey grid)
- Saves metadata for all downloaded photos in JSON format including photographer info
- Respects server with delays between requests

## Installation

1. Install Python 3.7 or higher
2. Install required packages:

```bash
pip install -r requirements.txt
```

## Usage

Basic usage (downloads 50 photos by default):
```bash
python geograph_scraper.py
```

Download 100 photos:
```bash
python geograph_scraper.py -n 100
```

Specify output directory:
```bash
python geograph_scraper.py -o /path/to/output -n 100
```

### Command Line Options

- `-n`, `--number`: Maximum number of photos to download (default: 50)
- `-o`, `--output`: Output directory path (default: scraped_photos)

## Output Structure

```
scraped_photos/
├── photos_with_GPS/       # Photos with GPS coordinates in EXIF
│   ├── geograph_123_photo.jpg
│   └── ...
├── photos_without_GPS/    # Photos without GPS coordinates
│   ├── geograph_456_photo.jpg
│   └── ...
└── metadata.json          # Metadata for all downloaded photos
```

## Metadata

The `metadata.json` file contains information about each downloaded photo:
- Photo ID
- Filename
- Title
- Photographer name
- Grid reference (Ordnance Survey)
- Original image URL
- Photo page URL
- GPS coordinates from EXIF (if found)
- Download timestamp

## Notes

- Geograph.org.uk is a geographical photography project covering Britain and Ireland
- All photos are georeferenced to Ordnance Survey grid squares
- Most photos do NOT have GPS coordinates embedded in EXIF data
- The grid references can be converted to lat/long coordinates if needed
- This script specifically checks EXIF data for embedded GPS coordinates

## Respect & Legal

- This script includes delays between requests to be respectful
- Always check the website's terms of service
- Geograph content is typically Creative Commons licensed
- Use responsibly and don't overload the server