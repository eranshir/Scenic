#!/usr/bin/env python3
"""
Enhanced Flickr HTML-based Photo Scraper
Downloads scenic photos with full metadata including descriptions and location
"""

import os
import re
import json
import time
import requests
import argparse
from datetime import datetime
from bs4 import BeautifulSoup
from pathlib import Path

class EnhancedFlickrScraper:
    def __init__(self, html_file, output_dir="flickr_scenic_photos", max_photos=None):
        self.html_file = html_file
        self.output_dir = output_dir
        self.max_photos = max_photos  # None means download all
        
        # Create output directories
        self.photos_dir = os.path.join(output_dir, "photos")
        os.makedirs(self.photos_dir, exist_ok=True)
        
        # Attribution and metadata file
        self.metadata_file = os.path.join(output_dir, "metadata.json")
        self.metadata = []
        
        # Load existing metadata if file exists
        if os.path.exists(self.metadata_file):
            try:
                with open(self.metadata_file, 'r') as f:
                    self.metadata = json.load(f)
                print(f"Loaded {len(self.metadata)} existing metadata entries")
            except:
                self.metadata = []
        
        # Session setup
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        })
        
        # Track failures
        self.failed_downloads = []
    
    def extract_photos_from_html(self):
        """Extract photo information from saved HTML"""
        print(f"Extracting photo information from {self.html_file}...")
        
        with open(self.html_file, 'r', encoding='utf-8') as f:
            html_content = f.read()
        
        # Find all photo URLs in the HTML
        pattern = r'https://www\.flickr\.com/photos/([^/]+)/(\d{8,})'
        matches = re.findall(pattern, html_content)
        
        # Remove duplicates while preserving order
        seen = set()
        photos = []
        for username, photo_id in matches:
            if photo_id not in seen:
                seen.add(photo_id)
                photos.append({
                    'id': photo_id,
                    'username': username,
                    'url': f"https://www.flickr.com/photos/{username}/{photo_id}"
                })
        
        print(f"Found {len(photos)} unique photos")
        
        if self.max_photos:
            return photos[:self.max_photos]
        return photos
    
    def get_photo_metadata(self, photo_info):
        """Extract comprehensive metadata from photo page"""
        photo_id = photo_info['id']
        username = photo_info['username']
        photo_url = photo_info['url']
        
        print(f"\nFetching metadata for photo {photo_id} by {username}...")
        
        try:
            # Get the main photo page for metadata
            response = self.session.get(photo_url, timeout=30)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.text, 'html.parser')
            html_text = response.text
            
            metadata = {
                'photo_id': photo_id,
                'username': username,
                'photo_url': photo_url
            }
            
            # Extract title
            title = "Untitled"
            title_elem = soup.find('h1', class_='photo-title')
            if title_elem:
                title = title_elem.get_text(strip=True)
            else:
                # Try meta tag
                meta_title = soup.find('meta', property='og:title')
                if meta_title:
                    title = meta_title.get('content', '').split('|')[0].strip()
            metadata['title'] = title or f"Photo_{photo_id}"
            
            # Extract description
            description = None
            desc_elem = soup.find('div', class_='photo-desc')
            if desc_elem:
                description = desc_elem.get_text(strip=True)
            else:
                # Try meta description
                meta_desc = soup.find('meta', property='og:description')
                if meta_desc:
                    description = meta_desc.get('content', '')
            metadata['description'] = description
            
            # Extract location information
            location_data = {}
            
            # Method 1: Look for location in the page
            location_elem = soup.find('a', class_='location-link')
            if location_elem:
                location_data['name'] = location_elem.get_text(strip=True)
                location_data['url'] = 'https://www.flickr.com' + location_elem.get('href', '')
            
            # Method 2: Extract from JavaScript/JSON-LD data
            # Look for coordinates in the page source
            lat_match = re.search(r'"latitude":\s*([-\d.]+)', html_text)
            lon_match = re.search(r'"longitude":\s*([-\d.]+)', html_text)
            
            if lat_match and lon_match:
                try:
                    location_data['latitude'] = float(lat_match.group(1))
                    location_data['longitude'] = float(lon_match.group(1))
                except:
                    pass
            
            # Look for place names in structured data
            place_matches = re.findall(r'"name":\s*"([^"]+)"[^}]*"@type":\s*"Place"', html_text)
            if place_matches:
                location_data['place_name'] = place_matches[0]
            
            # Look for country/region
            country_match = re.search(r'"addressCountry":\s*"([^"]+)"', html_text)
            region_match = re.search(r'"addressRegion":\s*"([^"]+)"', html_text)
            
            if country_match:
                location_data['country'] = country_match.group(1)
            if region_match:
                location_data['region'] = region_match.group(1)
            
            metadata['location'] = location_data if location_data else None
            
            # Extract tags
            tags = []
            tag_links = soup.find_all('a', class_='tag')
            for tag in tag_links:
                tag_text = tag.get_text(strip=True)
                if tag_text:
                    tags.append(tag_text)
            metadata['tags'] = tags
            
            # Extract date taken
            date_taken = None
            date_elem = soup.find('span', class_='date-taken')
            if date_elem:
                date_taken = date_elem.get_text(strip=True)
            else:
                # Try to find in meta tags or structured data
                date_match = re.search(r'"dateCreated":\s*"([^"]+)"', html_text)
                if date_match:
                    date_taken = date_match.group(1)
            metadata['date_taken'] = date_taken
            
            # Extract photographer's real name if available
            photographer_name = username
            author_elem = soup.find('span', class_='attribution-info')
            if author_elem:
                name_text = author_elem.get_text(strip=True)
                if name_text and name_text != username:
                    photographer_name = name_text
            metadata['photographer_name'] = photographer_name
            
            # Extract view count
            views = None
            view_match = re.search(r'([\d,]+)\s*views?', html_text, re.IGNORECASE)
            if view_match:
                views = view_match.group(1).replace(',', '')
            metadata['views'] = views
            
            # Extract license information
            license_info = "CC (See Flickr for specific license)"
            license_elem = soup.find('a', href=re.compile(r'/creativecommons/'))
            if license_elem:
                license_info = license_elem.get_text(strip=True)
            metadata['license'] = license_info
            
            return metadata
            
        except Exception as e:
            print(f"  Error fetching metadata: {e}")
            return None
    
    def download_photo_with_metadata(self, photo_info, metadata):
        """Download photo from sizes page and save with metadata"""
        photo_id = photo_info['id']
        username = photo_info['username']
        
        print(f"  Downloading photo {photo_id}...")
        
        # Get the sizes page
        sizes_url = f"https://www.flickr.com/photos/{username}/{photo_id}/sizes/"
        
        try:
            response = self.session.get(sizes_url, timeout=30)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Find the download URL
            download_url = None
            image_url = None
            
            # Look for download links
            download_links = soup.find_all('a', href=True)
            for link in download_links:
                href = link.get('href')
                link_text = link.get_text(strip=True).lower()
                
                if 'download' in link_text or 'original' in link_text:
                    if href.startswith('//'):
                        download_url = 'https:' + href
                    elif href.startswith('http'):
                        download_url = href
                    if download_url:
                        break
            
            # Fallback to displayed image
            if not download_url:
                img_elem = soup.find('div', id='allsizes-photo')
                if img_elem:
                    img_tag = img_elem.find('img')
                    if img_tag and img_tag.get('src'):
                        image_url = img_tag['src']
                        if image_url.startswith('//'):
                            image_url = 'https:' + image_url
            
            final_url = download_url or image_url
            
            if not final_url:
                print(f"    ✗ Could not find download URL")
                self.failed_downloads.append(photo_id)
                return False
            
            # Clean username for filename
            clean_username = re.sub(r'[^a-zA-Z0-9_-]', '_', username)
            filename = f"flickr_{photo_id}_{clean_username}.jpg"
            filepath = os.path.join(self.photos_dir, filename)
            
            # Skip if already exists
            if os.path.exists(filepath):
                print(f"    Already downloaded: {filename}")
                # Check if metadata already exists for this photo
                existing_ids = [m.get('photo_id') for m in self.metadata]
                if photo_id not in existing_ids:
                    # Still add metadata even if photo exists
                    metadata['filename'] = filename
                    metadata['downloaded_at'] = datetime.now().isoformat()
                    metadata['file_size'] = os.path.getsize(filepath)
                    self.metadata.append(metadata)
                    # Save metadata immediately
                    with open(self.metadata_file, 'w') as f:
                        json.dump(self.metadata, f, indent=2)
                return True
            
            # Download the image
            img_response = self.session.get(final_url, timeout=60)
            img_response.raise_for_status()
            
            # Save the image
            with open(filepath, 'wb') as f:
                f.write(img_response.content)
            
            # Add file info to metadata
            metadata['filename'] = filename
            metadata['downloaded_at'] = datetime.now().isoformat()
            metadata['file_size'] = os.path.getsize(filepath)
            metadata['download_url'] = final_url
            
            # Create attribution strings
            photographer = metadata.get('photographer_name', username)
            metadata['attribution'] = f"Photo by {photographer} on Flickr"
            metadata['attribution_html'] = f'Photo by <a href="{photo_info["url"]}">{photographer}</a> on Flickr'
            
            self.metadata.append(metadata)
            
            # Save metadata immediately after each download
            with open(self.metadata_file, 'w') as f:
                json.dump(self.metadata, f, indent=2)
            
            print(f"    ✓ Downloaded: {filename} ({metadata['file_size'] / 1024 / 1024:.1f} MB)")
            
            # Print location if available
            if metadata.get('location'):
                loc = metadata['location']
                if 'latitude' in loc and 'longitude' in loc:
                    print(f"    📍 Location: {loc.get('place_name', 'Unknown')} ({loc['latitude']:.4f}, {loc['longitude']:.4f})")
                elif 'name' in loc:
                    print(f"    📍 Location: {loc['name']}")
            
            return True
            
        except Exception as e:
            print(f"    ✗ Download error: {e}")
            self.failed_downloads.append(photo_id)
            return False
    
    def scrape(self):
        """Main scraping function"""
        print(f"Starting Enhanced Flickr Scraper...")
        print(f"HTML file: {self.html_file}")
        print(f"Output directory: {self.output_dir}")
        print(f"Maximum photos: {self.max_photos or 'All'}")
        print("-" * 50)
        
        # Extract photo information from HTML
        photos = self.extract_photos_from_html()
        
        if not photos:
            print("No photos found in HTML file")
            return
        
        photos_downloaded = 0
        photos_skipped = 0
        
        total_photos = len(photos)
        
        for idx, photo_info in enumerate(photos, 1):
            print(f"\n[{idx}/{total_photos}] Processing {photo_info['id']}...")
            
            # Get comprehensive metadata
            metadata = self.get_photo_metadata(photo_info)
            
            if metadata:
                # Download the photo with metadata
                if self.download_photo_with_metadata(photo_info, metadata):
                    photos_downloaded += 1
                else:
                    photos_skipped += 1
            else:
                photos_skipped += 1
                self.failed_downloads.append(photo_info['id'])
            
            # Progress update
            if idx % 10 == 0:
                print(f"\n=== Progress: {idx}/{total_photos} processed, {photos_downloaded} downloaded ===\n")
            
            # Be respectful with rate limiting
            time.sleep(1.5)
        
        # Metadata is already saved incrementally after each download
        
        # Save failed downloads list
        if self.failed_downloads:
            failed_file = os.path.join(self.output_dir, "failed_downloads.json")
            with open(failed_file, 'w') as f:
                json.dump(self.failed_downloads, f, indent=2)
        
        # Print summary
        print("\n" + "=" * 60)
        print("SCRAPING COMPLETE")
        print("=" * 60)
        print(f"Total photos processed: {total_photos}")
        print(f"Successfully downloaded: {photos_downloaded}")
        print(f"Skipped/Failed: {photos_skipped}")
        
        if self.failed_downloads:
            print(f"Failed photo IDs saved to: failed_downloads.json")
        
        print(f"\nMetadata saved to: {self.metadata_file}")
        
        # Show statistics about location data
        photos_with_location = sum(1 for m in self.metadata if m.get('location'))
        photos_with_coords = sum(1 for m in self.metadata if m.get('location', {}).get('latitude'))
        photos_with_desc = sum(1 for m in self.metadata if m.get('description'))
        photos_with_tags = sum(1 for m in self.metadata if m.get('tags'))
        
        print(f"\nMetadata Statistics:")
        print(f"  Photos with descriptions: {photos_with_desc}")
        print(f"  Photos with location data: {photos_with_location}")
        print(f"  Photos with GPS coordinates: {photos_with_coords}")
        print(f"  Photos with tags: {photos_with_tags}")
        
        if self.metadata:
            print(f"\nSample metadata entry:")
            sample = self.metadata[0]
            print(f"  Title: {sample.get('title', 'N/A')}")
            print(f"  Photographer: {sample.get('photographer_name', 'N/A')}")
            if sample.get('location'):
                print(f"  Location: {sample['location']}")
            if sample.get('tags'):
                print(f"  Tags: {', '.join(sample['tags'][:5])}")

def main():
    parser = argparse.ArgumentParser(description='Enhanced Flickr scraper with full metadata extraction')
    parser.add_argument('html_file', nargs='?',
                       default='/Users/eranshir/Documents/Projects/scenic/Scenic/Scenic/documents/spots/Search_ scenic _ Flickr3.html',
                       help='Path to saved Flickr search HTML file')
    parser.add_argument('-o', '--output', default='flickr_collection',
                       help='Output directory (default: flickr_collection)')
    parser.add_argument('-n', '--number', type=int, default=None,
                       help='Maximum number of photos to download (default: all)')
    
    args = parser.parse_args()
    
    # Check if HTML file exists
    if not os.path.exists(args.html_file):
        print(f"Error: HTML file not found: {args.html_file}")
        return
    
    scraper = EnhancedFlickrScraper(
        html_file=args.html_file,
        output_dir=args.output,
        max_photos=args.number
    )
    scraper.scrape()

if __name__ == "__main__":
    main()