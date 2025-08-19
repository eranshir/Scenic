#!/usr/bin/env node

/**
 * Cleanup Script for Flickr Import Data
 * 
 * This script removes all Flickr-imported data from both Supabase and Cloudinary
 * to allow for a fresh bulk import test.
 */

const { createClient } = require('@supabase/supabase-js');
const { v2: cloudinary } = require('cloudinary');
require('dotenv').config();

class FlickrDataCleaner {
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
            deletedCloudinaryImages: 0,
            errors: []
        };
    }
    
    async cleanupSupabaseData() {
        console.log('🧹 Cleaning up Supabase data...');
        
        try {
            // Get all Flickr spots to identify what to clean
            const { data: spots, error: spotsError } = await this.supabase
                .from('spots')
                .select('id, title')
                .eq('created_by', process.env.FLICKR_SYSTEM_USER_ID);
            
            if (spotsError) {
                throw new Error(`Failed to fetch Flickr spots: ${spotsError.message}`);
            }
            
            console.log(`📍 Found ${spots.length} Flickr spots to delete`);
            
            if (spots.length === 0) {
                console.log('ℹ️ No Flickr spots found to delete');
                return;
            }
            
            // Delete media records first (due to foreign key constraints)
            console.log('🖼️ Deleting Flickr media records...');
            const { error: mediaError } = await this.supabase
                .from('media')
                .delete()
                .eq('original_source', 'flickr');
            
            if (mediaError) {
                throw new Error(`Failed to delete media: ${mediaError.message}`);
            }
            
            // Get count of deleted media
            const { count: mediaCount } = await this.supabase
                .from('media')
                .select('*', { count: 'exact', head: true })
                .eq('original_source', 'flickr');
            
            this.stats.deletedMedia = mediaCount || 0;
            console.log(`✅ Deleted media records`);
            
            // Delete spots
            console.log('📍 Deleting Flickr spots...');
            const { error: spotsDeleteError } = await this.supabase
                .from('spots')
                .delete()
                .eq('created_by', process.env.FLICKR_SYSTEM_USER_ID);
            
            if (spotsDeleteError) {
                throw new Error(`Failed to delete spots: ${spotsDeleteError.message}`);
            }
            
            this.stats.deletedSpots = spots.length;
            console.log(`✅ Deleted ${spots.length} Flickr spots`);
            
        } catch (error) {
            console.error('❌ Error cleaning Supabase data:', error.message);
            this.stats.errors.push(`Supabase cleanup: ${error.message}`);
        }
    }
    
    async cleanupCloudinaryData() {
        console.log('☁️ Cleaning up Cloudinary data...');
        
        try {
            // List all resources in the scenic/flickr_import folder
            console.log('🔍 Finding Flickr import images in Cloudinary...');
            
            const listResult = await cloudinary.api.resources({
                type: 'upload',
                prefix: 'scenic/flickr_import/',
                max_results: 500, // Adjust if you have more images
            });
            
            console.log(`🖼️ Found ${listResult.resources.length} Flickr images to delete`);
            
            if (listResult.resources.length === 0) {
                console.log('ℹ️ No Flickr images found in Cloudinary');
                return;
            }
            
            // Delete images in batches
            const publicIds = listResult.resources.map(resource => resource.public_id);
            
            console.log('🗑️ Deleting Cloudinary images...');
            const deleteResult = await cloudinary.api.delete_resources(publicIds);
            
            // Count successful deletions
            const deletedCount = Object.values(deleteResult.deleted).filter(status => status === 'deleted').length;
            this.stats.deletedCloudinaryImages = deletedCount;
            
            console.log(`✅ Deleted ${deletedCount} images from Cloudinary`);
            
            // Also try to delete the folder if it's empty
            try {
                await cloudinary.api.delete_folder('scenic/flickr_import');
                console.log('✅ Deleted empty flickr_import folder');
            } catch (folderError) {
                // Folder might not be empty or might not exist - that's okay
                console.log('ℹ️ Could not delete flickr_import folder (may not be empty)');
            }
            
        } catch (error) {
            console.error('❌ Error cleaning Cloudinary data:', error.message);
            this.stats.errors.push(`Cloudinary cleanup: ${error.message}`);
        }
    }
    
    async run() {
        console.log('🚀 Starting Flickr data cleanup...\n');
        
        if (!process.env.FLICKR_SYSTEM_USER_ID) {
            console.error('❌ FLICKR_SYSTEM_USER_ID not found in environment variables');
            process.exit(1);
        }
        
        // Clean up Supabase data first
        await this.cleanupSupabaseData();
        
        // Then clean up Cloudinary data
        await this.cleanupCloudinaryData();
        
        this.printSummary();
    }
    
    printSummary() {
        console.log('\n' + '='.repeat(50));
        console.log('🧹 CLEANUP SUMMARY');
        console.log('='.repeat(50));
        console.log(`Deleted Supabase spots: ${this.stats.deletedSpots} 📍`);
        console.log(`Deleted Supabase media: ${this.stats.deletedMedia} 🖼️`);
        console.log(`Deleted Cloudinary images: ${this.stats.deletedCloudinaryImages} ☁️`);
        console.log(`Errors: ${this.stats.errors.length} ❌`);
        
        if (this.stats.errors.length > 0) {
            console.log('\n❌ ERRORS:');
            this.stats.errors.forEach(err => {
                console.log(`  - ${err}`);
            });
        }
        
        if (this.stats.errors.length === 0) {
            console.log('\n✨ Cleanup completed successfully! Ready for fresh bulk import.');
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
Flickr Data Cleanup Script

Usage: node cleanup-flickr-data.js [--confirm]

This script removes all Flickr-imported data from:
- Supabase spots table (where created_by = FLICKR_SYSTEM_USER_ID)
- Supabase media table (where original_source = 'flickr')  
- Cloudinary images (in scenic/flickr_import/ folder)

Options:
  --confirm    Proceed with cleanup (required for safety)
  --help       Show this help message

Environment Variables Required:
  SUPABASE_URL, SUPABASE_SERVICE_KEY, FLICKR_SYSTEM_USER_ID
  CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET
        `);
        process.exit(0);
    }
    
    if (!args.includes('--confirm')) {
        console.log('⚠️  WARNING: This will permanently delete all Flickr import data!');
        console.log('   - All Flickr spots from Supabase');
        console.log('   - All Flickr media records from Supabase');
        console.log('   - All Flickr images from Cloudinary');
        console.log('\nAdd --confirm flag to proceed with cleanup.');
        console.log('Example: node cleanup-flickr-data.js --confirm');
        process.exit(0);
    }
    
    const cleaner = new FlickrDataCleaner();
    await cleaner.run();
}

// Handle graceful shutdown
process.on('SIGINT', () => {
    console.log('\n⏹️  Cleanup cancelled by user');
    process.exit(0);
});

// Run the script
if (require.main === module) {
    main().catch(error => {
        console.error('\n💥 Unexpected error:', error);
        process.exit(1);
    });
}

module.exports = { FlickrDataCleaner };