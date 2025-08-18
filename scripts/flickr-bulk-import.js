#!/usr/bin/env node

/**
 * Flickr Bulk Import Script for Scenic App
 * 
 * This script imports photos from the flickr_collection folder into Supabase,
 * creating placeholder photographer accounts and properly attributing photos.
 * 
 * Usage: node flickr-bulk-import.js [--dry-run] [--batch-size=10] [--start-index=0]
 */

const { createClient } = require('@supabase/supabase-js');
const { v2: cloudinary } = require('cloudinary');
const fs = require('fs').promises;
const path = require('path');
const crypto = require('crypto');

// Load environment variables from .env file
require('dotenv').config();

// Configuration
const CONFIG = {
    SUPABASE_URL: process.env.SUPABASE_URL || 'https://jhfnoritkmdomkcrwtqy.supabase.co',
    SUPABASE_SERVICE_KEY: process.env.SUPABASE_SERVICE_KEY, // Required: Service role key
    CLOUDINARY_CLOUD_NAME: process.env.CLOUDINARY_CLOUD_NAME || 'dwq5rsria',
    CLOUDINARY_API_KEY: process.env.CLOUDINARY_API_KEY || '442752772473387',
    CLOUDINARY_API_SECRET: process.env.CLOUDINARY_API_SECRET, // Required
    BATCH_SIZE: 10,
    RATE_LIMIT_MS: 2000, // 2 seconds between batches
    PROXIMITY_THRESHOLD_METERS: 100, // Group photos within 100m into same spot
    METADATA_FILE: './flickr_collection/metadata.json',
    PHOTOS_DIR: './flickr_collection/photos/',
    DRY_RUN: false
};

class FlickrImporter {
    constructor(options = {}) {
        this.config = { ...CONFIG, ...options };
        this.stats = {
            totalPhotos: 0,
            processedPhotos: 0,
            skippedPhotos: 0,
            createdSpots: 0,
            createdPhotographers: 0,
            errors: []
        };
        
        this.initializeClients();
        this.photographerCache = new Map(); // Cache to avoid duplicate photographers
        this.spotCache = new Map(); // Cache for proximity-based spot grouping
    }
    
    initializeClients() {
        // Initialize Supabase client
        if (!this.config.SUPABASE_SERVICE_KEY) {
            throw new Error('SUPABASE_SERVICE_KEY environment variable is required');
        }
        
        this.supabase = createClient(this.config.SUPABASE_URL, this.config.SUPABASE_SERVICE_KEY, {
            auth: { persistSession: false }
        });
        
        // Initialize Cloudinary
        if (!this.config.CLOUDINARY_API_SECRET) {
            throw new Error('CLOUDINARY_API_SECRET environment variable is required');
        }
        
        cloudinary.config({
            cloud_name: this.config.CLOUDINARY_CLOUD_NAME,
            api_key: this.config.CLOUDINARY_API_KEY,
            api_secret: this.config.CLOUDINARY_API_SECRET,
        });
        
        console.log('✅ Initialized Supabase and Cloudinary clients');
    }
    
    async loadMetadata() {
        try {
            const metadataPath = path.resolve(this.config.METADATA_FILE);
            const data = await fs.readFile(metadataPath, 'utf8');
            const metadata = JSON.parse(data);
            
            // Filter for photos with GPS coordinates
            const gpsPhotos = metadata.filter(item => 
                item.location && 
                item.location.latitude && 
                item.location.longitude
            );
            
            console.log(`📋 Loaded ${metadata.length} total photos, ${gpsPhotos.length} with GPS coordinates`);
            return gpsPhotos;
        } catch (error) {
            throw new Error(`Failed to load metadata: ${error.message}`);
        }
    }
    
    async ensurePhotographer(photoData) {
        const flickrUserId = photoData.username;
        const flickrUsername = photoData.photographer_name || photoData.username;
        
        // For now, use a system user approach - find or create a single Flickr system user
        const systemUserId = await this.getOrCreateFlickrSystemUser();
        
        // Return the system user but with Flickr attribution info
        const photographer = {
            id: systemUserId,
            username: 'flickr_system',
            display_name: 'Flickr Community',
            flickr_user_id: flickrUserId,
            flickr_username: flickrUsername
        };
        
        this.photographerCache.set(flickrUserId, photographer);
        return photographer;
    }
    
    async getOrCreateFlickrSystemUser() {
        // Check cache first
        if (this.systemUserId) {
            return this.systemUserId;
        }
        
        try {
            // Look for existing flickr system user
            const { data: existingUser } = await this.supabase
                .from('profiles')
                .select('id')
                .eq('username', 'flickr_system')
                .single();
                
            if (existingUser) {
                console.log('📋 Using existing Flickr system user');
                this.systemUserId = existingUser.id;
                return this.systemUserId;
            }
            
            if (this.config.DRY_RUN) {
                console.log('[DRY RUN] Would create Flickr system user');
                this.systemUserId = crypto.randomUUID();
                return this.systemUserId;
            }
            
            // Create system user account (requires manual setup - will fail gracefully)
            throw new Error('Flickr system user not found. Please create one manually.');
            
        } catch (error) {
            // Use configured system user ID
            const configuredSystemUserId = process.env.FLICKR_SYSTEM_USER_ID;
            if (configuredSystemUserId) {
                console.log('📋 Using configured Flickr system user');
                this.systemUserId = configuredSystemUserId;
                return this.systemUserId;
            }
            
            throw new Error('No Flickr system user configured. Please set FLICKR_SYSTEM_USER_ID in .env');
        }
    }
    
    generateFlickrUsername(flickrUsername) {
        // Clean the flickr username and add prefix
        const baseUsername = 'flickr_' + flickrUsername.replace(/[^a-z0-9_]/gi, '').toLowerCase();
        return baseUsername.substring(0, 50); // Limit length
    }
    
    mapFlickrLicenseToDbLicense(flickrLicense) {
        // Map Flickr license strings to database constraint values
        // Allowed values: 'All Rights Reserved', 'CC-BY', 'CC-BY-SA', 'CC-BY-NC', 'CC-BY-NC-SA', 'CC0', 'CC (See Flickr)'
        if (!flickrLicense) return 'CC (See Flickr)';
        
        const license = flickrLicense.toLowerCase();
        
        if (license.includes('cc-by-nc-sa')) return 'CC-BY-NC-SA';
        if (license.includes('cc-by-nc')) return 'CC-BY-NC';
        if (license.includes('cc-by-sa')) return 'CC-BY-SA';
        if (license.includes('cc-by')) return 'CC-BY';
        if (license.includes('cc0') || license.includes('public domain')) return 'CC0';
        if (license.includes('all rights reserved')) return 'All Rights Reserved';
        
        // Default for Flickr imports
        return 'CC (See Flickr)';
    }
    
    async uploadToCloudinary(photoData) {
        const photoPath = path.resolve(this.config.PHOTOS_DIR, photoData.filename);
        
        if (this.config.DRY_RUN) {
            console.log(`[DRY RUN] Would upload: ${photoData.filename}`);
            return {
                public_id: `flickr_${photoData.photo_id}`,
                secure_url: `https://res.cloudinary.com/mock/image/upload/flickr_${photoData.photo_id}.jpg`,
                url: `https://res.cloudinary.com/mock/image/upload/flickr_${photoData.photo_id}.jpg`,
                width: 800,
                height: 600
            };
        }
        
        try {
            // Check if file exists
            await fs.access(photoPath);
            
            const uploadOptions = {
                public_id: `scenic/flickr_import/${photoData.photo_id}`,
                folder: 'scenic',
                tags: ['flickr_import', 'scenic'],
                context: {
                    source: 'flickr',
                    original_id: photoData.photo_id,
                    photographer: photoData.photographer_name || photoData.username,
                    title: photoData.title
                },
                transformation: [
                    { quality: 'auto', fetch_format: 'auto' }
                ]
            };
            
            const result = await cloudinary.uploader.upload(photoPath, uploadOptions);
            console.log(`☁️  Uploaded to Cloudinary: ${photoData.filename}`);
            return result;
            
        } catch (error) {
            if (error.code === 'ENOENT') {
                throw new Error(`Photo file not found: ${photoPath}`);
            }
            throw new Error(`Cloudinary upload failed: ${error.message}`);
        }
    }
    
    findNearbySpot(latitude, longitude) {
        const threshold = this.config.PROXIMITY_THRESHOLD_METERS;
        
        for (const [spotKey, spot] of this.spotCache) {
            const distance = this.calculateDistance(
                latitude, longitude,
                spot.latitude, spot.longitude
            );
            
            if (distance <= threshold) {
                return spot;
            }
        }
        
        return null;
    }
    
    calculateDistance(lat1, lon1, lat2, lon2) {
        const R = 6371000; // Earth's radius in meters
        const φ1 = lat1 * Math.PI / 180;
        const φ2 = lat2 * Math.PI / 180;
        const Δφ = (lat2 - lat1) * Math.PI / 180;
        const Δλ = (lon2 - lon1) * Math.PI / 180;
        
        const a = Math.sin(Δφ/2) * Math.sin(Δφ/2) +
                  Math.cos(φ1) * Math.cos(φ2) *
                  Math.sin(Δλ/2) * Math.sin(Δλ/2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
        
        return R * c;
    }
    
    async createOrFindSpot(photoData, photographerId) {
        const { latitude, longitude } = photoData.location;
        
        // Check for nearby existing spot
        const nearbySpot = this.findNearbySpot(latitude, longitude);
        if (nearbySpot) {
            console.log(`📍 Using existing nearby spot: ${nearbySpot.title}`);
            return nearbySpot;
        }
        
        // Create new spot
        const spotData = {
            title: this.generateSpotTitle(photoData),
            description: photoData.description || `Scenic location captured by ${photoData.photographer_name || photoData.username}`,
            latitude: latitude,
            longitude: longitude,
            location: `POINT(${longitude} ${latitude})`, // PostGIS format
            difficulty: this.inferDifficulty(photoData),
            subject_tags: photoData.tags || [],
            created_by: photographerId,
            privacy: 'public',
            license: 'CC-BY-NC',
            status: 'active'
        };
        
        if (this.config.DRY_RUN) {
            console.log(`[DRY RUN] Would create spot: ${spotData.title}`);
            const mockSpot = {
                id: crypto.randomUUID(),
                ...spotData
            };
            this.spotCache.set(`${latitude},${longitude}`, mockSpot);
            return mockSpot;
        }
        
        try {
            const { data: newSpot, error } = await this.supabase
                .from('spots')
                .insert(spotData)
                .select()
                .single();
            
            if (error) {
                throw new Error(`Failed to create spot: ${error.message}`);
            }
            
            console.log(`🗺️  Created spot: ${newSpot.title}`);
            this.stats.createdSpots++;
            this.spotCache.set(`${latitude},${longitude}`, newSpot);
            return newSpot;
            
        } catch (error) {
            console.error(`❌ Error creating spot:`, error.message);
            throw error;
        }
    }
    
    generateSpotTitle(photoData) {
        // Clean up the photo title for use as spot title
        const title = photoData.title && photoData.title.trim();
        
        // Check if title is valid (not empty, not "Untitled", not a UUID)
        if (title && 
            title !== 'Untitled' && 
            !this.isUuidLike(title)) {
            return title.substring(0, 100);
        }
        
        // Fallback to photographer and location info
        const photographer = photoData.photographer_name || photoData.username;
        const location = photoData.location;
        
        if (location && (location.locality || location.region)) {
            const locationStr = [location.locality, location.region].filter(Boolean).join(', ');
            return `Photo spot in ${locationStr}`;
        }
        
        return `Scenic spot by ${photographer}`;
    }
    
    // Helper to detect UUID-like strings
    isUuidLike(str) {
        // Match UUID pattern (8-4-4-4-12 hex digits)
        const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
        return uuidPattern.test(str);
    }
    
    // Create sun snapshot for a spot (simplified calculation)
    async createSunSnapshot(spotId, latitude, longitude, captureDate) {
        if (this.config.DRY_RUN) {
            console.log(`[DRY RUN] Would create sun snapshot for spot: ${spotId}`);
            return;
        }
        
        try {
            // Use capture date or current date for sun calculations
            const date = captureDate ? new Date(captureDate) : new Date();
            const dateStr = date.toISOString().split('T')[0]; // YYYY-MM-DD format
            
            // Simple sun calculations (this is a basic approximation)
            // In a real app, you'd use a proper solar calculation library
            const sunData = this.calculateSunTimes(latitude, longitude, date);
            
            // Use only basic fields that likely exist in the schema
            const sunSnapshot = {
                spot_id: spotId,
                date: dateStr,
                sunrise_utc: sunData.sunrise,
                sunset_utc: sunData.sunset
            };
            
            const { error } = await this.supabase
                .from('sun_snapshots')
                .insert(sunSnapshot);
                
            if (error) {
                console.log(`⚠️ Failed to create sun snapshot: ${error.message}`);
            } else {
                console.log(`☀️ Created sun snapshot for ${dateStr}`);
            }
            
        } catch (error) {
            console.log(`⚠️ Error creating sun snapshot: ${error.message}`);
        }
    }
    
    // Basic sun time calculations (simplified)
    calculateSunTimes(lat, lng, date) {
        // This is a very basic approximation
        // In production, use a proper library like suncalc or similar
        const jd = this.getJulianDate(date);
        const n = jd - 2451545.0;
        const L = (280.460 + 0.9856474 * n) % 360;
        const g = Math.PI / 180 * ((357.528 + 0.9856003 * n) % 360);
        const lambda = Math.PI / 180 * (L + 1.915 * Math.sin(g) + 0.020 * Math.sin(2 * g));
        
        const hourAngle = Math.acos(-Math.tan(lat * Math.PI / 180) * Math.tan(Math.asin(0.39795 * Math.cos(lambda))));
        const timeCorrection = 4 * (lng - 15 * Math.floor(lng / 15)) - 4 * lng + 60 * Math.floor(lng / 15);
        
        const sunrise = new Date(date);
        sunrise.setUTCHours(12 - hourAngle * 12 / Math.PI - timeCorrection / 60, 0, 0, 0);
        
        const sunset = new Date(date);
        sunset.setUTCHours(12 + hourAngle * 12 / Math.PI - timeCorrection / 60, 0, 0, 0);
        
        const solarNoon = new Date(date);
        solarNoon.setUTCHours(12 - timeCorrection / 60, 0, 0, 0);
        
        // Golden hour approximations (1 hour before sunset, 1 hour after sunrise)
        const goldenHourStart = new Date(sunset.getTime() - 60 * 60 * 1000);
        const goldenHourEnd = new Date(sunrise.getTime() + 60 * 60 * 1000);
        
        // Blue hour approximations (30 min before sunrise, 30 min after sunset)
        const blueHourStart = new Date(sunrise.getTime() - 30 * 60 * 1000);
        const blueHourEnd = new Date(sunset.getTime() + 30 * 60 * 1000);
        
        return {
            sunrise: sunrise.toISOString(),
            sunset: sunset.toISOString(),
            solarNoon: solarNoon.toISOString(),
            goldenHourStart: goldenHourStart.toISOString(),
            goldenHourEnd: goldenHourEnd.toISOString(),
            blueHourStart: blueHourStart.toISOString(),
            blueHourEnd: blueHourEnd.toISOString(),
            elevationAtCapture: 45, // Placeholder
            azimuthAtCapture: 180   // Placeholder
        };
    }
    
    getJulianDate(date) {
        return date.getTime() / 86400000 + 2440587.5;
    }
    
    inferDifficulty(photoData) {
        // Simple heuristic for difficulty based on tags and title
        const text = `${photoData.title} ${photoData.description} ${(photoData.tags || []).join(' ')}`.toLowerCase();
        
        if (text.includes('extreme') || text.includes('dangerous') || text.includes('technical')) return 5;
        if (text.includes('challenging') || text.includes('difficult') || text.includes('advanced')) return 4;
        if (text.includes('moderate') || text.includes('intermediate')) return 3;
        if (text.includes('easy') || text.includes('accessible') || text.includes('beginner')) return 2;
        
        return 2; // Default to easy
    }
    
    async createMediaRecord(photoData, spotId, photographerId, cloudinaryResult) {
        const mediaData = {
            spot_id: spotId,
            user_id: photographerId,
            cloudinary_public_id: cloudinaryResult.public_id,
            cloudinary_url: cloudinaryResult.url,
            cloudinary_secure_url: cloudinaryResult.secure_url,
            type: 'photo',
            width: cloudinaryResult.width,
            height: cloudinaryResult.height,
            
            // Capture time from Flickr metadata
            capture_time_utc: photoData.date_taken ? new Date(photoData.date_taken).toISOString() : null,
            
            // Attribution fields (matching database schema)
            attribution_text: photoData.attribution || `Photo by ${photoData.photographer_name || photoData.username} on Flickr`,
            original_source: 'flickr',
            original_photo_id: photoData.photo_id,
            license_type: this.mapFlickrLicenseToDbLicense(photoData.license),
            
            // Original GPS coordinates from Flickr photo
            gps_latitude: photoData.location?.latitude,
            gps_longitude: photoData.location?.longitude
        };
        
        if (this.config.DRY_RUN) {
            console.log(`[DRY RUN] Would create media record for: ${photoData.filename}`);
            return { id: crypto.randomUUID() };
        }
        
        try {
            const { data: newMedia, error } = await this.supabase
                .from('media')
                .insert(mediaData)
                .select()
                .single();
            
            if (error) {
                throw new Error(`Failed to create media record: ${error.message}`);
            }
            
            console.log(`📸 Created media record: ${photoData.filename}`);
            return newMedia;
            
        } catch (error) {
            console.error(`❌ Error creating media record:`, error.message);
            throw error;
        }
    }
    
    async processBatch(batch) {
        console.log(`\n🔄 Processing batch of ${batch.length} photos...`);
        
        for (const photoData of batch) {
            try {
                console.log(`\n📷 Processing: ${photoData.title || photoData.filename}`);
                
                // Step 1: Ensure photographer exists
                const photographer = await this.ensurePhotographer(photoData);
                
                // Step 2: Upload to Cloudinary
                const cloudinaryResult = await this.uploadToCloudinary(photoData);
                
                // Step 3: Create or find spot
                const spot = await this.createOrFindSpot(photoData, photographer.id);
                
                // Step 4: Create media record
                await this.createMediaRecord(photoData, spot.id, photographer.id, cloudinaryResult);
                
                // Step 5: Create sun snapshot data
                if (photoData.location) {
                    await this.createSunSnapshot(
                        spot.id, 
                        photoData.location.latitude, 
                        photoData.location.longitude, 
                        photoData.date_taken
                    );
                }
                
                this.stats.processedPhotos++;
                console.log(`✅ Successfully processed: ${photoData.title || photoData.filename}`);
                
            } catch (error) {
                this.stats.errors.push({
                    photo: photoData.filename,
                    error: error.message
                });
                this.stats.skippedPhotos++;
                console.error(`❌ Failed to process ${photoData.filename}:`, error.message);
            }
        }
    }
    
    async sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
    
    async importAll(startIndex = 0, maxPhotos = null) {
        try {
            console.log('🚀 Starting Flickr bulk import...\n');
            
            if (this.config.DRY_RUN) {
                console.log('🧪 DRY RUN MODE - No actual changes will be made\n');
            }
            
            const metadata = await this.loadMetadata();
            this.stats.totalPhotos = metadata.length;
            
            // Start from specified index
            let photosToProcess = metadata.slice(startIndex);
            
            // Limit to max photos if specified
            if (maxPhotos && maxPhotos > 0) {
                photosToProcess = photosToProcess.slice(0, maxPhotos);
                console.log(`📊 Processing ${photosToProcess.length} photos (starting from index ${startIndex}, limited to ${maxPhotos} max)\n`);
            } else {
                console.log(`📊 Processing ${photosToProcess.length} photos (starting from index ${startIndex}, no limit)\n`);
            }
            
            // Process in batches
            for (let i = 0; i < photosToProcess.length; i += this.config.BATCH_SIZE) {
                const batch = photosToProcess.slice(i, i + this.config.BATCH_SIZE);
                const batchNumber = Math.floor(i / this.config.BATCH_SIZE) + 1;
                const totalBatches = Math.ceil(photosToProcess.length / this.config.BATCH_SIZE);
                
                console.log(`\n📦 Batch ${batchNumber}/${totalBatches}`);
                
                await this.processBatch(batch);
                
                // Rate limiting between batches
                if (i + this.config.BATCH_SIZE < photosToProcess.length) {
                    console.log(`⏳ Waiting ${this.config.RATE_LIMIT_MS}ms before next batch...`);
                    await this.sleep(this.config.RATE_LIMIT_MS);
                }
            }
            
            this.printSummary();
            
        } catch (error) {
            console.error('\n💥 Import failed:', error.message);
            this.printSummary();
            process.exit(1);
        }
    }
    
    printSummary() {
        console.log('\n' + '='.repeat(50));
        console.log('📊 IMPORT SUMMARY');
        console.log('='.repeat(50));
        console.log(`Total photos: ${this.stats.totalPhotos}`);
        console.log(`Processed: ${this.stats.processedPhotos} ✅`);
        console.log(`Skipped: ${this.stats.skippedPhotos} ⏭️`);
        console.log(`Created spots: ${this.stats.createdSpots} 🗺️`);
        console.log(`Created photographers: ${this.stats.createdPhotographers} 👤`);
        console.log(`Errors: ${this.stats.errors.length} ❌`);
        
        if (this.stats.errors.length > 0) {
            console.log('\n❌ ERRORS:');
            this.stats.errors.forEach(err => {
                console.log(`  - ${err.photo}: ${err.error}`);
            });
        }
        
        console.log('\n✨ Import completed!');
    }
}

// CLI Interface
async function main() {
    const args = process.argv.slice(2);
    const options = {};
    
    // Parse command line arguments
    args.forEach(arg => {
        if (arg === '--dry-run') {
            options.DRY_RUN = true;
        } else if (arg.startsWith('--batch-size=')) {
            options.BATCH_SIZE = parseInt(arg.split('=')[1]) || CONFIG.BATCH_SIZE;
        } else if (arg.startsWith('--start-index=')) {
            options.startIndex = parseInt(arg.split('=')[1]) || 0;
        } else if (arg.startsWith('--max-photos=')) {
            options.maxPhotos = parseInt(arg.split('=')[1]) || null;
        } else if (arg === '--help') {
            console.log(`
Flickr Bulk Import Script for Scenic App

Usage: node flickr-bulk-import.js [options]

Options:
  --dry-run              Run without making actual changes
  --batch-size=N         Number of photos to process per batch (default: 10)
  --max-photos=N         Maximum total number of photos to import (default: no limit)
  --start-index=N        Start processing from index N (default: 0)
  --help                 Show this help message

Environment Variables:
  SUPABASE_SERVICE_KEY   Required: Supabase service role key
  CLOUDINARY_API_SECRET  Required: Cloudinary API secret

Examples:
  node flickr-bulk-import.js --dry-run
  node flickr-bulk-import.js --max-photos=5
  node flickr-bulk-import.js --batch-size=5 --max-photos=20 --start-index=100
            `);
            process.exit(0);
        }
    });
    
    const startIndex = options.startIndex || 0;
    const maxPhotos = options.maxPhotos || null;
    delete options.startIndex;
    delete options.maxPhotos;
    
    const importer = new FlickrImporter(options);
    await importer.importAll(startIndex, maxPhotos);
}

// Handle graceful shutdown
process.on('SIGINT', () => {
    console.log('\n⏹️  Import interrupted by user');
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('\n⏹️  Import terminated');
    process.exit(0);
});

// Run the script
if (require.main === module) {
    main().catch(error => {
        console.error('\n💥 Unexpected error:', error);
        process.exit(1);
    });
}

module.exports = { FlickrImporter };