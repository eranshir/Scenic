#!/usr/bin/env node

/**
 * Complete Database Cleanup Script
 * 
 * This script removes ALL spots, media, and related data from both Supabase and Cloudinary
 * to allow for a completely fresh start.
 * 
 * WARNING: This will delete ALL data, not just Flickr imports!
 */

const { createClient } = require('@supabase/supabase-js');
const { v2: cloudinary } = require('cloudinary');
require('dotenv').config();

class CompleteDatabaseCleaner {
    constructor() {
        // Initialize Supabase client
        this.supabase = createClient(
            process.env.SUPABASE_URL,
            process.env.SUPABASE_SERVICE_KEY,
            { auth: { persistSession: false } }
        );
        
        // Initialize Cloudinary
        cloudinary.config({
            cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
            api_key: process.env.CLOUDINARY_API_KEY,
            api_secret: process.env.CLOUDINARY_API_SECRET,
        });
        
        this.stats = {
            deletedSpots: 0,
            deletedMedia: 0,
            deletedSunSnapshots: 0,
            deletedWeatherSnapshots: 0,
            deletedCloudinaryImages: 0,
            errors: []
        };
    }
    
    async cleanupSupabaseData() {
        console.log('🧹 Cleaning up ALL Supabase data...');
        
        try {
            // First, get counts of what we're about to delete
            const { count: spotCount } = await this.supabase
                .from('spots')
                .select('*', { count: 'exact', head: true });
                
            const { count: mediaCount } = await this.supabase
                .from('media')
                .select('*', { count: 'exact', head: true });
                
            const { count: sunCount } = await this.supabase
                .from('sun_snapshots')
                .select('*', { count: 'exact', head: true });
                
            console.log(`📊 Found ${spotCount || 0} spots, ${mediaCount || 0} media, ${sunCount || 0} sun snapshots`);
            
            // Delete in order due to foreign key constraints
            
            // 1. Delete sun snapshots first
            console.log('🌅 Deleting sun snapshots...');
            const { error: sunError } = await this.supabase
                .from('sun_snapshots')
                .delete()
                .neq('id', '00000000-0000-0000-0000-000000000000'); // Delete all (dummy condition)
            
            if (sunError) {
                console.log(`⚠️ Warning deleting sun snapshots: ${sunError.message}`);
            } else {
                this.stats.deletedSunSnapshots = sunCount || 0;
                console.log(`✅ Deleted ${sunCount || 0} sun snapshots`);
            }
            
            // 2. Delete weather snapshots if they exist
            console.log('🌤️ Deleting weather snapshots...');
            const { error: weatherError } = await this.supabase
                .from('weather_snapshots')
                .delete()
                .neq('id', '00000000-0000-0000-0000-000000000000'); // Delete all (dummy condition)
            
            if (weatherError) {
                console.log(`ℹ️ No weather snapshots table or no data: ${weatherError.message}`);
            } else {
                console.log(`✅ Deleted weather snapshots`);
            }
            
            // 3. Delete media records
            console.log('🖼️ Deleting ALL media records...');
            const { error: mediaError } = await this.supabase
                .from('media')
                .delete()
                .neq('id', '00000000-0000-0000-0000-000000000000'); // Delete all (dummy condition)
            
            if (mediaError) {
                throw new Error(`Failed to delete media: ${mediaError.message}`);
            }
            
            this.stats.deletedMedia = mediaCount || 0;
            console.log(`✅ Deleted ${mediaCount || 0} media records`);
            
            // 4. Delete spots
            console.log('📍 Deleting ALL spots...');
            const { error: spotsError } = await this.supabase
                .from('spots')
                .delete()
                .neq('id', '00000000-0000-0000-0000-000000000000'); // Delete all (dummy condition)
            
            if (spotsError) {
                throw new Error(`Failed to delete spots: ${spotsError.message}`);
            }
            
            this.stats.deletedSpots = spotCount || 0;
            console.log(`✅ Deleted ${spotCount || 0} spots`);
            
        } catch (error) {
            console.error('❌ Error cleaning Supabase data:', error.message);
            this.stats.errors.push(`Supabase cleanup: ${error.message}`);
        }
    }
    
    async cleanupCloudinaryData() {
        console.log('☁️ Cleaning up ALL Cloudinary data...');
        
        try {
            // Search for all scenic-related images
            console.log('🔍 Finding all Scenic images in Cloudinary...');
            
            const searchPrefixes = [
                'scenic/',
                'scenic',
                '' // Search all if above don't work
            ];
            
            let totalDeleted = 0;
            
            for (const prefix of searchPrefixes) {
                try {
                    console.log(`📂 Searching prefix: "${prefix}"`);
                    
                    const listResult = await cloudinary.api.resources({
                        type: 'upload',
                        prefix: prefix,
                        max_results: 500, // Cloudinary API limit
                    });
                    
                    if (listResult.resources.length > 0) {
                        console.log(`🖼️ Found ${listResult.resources.length} images to delete`);
                        
                        // Delete images in batches
                        const publicIds = listResult.resources.map(resource => resource.public_id);
                        
                        console.log('🗑️ Deleting Cloudinary images...');
                        const deleteResult = await cloudinary.api.delete_resources(publicIds);
                        
                        // Count successful deletions
                        const deletedCount = Object.values(deleteResult.deleted).filter(status => status === 'deleted').length;
                        totalDeleted += deletedCount;
                        
                        console.log(`✅ Deleted ${deletedCount} images from prefix "${prefix}"`);
                        
                        // If we found images with this prefix, don't try the others
                        if (deletedCount > 0) break;
                    } else {
                        console.log(`ℹ️ No images found with prefix "${prefix}"`);
                    }
                    
                } catch (prefixError) {
                    console.log(`⚠️ Error with prefix "${prefix}": ${prefixError.message}`);
                }
            }
            
            this.stats.deletedCloudinaryImages = totalDeleted;
            
            if (totalDeleted === 0) {
                console.log('ℹ️ No Scenic images found in Cloudinary to delete');
            }
            
            // Try to clean up folders
            try {
                await cloudinary.api.delete_folder('scenic');
                console.log('✅ Deleted scenic folder');
            } catch (folderError) {
                console.log('ℹ️ Could not delete scenic folder (may not exist or not be empty)');
            }
            
        } catch (error) {
            console.error('❌ Error cleaning Cloudinary data:', error.message);
            this.stats.errors.push(`Cloudinary cleanup: ${error.message}`);
        }
    }
    
    async run() {
        console.log('🚀 Starting COMPLETE database cleanup...');
        console.log('⚠️  This will delete ALL spots, media, and related data!');
        console.log('');
        
        // Clean up Supabase data first
        await this.cleanupSupabaseData();
        
        // Then clean up Cloudinary data
        await this.cleanupCloudinaryData();
        
        this.printSummary();
    }
    
    printSummary() {
        console.log('\n' + '='.repeat(60));
        console.log('🧹 COMPLETE CLEANUP SUMMARY');
        console.log('='.repeat(60));
        console.log(`Deleted Supabase spots: ${this.stats.deletedSpots} 📍`);
        console.log(`Deleted Supabase media: ${this.stats.deletedMedia} 🖼️`);
        console.log(`Deleted sun snapshots: ${this.stats.deletedSunSnapshots} 🌅`);
        console.log(`Deleted weather snapshots: ${this.stats.deletedWeatherSnapshots} 🌤️`);
        console.log(`Deleted Cloudinary images: ${this.stats.deletedCloudinaryImages} ☁️`);
        console.log(`Errors: ${this.stats.errors.length} ❌`);
        
        if (this.stats.errors.length > 0) {
            console.log('\n❌ ERRORS:');
            this.stats.errors.forEach(err => {
                console.log(`  - ${err}`);
            });
        }
        
        if (this.stats.errors.length === 0) {
            console.log('\n✨ Complete cleanup successful! Database is now completely empty.');
            console.log('🎯 Ready for fresh bulk import and testing.');
        } else {
            console.log('\n⚠️ Cleanup completed with some errors. Check above for details.');
        }
    }
}

// CLI Interface
async function main() {
    const args = process.argv.slice(2);
    
    if (args.includes('--help') || args.includes('-h')) {
        console.log(`
Complete Database Cleanup Script

Usage: node cleanup-all-data.js [--confirm]

⚠️  WARNING: This script will DELETE ALL DATA:
- ALL spots from Supabase (not just Flickr imports)
- ALL media records from Supabase
- ALL sun snapshots from Supabase
- ALL images from Cloudinary scenic folder

Options:
  --confirm    Proceed with complete cleanup (required for safety)
  --help       Show this help message

Environment Variables Required:
  SUPABASE_URL, SUPABASE_SERVICE_KEY
  CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET
        `);
        process.exit(0);
    }
    
    if (!args.includes('--confirm')) {
        console.log('⚠️  DANGER: This will permanently delete ALL DATA from your Scenic database!');
        console.log('   - ALL user-created spots from Supabase');
        console.log('   - ALL Flickr imported spots from Supabase');
        console.log('   - ALL media records from Supabase');
        console.log('   - ALL sun and weather snapshots from Supabase');
        console.log('   - ALL images from Cloudinary');
        console.log('');
        console.log('This action cannot be undone!');
        console.log('');
        console.log('Add --confirm flag to proceed with complete cleanup.');
        console.log('Example: node cleanup-all-data.js --confirm');
        process.exit(0);
    }
    
    const cleaner = new CompleteDatabaseCleaner();
    await cleaner.run();
}

// Handle graceful shutdown
process.on('SIGINT', () => {
    console.log('\n⏹️  Complete cleanup cancelled by user');
    process.exit(0);
});

// Run the script
if (require.main === module) {
    main().catch(error => {
        console.error('\n💥 Unexpected error:', error);
        process.exit(1);
    });
}

module.exports = { CompleteDatabaseCleaner };