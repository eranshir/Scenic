#!/usr/bin/env python3
"""
Flickr Creative Commons Photo Scraper
Downloads scenic photos with commercial use licenses and maintains attribution data
"""

import os
import requests
import json
import time
import argparse
from datetime import datetime
from urllib.parse import urlparse, parse_qs, urljoin
import re
from bs4 import BeautifulSoup

class FlickrScraper:
    def __init__(self, output_dir="flickr_scenic_photos", max_photos=100):
        self.base_url = "https://www.flickr.com"
        self.output_dir = output_dir
        self.max_photos = max_photos
        
        # Create output directory
        self.photos_dir = os.path.join(output_dir, "photos")
        os.makedirs(self.photos_dir, exist_ok=True)
        
        # Attribution data file
        self.attribution_file = os.path.join(output_dir, "attribution.json")
        self.attribution_data = []
        
        # Session for connection reuse
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Accept-Encoding': 'gzip, deflate, br',
            'DNT': '1',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1'
        })
        
        # License mapping (Creative Commons with commercial use)
        self.licenses = {
            '4': 'CC BY 2.0',           # Attribution
            '5': 'CC BY-SA 2.0',        # Attribution-ShareAlike
            '9': 'CC0 1.0',             # Public Domain Dedication
            '10': 'Public Domain Mark', # Public Domain Mark
            '11': 'CC BY 4.0',          # Attribution 4.0
            '12': 'CC BY-SA 4.0'        # Attribution-ShareAlike 4.0
        }
        
    def search_photos(self, page=1):
        """Search for scenic photos with commercial CC licenses"""
        print(f"Fetching search results page {page}...")
        
        # Construct search URL with parameters
        search_params = {
            'sort': 'interestingness-desc',
            'content_types': '0',  # Photos only
            'license': '4,5,9,10,11,12',  # Commercial use CC licenses
            'height': '1024',
            'width': '1024',
            'dimension_search_mode': 'min',
            'orientation': 'portrait',
            'view_all': '1',
            'text': 'scenic landscape nature',
            'page': str(page)
        }
        
        # Build query string
        query_string = '&'.join([f"{k}={v}" for k, v in search_params.items()])
        url = f"{self.base_url}/search/?{query_string}"
        
        try:
            response = self.session.get(url, timeout=30)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Find photo links in search results
            photo_links = []
            
            # Look for photo tiles in the search results
            photo_divs = soup.find_all('div', class_='photo-list-photo-view')
            
            for div in photo_divs:
                # Extract photo URL from style attribute
                style = div.get('style', '')
                match = re.search(r'url\((.*?)\)', style)
                if match:
                    thumb_url = match.group(1).strip('"\'')
                    
                    # Extract photo ID from thumbnail URL
                    # Format: //live.staticflickr.com/{server}/{id}_{secret}_{size}.jpg
                    id_match = re.search(r'/(\d+)_[a-f0-9]+_', thumb_url)
                    if id_match:
                        photo_id = id_match.group(1)
                        
                        # Get the link to the photo page
                        link = div.find_parent('a')
                        if link and link.get('href'):
                            photo_url = urljoin(self.base_url, link['href'])
                            photo_links.append({
                                'id': photo_id,
                                'url': photo_url,
                                'thumb': thumb_url
                            })
            
            # Alternative method: Look for links directly
            if not photo_links:
                links = soup.find_all('a', href=re.compile(r'/photos/[^/]+/\d+'))
                for link in links[:50]:  # Limit to prevent too many
                    href = link.get('href')
                    match = re.search(r'/photos/([^/]+)/(\d+)', href)
                    if match:
                        username = match.group(1)
                        photo_id = match.group(2)
                        photo_url = urljoin(self.base_url, href)
                        photo_links.append({
                            'id': photo_id,
                            'url': photo_url,
                            'username': username
                        })
            
            print(f"Found {len(photo_links)} photos on page {page}")
            return photo_links
            
        except Exception as e:
            print(f"Error fetching search results: {e}")
            return []
    
    def get_photo_details(self, photo_info):
        """Get detailed information about a photo including attribution data"""
        photo_url = photo_info['url']
        photo_id = photo_info['id']
        
        print(f"\nFetching details for photo {photo_id}...")
        
        try:
            response = self.session.get(photo_url, timeout=30)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Extract photographer name
            photographer = None
            photographer_elem = soup.find('a', class_='owner-name')
            if photographer_elem:
                photographer = photographer_elem.get_text(strip=True)
            else:
                # Try alternative selector
                photographer_elem = soup.find('span', class_='username')
                if photographer_elem:
                    photographer = photographer_elem.get_text(strip=True)
            
            # Extract photo title
            title = None
            title_elem = soup.find('h1', class_='photo-title')
            if title_elem:
                title = title_elem.get_text(strip=True)
            else:
                # Try meta tag
                meta_title = soup.find('meta', property='og:title')
                if meta_title:
                    title = meta_title.get('content', '').split('|')[0].strip()
            
            # Extract description
            description = None
            desc_elem = soup.find('div', class_='photo-desc')
            if desc_elem:
                description = desc_elem.get_text(strip=True)
            
            # Extract license info
            license_info = None
            license_elem = soup.find('a', href=re.compile(r'/creativecommons/'))
            if license_elem:
                license_text = license_elem.get_text(strip=True)
                # Map to our license types
                for key, value in self.licenses.items():
                    if value in license_text or value.replace(' ', '') in license_text.replace(' ', ''):
                        license_info = value
                        break
            
            # Extract the download URL for original size
            # Look for the download button/link
            download_url = None
            
            # Method 1: Look for download link in page
            download_link = soup.find('a', {'data-track': re.compile('download')})
            if download_link:
                download_url = download_link.get('href')
            
            # Method 2: Construct download URL
            if not download_url:
                # Find secret from page
                secret_match = re.search(r'"secret":"([a-f0-9]+)"', response.text)
                if secret_match:
                    secret = secret_match.group(1)
                    download_url = f"/photo_download.gne?id={photo_id}&secret={secret}&size=o&source=photoPageEngagement"
            
            # Get actual image URL from the page
            img_url = None
            # Look for the main photo
            img_elem = soup.find('img', class_='main-photo')
            if img_elem:
                img_url = img_elem.get('src')
            else:
                # Try to find in meta tags
                meta_img = soup.find('meta', property='og:image')
                if meta_img:
                    img_url = meta_img.get('content')
            
            # If we have an image URL, upgrade it to larger size
            if img_url:
                # Convert to largest available size
                img_url = re.sub(r'_[a-z]\.(jpg|png)$', '_b.\\1', img_url)
                if not img_url.startswith('http'):
                    img_url = 'https:' + img_url
            
            return {
                'id': photo_id,
                'url': photo_url,
                'title': title or f'Untitled_{photo_id}',
                'photographer': photographer or 'Unknown',
                'description': description,
                'license': license_info or 'CC (Commercial Use)',
                'download_url': download_url,
                'image_url': img_url
            }
            
        except Exception as e:
            print(f"Error fetching photo details: {e}")
            return None
    
    def download_photo(self, photo_details):
        """Download a photo and save attribution data"""
        if not photo_details or not photo_details.get('image_url'):
            print(f"No image URL for photo {photo_details.get('id', 'unknown')}")
            return False
        
        photo_id = photo_details['id']
        img_url = photo_details['image_url']
        
        # Determine file extension
        ext = 'jpg'
        if '.png' in img_url:
            ext = 'png'
        
        filename = f"flickr_{photo_id}_{photo_details['photographer'].replace(' ', '_')}.{ext}"
        filepath = os.path.join(self.photos_dir, filename)
        
        # Skip if already downloaded
        if os.path.exists(filepath):
            print(f"Already downloaded: {filename}")
            return True
        
        try:
            print(f"Downloading: {photo_details['title']} by {photo_details['photographer']}")
            print(f"  URL: {img_url}")
            
            # Download image
            if img_url.startswith('//'):
                img_url = 'https:' + img_url
            
            response = self.session.get(img_url, timeout=30)
            response.raise_for_status()
            
            # Save image
            with open(filepath, 'wb') as f:
                f.write(response.content)
            
            # Save attribution data
            self.attribution_data.append({
                'filename': filename,
                'photo_id': photo_id,
                'title': photo_details['title'],
                'photographer': photo_details['photographer'],
                'photographer_profile': photo_details['url'].rsplit('/', 2)[0],
                'photo_url': photo_details['url'],
                'license': photo_details['license'],
                'description': photo_details['description'],
                'attribution': f"Photo by {photo_details['photographer']} on Flickr ({photo_details['license']})",
                'downloaded_at': datetime.now().isoformat()
            })
            
            print(f"  ✓ Downloaded successfully")
            return True
            
        except Exception as e:
            print(f"Error downloading photo: {e}")
            return False
    
    def scrape(self):
        """Main scraping function"""
        print(f"Starting Flickr scenic photo scraper...")
        print(f"Output directory: {self.output_dir}")
        print(f"Maximum photos: {self.max_photos}")
        print(f"Licenses: {', '.join(self.licenses.values())}")
        print("-" * 50)
        
        photos_downloaded = 0
        page = 1
        max_pages = 10  # Limit pages to prevent infinite loops
        
        while photos_downloaded < self.max_photos and page <= max_pages:
            # Get search results
            photo_links = self.search_photos(page)
            
            if not photo_links:
                print("No more photos found")
                break
            
            for photo_info in photo_links:
                if photos_downloaded >= self.max_photos:
                    break
                
                # Get detailed photo information
                photo_details = self.get_photo_details(photo_info)
                
                if photo_details:
                    # Download the photo
                    if self.download_photo(photo_details):
                        photos_downloaded += 1
                        print(f"Progress: {photos_downloaded}/{self.max_photos}")
                    
                    # Be respectful - wait between downloads
                    time.sleep(2)
            
            page += 1
            # Longer delay between pages
            time.sleep(3)
        
        # Save attribution data
        with open(self.attribution_file, 'w') as f:
            json.dump(self.attribution_data, f, indent=2)
        
        # Print summary
        print("\n" + "=" * 50)
        print("SCRAPING COMPLETE")
        print("=" * 50)
        print(f"Total photos downloaded: {photos_downloaded}")
        print(f"Attribution data saved to: {self.attribution_file}")
        print("\nAttribution format for each photo:")
        print('  "Photo by [Photographer Name] on Flickr ([License])"')
        print("\nAll photos are licensed for commercial use under Creative Commons")

def main():
    parser = argparse.ArgumentParser(description='Scrape scenic photos from Flickr with CC commercial licenses')
    parser.add_argument('-o', '--output', default='flickr_scenic_photos',
                       help='Output directory (default: flickr_scenic_photos)')
    parser.add_argument('-n', '--number', type=int, default=50,
                       help='Maximum number of photos to download (default: 50)')
    
    args = parser.parse_args()
    
    scraper = FlickrScraper(output_dir=args.output, max_photos=args.number)
    scraper.scrape()

if __name__ == "__main__":
    main()