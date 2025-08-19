#!/usr/bin/env python3
"""
Flickr HTML-based Photo Scraper
Downloads scenic photos using saved HTML search results
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

class FlickrHTMLScraper:
    def __init__(self, html_file, output_dir="flickr_scenic_photos", max_photos=100):
        self.html_file = html_file
        self.output_dir = output_dir
        self.max_photos = max_photos
        
        # Create output directories
        self.photos_dir = os.path.join(output_dir, "photos")
        os.makedirs(self.photos_dir, exist_ok=True)
        
        # Attribution data file
        self.attribution_file = os.path.join(output_dir, "attribution.json")
        self.attribution_data = []
        
        # Session setup
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        })
    
    def extract_photos_from_html(self):
        """Extract photo information from saved HTML"""
        print(f"Extracting photo information from {self.html_file}...")
        
        with open(self.html_file, 'r', encoding='utf-8') as f:
            html_content = f.read()
        
        # Find all photo URLs in the HTML
        # Pattern: https://www.flickr.com/photos/{username}/{photo_id}
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
        return photos[:self.max_photos]
    
    def get_photo_sizes_url(self, photo_id, username):
        """Construct the sizes page URL for a photo"""
        return f"https://www.flickr.com/photos/{username}/{photo_id}/sizes/"
    
    def download_photo_from_sizes(self, photo_info):
        """Download photo using the sizes page"""
        photo_id = photo_info['id']
        username = photo_info['username']
        
        print(f"\nProcessing photo {photo_id} by {username}...")
        
        # Get the sizes page
        sizes_url = self.get_photo_sizes_url(photo_id, username)
        
        try:
            response = self.session.get(sizes_url, timeout=30)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Extract photo title
            title = "Untitled"
            title_elem = soup.find('h1')
            if title_elem:
                title_text = title_elem.get_text(strip=True)
                # Clean up the title (remove "All sizes", etc.)
                title = re.sub(r'All sizes.*?of\s+', '', title_text).strip()
                if not title or title == "All sizes":
                    title = f"Photo_{photo_id}"
            
            # Find the largest available size
            # Look for download links in order of preference: Original, Large, Medium
            download_url = None
            image_url = None
            
            # Method 1: Look for download buttons/links
            download_links = soup.find_all('a', href=True)
            for link in download_links:
                href = link.get('href')
                link_text = link.get_text(strip=True).lower()
                
                # Check for download links
                if 'download' in link_text or 'original' in link_text:
                    if href.startswith('//'):
                        download_url = 'https:' + href
                    elif href.startswith('http'):
                        download_url = href
                    if download_url:
                        break
            
            # Method 2: Find the displayed image on the page
            if not download_url:
                # Look for the main image
                img_elem = soup.find('div', id='allsizes-photo')
                if img_elem:
                    img_tag = img_elem.find('img')
                    if img_tag and img_tag.get('src'):
                        image_url = img_tag['src']
                        if image_url.startswith('//'):
                            image_url = 'https:' + image_url
            
            # Method 3: Extract from size links
            if not download_url and not image_url:
                # Find links to different sizes
                size_links = soup.find_all('a', href=re.compile(r'/sizes/'))
                for link in size_links:
                    if 'Original' in link.get_text():
                        # Navigate to original size page
                        orig_url = 'https://www.flickr.com' + link['href']
                        orig_response = self.session.get(orig_url, timeout=30)
                        orig_soup = BeautifulSoup(orig_response.text, 'html.parser')
                        
                        img_div = orig_soup.find('div', id='allsizes-photo')
                        if img_div:
                            img_tag = img_div.find('img')
                            if img_tag and img_tag.get('src'):
                                image_url = img_tag['src']
                                if image_url.startswith('//'):
                                    image_url = 'https:' + image_url
                                break
            
            # Use whichever URL we found
            final_url = download_url or image_url
            
            if not final_url:
                print(f"  ✗ Could not find download URL")
                return False
            
            # Download the image
            filename = f"flickr_{photo_id}_{username.replace('/', '_')}.jpg"
            filepath = os.path.join(self.photos_dir, filename)
            
            # Skip if already exists
            if os.path.exists(filepath):
                print(f"  Already downloaded: {filename}")
                return True
            
            print(f"  Downloading from: {final_url}")
            img_response = self.session.get(final_url, timeout=60)
            img_response.raise_for_status()
            
            # Save the image
            with open(filepath, 'wb') as f:
                f.write(img_response.content)
            
            # Save attribution data
            self.attribution_data.append({
                'filename': filename,
                'photo_id': photo_id,
                'title': title,
                'photographer': username,
                'photo_url': photo_info['url'],
                'sizes_url': sizes_url,
                'license': 'CC (See Flickr for specific license)',
                'attribution': f"Photo by {username} on Flickr",
                'attribution_html': f'Photo by <a href="{photo_info["url"]}">{username}</a> on Flickr',
                'downloaded_at': datetime.now().isoformat()
            })
            
            print(f"  ✓ Downloaded successfully: {filename}")
            return True
            
        except Exception as e:
            print(f"  ✗ Error: {e}")
            return False
    
    def scrape(self):
        """Main scraping function"""
        print(f"Starting Flickr HTML-based scraper...")
        print(f"HTML file: {self.html_file}")
        print(f"Output directory: {self.output_dir}")
        print(f"Maximum photos: {self.max_photos}")
        print("-" * 50)
        
        # Extract photo information from HTML
        photos = self.extract_photos_from_html()
        
        if not photos:
            print("No photos found in HTML file")
            return
        
        photos_downloaded = 0
        
        for photo_info in photos:
            if photos_downloaded >= self.max_photos:
                break
            
            # Download the photo
            if self.download_photo_from_sizes(photo_info):
                photos_downloaded += 1
                print(f"Progress: {photos_downloaded}/{min(len(photos), self.max_photos)}")
            
            # Be respectful with rate limiting
            time.sleep(2)
        
        # Save attribution data
        with open(self.attribution_file, 'w') as f:
            json.dump(self.attribution_data, f, indent=2)
        
        # Print summary
        print("\n" + "=" * 50)
        print("SCRAPING COMPLETE")
        print("=" * 50)
        print(f"Total photos downloaded: {photos_downloaded}")
        print(f"Attribution data saved to: {self.attribution_file}")
        
        if self.attribution_data:
            print("\nSample attribution:")
            sample = self.attribution_data[0]
            print(f'  {sample["attribution"]}')
            print(f'  Title: {sample["title"]}')
            print(f'  URL: {sample["photo_url"]}')

def main():
    parser = argparse.ArgumentParser(description='Download Flickr photos from saved HTML')
    parser.add_argument('html_file', nargs='?',
                       default='/Users/eranshir/Documents/Projects/scenic/Scenic/Scenic/documents/spots/Search_ scenic _ Flickr-page.html',
                       help='Path to saved Flickr search HTML file')
    parser.add_argument('-o', '--output', default='flickr_scenic_photos',
                       help='Output directory (default: flickr_scenic_photos)')
    parser.add_argument('-n', '--number', type=int, default=20,
                       help='Maximum number of photos to download (default: 20)')
    
    args = parser.parse_args()
    
    # Check if HTML file exists
    if not os.path.exists(args.html_file):
        print(f"Error: HTML file not found: {args.html_file}")
        return
    
    scraper = FlickrHTMLScraper(
        html_file=args.html_file,
        output_dir=args.output,
        max_photos=args.number
    )
    scraper.scrape()

if __name__ == "__main__":
    main()