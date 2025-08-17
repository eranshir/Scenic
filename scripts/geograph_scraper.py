#!/usr/bin/env python3
"""
Geograph.org.uk Photo Scraper
Scrapes photos from geograph.org.uk recent photos page and sorts them by GPS availability
"""

import os
import requests
from bs4 import BeautifulSoup
import time
from PIL import Image
from PIL.ExifTags import TAGS, GPSTAGS
import io
from urllib.parse import urljoin
import argparse
from datetime import datetime
import json
import re

class GeographScraper:
    def __init__(self, output_dir="scraped_photos", max_photos=100):
        self.base_url = "https://www.geograph.org.uk"
        self.output_dir = output_dir
        self.max_photos = max_photos
        
        # Create output directories
        self.gps_dir = os.path.join(output_dir, "photos_with_GPS")
        self.no_gps_dir = os.path.join(output_dir, "photos_without_GPS")
        os.makedirs(self.gps_dir, exist_ok=True)
        os.makedirs(self.no_gps_dir, exist_ok=True)
        
        # Create metadata file
        self.metadata_file = os.path.join(output_dir, "metadata.json")
        self.metadata = []
        
        # Statistics tracking
        self.stats = {
            'total_downloaded': 0,
            'with_gps': 0,
            'without_gps': 0,
            'failed': 0
        }
        
        # Session for connection reuse
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (compatible; Scenic-Scraper/1.0; +https://github.com/scenic)',
            'Accept': 'image/jpeg,image/png,image/*',
        })
        
    def get_photo_urls_from_recent_page(self, page=1):
        """Get photo URLs from recent photos page"""
        print(f"Fetching recent photos page {page}...")
        
        # Recent photos page with pagination
        url = f"{self.base_url}/finder/recent.php"
        if page > 1:
            url += f"?page={page}"
        
        try:
            response = self.session.get(url, timeout=10)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.text, 'html.parser')
            photos = []
            
            # Find the main thumbs container
            thumbs_div = soup.find('div', class_='thumbs')
            if not thumbs_div:
                print("Could not find thumbs container")
                return []
            
            # Find all photo links within the thumbs container
            photo_links = thumbs_div.find_all('a', href=True)
            
            for link in photo_links:
                if '/photo/' not in link.get('href', ''):
                    continue
                    
                photo_data = {}
                
                # Get photo page URL
                photo_url = urljoin(self.base_url, link['href'])
                photo_data['page_url'] = photo_url
                
                # Extract photo ID from URL
                match = re.search(r'/photo/(\d+)', link['href'])
                if match:
                    photo_data['photo_id'] = match.group(1)
                
                # Get image thumbnail from inside the link
                img = link.find('img')
                if img:
                    # Get thumbnail URL
                    if 'src' in img.attrs:
                        photo_data['thumbnail_url'] = img['src']
                    
                    # Extract title and grid reference from alt text
                    # Format is usually: "GRIDREF : Title by Photographer"
                    alt_text = img.get('alt', '')
                    if alt_text:
                        # Parse the alt text
                        if ' : ' in alt_text:
                            parts = alt_text.split(' : ', 1)
                            photo_data['gridref'] = parts[0]
                            
                            # Parse title and photographer
                            if ' by ' in parts[1]:
                                title_parts = parts[1].rsplit(' by ', 1)
                                photo_data['title'] = title_parts[0]
                                photo_data['photographer'] = title_parts[1] if len(title_parts) > 1 else ''
                            else:
                                photo_data['title'] = parts[1]
                        else:
                            photo_data['title'] = alt_text
                
                if photo_data.get('photo_id'):
                    photos.append(photo_data)
                    
            print(f"Found {len(photos)} photos on page {page}")
            return photos
            
        except Exception as e:
            print(f"Error fetching recent photos page: {e}")
            return []
    
    def get_image_url_from_thumbnail(self, photo_data):
        """Convert thumbnail URL to full-size image URL"""
        # If we have a thumbnail URL, convert it to full size
        # Thumbnail: https://s0.geograph.org.uk/geophotos/08/12/45/8124576_76a4d3ca_120x120.jpg
        # Full size: https://s0.geograph.org.uk/geophotos/08/12/45/8124576_76a4d3ca.jpg
        
        thumbnail_url = photo_data.get('thumbnail_url')
        if thumbnail_url:
            # Simply remove the _120x120 suffix
            full_url = thumbnail_url.replace('_120x120.jpg', '.jpg')
            return full_url
        
        # Fallback: construct URL from photo ID
        photo_id = photo_data.get('photo_id')
        if not photo_id:
            return None
            
        # Try to construct a URL based on common patterns
        # This is less reliable than using the thumbnail URL
        id_str = str(photo_id)
        # Use the pattern from observed URLs: first 2 of last 6 digits / next 2 / next 2
        if len(id_str) >= 6:
            last_six = id_str[-6:]
            dir1 = last_six[0:2]
            dir2 = last_six[2:4]
            dir3 = last_six[4:6]
        else:
            # For shorter IDs, pad and split
            padded = id_str.zfill(6)
            dir1 = padded[0:2]
            dir2 = padded[2:4]
            dir3 = padded[4:6]
        
        # Try common server numbers
        for server_num in range(4):
            url = f"https://s{server_num}.geograph.org.uk/geophotos/{dir1}/{dir2}/{dir3}/{photo_id}.jpg"
            try:
                response = self.session.head(url, timeout=5)
                if response.status_code == 200:
                    return url
            except:
                continue
        
        return None
    
    def get_gps_from_exif(self, img_data):
        """Extract GPS coordinates from EXIF data"""
        try:
            img = Image.open(io.BytesIO(img_data))
            exifdata = img.getexif()
            
            if not exifdata:
                return None
            
            # Look for GPS IFD
            for tag_id, value in exifdata.items():
                tag = TAGS.get(tag_id, tag_id)
                if tag == "GPSInfo":
                    gps_data = {}
                    for gps_tag_id in value:
                        gps_tag = GPSTAGS.get(gps_tag_id, gps_tag_id)
                        gps_data[gps_tag] = value[gps_tag_id]
                    
                    # Extract lat/lon if available
                    if "GPSLatitude" in gps_data and "GPSLongitude" in gps_data:
                        lat = self.convert_to_degrees(gps_data["GPSLatitude"])
                        lon = self.convert_to_degrees(gps_data["GPSLongitude"])
                        
                        # Handle N/S and E/W
                        if gps_data.get("GPSLatitudeRef") == "S":
                            lat = -lat
                        if gps_data.get("GPSLongitudeRef") == "W":
                            lon = -lon
                            
                        return {"latitude": lat, "longitude": lon}
                        
        except Exception as e:
            print(f"Error reading EXIF: {e}")
            
        return None
    
    def convert_to_degrees(self, value):
        """Convert GPS coordinates to degrees"""
        try:
            d, m, s = value
            return d + (m / 60.0) + (s / 3600.0)
        except:
            return 0
    
    def download_and_classify_photo(self, photo_data):
        """Download photo and classify based on GPS data"""
        photo_id = photo_data.get('photo_id')
        if not photo_id:
            return False
            
        # Get image URL
        img_url = self.get_image_url_from_thumbnail(photo_data)
        if not img_url:
            print(f"Could not find image URL for photo {photo_id}")
            return False
            
        try:
            print(f"Downloading photo {photo_id}: {photo_data.get('title', 'Untitled')}")
            print(f"  URL: {img_url}")
            
            response = self.session.get(img_url, timeout=15)
            response.raise_for_status()
            
            img_data = response.content
            
            # Check EXIF for GPS
            gps_coords = self.get_gps_from_exif(img_data)
            
            # Determine filename and directory
            filename = f"geograph_{photo_id}.jpg"
            
            if gps_coords:
                filepath = os.path.join(self.gps_dir, filename)
                has_gps = True
                self.stats['with_gps'] += 1
                print(f"  ✓ GPS in EXIF: {gps_coords['latitude']:.6f}, {gps_coords['longitude']:.6f}")
            else:
                filepath = os.path.join(self.no_gps_dir, filename)
                has_gps = False
                self.stats['without_gps'] += 1
                print(f"  ✗ No GPS in EXIF")
                if photo_data.get('gridref'):
                    print(f"  (Grid reference: {photo_data['gridref']})")
            
            # Save image
            with open(filepath, 'wb') as f:
                f.write(img_data)
            
            # Save metadata
            self.metadata.append({
                "photo_id": photo_id,
                "filename": filename,
                "title": photo_data.get('title', ''),
                "photographer": photo_data.get('photographer', ''),
                "gridref": photo_data.get('gridref', ''),
                "url": img_url,
                "page_url": photo_data.get('page_url', ''),
                "has_gps_exif": has_gps,
                "exif_coords": gps_coords,
                "downloaded_at": datetime.now().isoformat()
            })
            
            self.stats['total_downloaded'] += 1
            return True
            
        except Exception as e:
            print(f"Error downloading {photo_id}: {e}")
            self.stats['failed'] += 1
            return False
    
    def scrape(self):
        """Main scraping function"""
        print(f"Starting Geograph.org.uk scraper...")
        print(f"Output directory: {self.output_dir}")
        print(f"Maximum photos: {self.max_photos}")
        print("-" * 50)
        
        photos_downloaded = 0
        page = 1
        
        while photos_downloaded < self.max_photos:
            photos = self.get_photo_urls_from_recent_page(page)
            
            if not photos:
                print("No more photos found")
                break
            
            for photo_data in photos:
                if photos_downloaded >= self.max_photos:
                    break
                
                if self.download_and_classify_photo(photo_data):
                    photos_downloaded += 1
                    # Print running tally
                    print(f"Progress: {photos_downloaded}/{self.max_photos} | GPS: {self.stats['with_gps']} | No GPS: {self.stats['without_gps']} | Failed: {self.stats['failed']}")
                    print("-" * 70)
                    
                # Be polite - wait between downloads
                time.sleep(2)
                
            page += 1  # Move to next page
            
            # Longer delay between pages
            time.sleep(3)
        
        # Save metadata
        with open(self.metadata_file, 'w') as f:
            json.dump(self.metadata, f, indent=2)
        
        # Print summary
        print("\n" + "=" * 70)
        print("SCRAPING COMPLETE - FINAL STATISTICS")
        print("=" * 70)
        
        print(f"Total photos downloaded: {self.stats['total_downloaded']}")
        print(f"Photos with GPS in EXIF: {self.stats['with_gps']} ({self.stats['with_gps']*100/(self.stats['total_downloaded'] or 1):.1f}%)")
        print(f"Photos without GPS in EXIF: {self.stats['without_gps']} ({self.stats['without_gps']*100/(self.stats['total_downloaded'] or 1):.1f}%)")
        if self.stats['failed'] > 0:
            print(f"Failed downloads: {self.stats['failed']}")
        
        print("-" * 70)
        print(f"Photos saved to: {self.output_dir}/")
        print(f"  With GPS: {self.gps_dir}/")
        print(f"  Without GPS: {self.no_gps_dir}/")
        print(f"Metadata saved to: {self.metadata_file}")
        print("-" * 70)
        print(f"Note: Photos without EXIF GPS still have grid references (UK/Ireland Ordnance Survey)")
        
        # Save statistics to a separate file
        stats_file = os.path.join(self.output_dir, "statistics.json")
        with open(stats_file, 'w') as f:
            json.dump({
                'scrape_date': datetime.now().isoformat(),
                'max_photos_requested': self.max_photos,
                'statistics': self.stats
            }, f, indent=2)
        print(f"Statistics saved to: {stats_file}")

def main():
    parser = argparse.ArgumentParser(description='Scrape photos from Geograph.org.uk recent photos page')
    parser.add_argument('-o', '--output', default='scraped_photos', 
                       help='Output directory (default: scraped_photos)')
    parser.add_argument('-n', '--number', type=int, default=50,
                       help='Maximum number of photos to download (default: 50)')
    
    args = parser.parse_args()
    
    scraper = GeographScraper(output_dir=args.output, max_photos=args.number)
    scraper.scrape()

if __name__ == "__main__":
    main()