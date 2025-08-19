#!/usr/bin/env node

const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(
  process.env.SUPABASE_URL || 'https://jhfnoritkmdomkcrwtqy.supabase.co',
  process.env.SUPABASE_SERVICE_KEY
);

async function cleanupDuplicateSpots(dryRun = true) {
  try {
    console.log(`🔍 ${dryRun ? '[DRY RUN] ' : ''}Finding duplicate spots...`);
    
    // Get all spots with coordinates and creation time
    const { data: spots, error } = await supabase
      .from('spots')
      .select('id, title, latitude, longitude, created_at')
      .order('created_at');
    
    if (error) throw error;
    
    console.log(`Total spots: ${spots.length}`);
    
    // Group by coordinates
    const coordinateGroups = {};
    spots.forEach(spot => {
      const key = `${spot.latitude},${spot.longitude}`;
      if (!coordinateGroups[key]) {
        coordinateGroups[key] = [];
      }
      coordinateGroups[key].push(spot);
    });
    
    // Find duplicates and identify spots to delete
    const toDelete = [];
    let duplicateGroups = 0;
    
    Object.entries(coordinateGroups).forEach(([coords, spotsAtLocation]) => {
      if (spotsAtLocation.length > 1) {
        duplicateGroups++;
        // Keep the oldest spot (first in array), delete the rest
        const [keepSpot, ...deleteSpots] = spotsAtLocation;
        console.log(`\n📍 ${coords}: Keeping "${keepSpot.title}" (${new Date(keepSpot.created_at).toLocaleString()})`);
        
        deleteSpots.forEach(spot => {
          console.log(`   🗑️  Will delete: "${spot.title}" (${new Date(spot.created_at).toLocaleString()})`);
          toDelete.push(spot.id);
        });
      }
    });
    
    console.log(`\n📊 CLEANUP SUMMARY:`);
    console.log(`- Unique coordinates: ${Object.keys(coordinateGroups).length}`);
    console.log(`- Duplicate groups: ${duplicateGroups}`);
    console.log(`- Spots to delete: ${toDelete.length}`);
    console.log(`- Final count: ${spots.length - toDelete.length}`);
    
    if (toDelete.length === 0) {
      console.log('✅ No duplicates to clean up!');
      return;
    }
    
    if (dryRun) {
      console.log(`\n🧪 DRY RUN - No changes made. Run with --execute to perform cleanup.`);
    } else {
      console.log(`\n💥 EXECUTING CLEANUP...`);
      
      // Delete media records first (foreign key constraint)
      console.log('🗑️  Deleting associated media records...');
      const { error: mediaError } = await supabase
        .from('media')
        .delete()
        .in('spot_id', toDelete);
      
      if (mediaError) {
        console.error('❌ Error deleting media:', mediaError.message);
        return;
      }
      
      // Delete sun snapshots  
      console.log('☀️ Deleting associated sun snapshots...');
      const { error: sunError } = await supabase
        .from('sun_snapshots')
        .delete()
        .in('spot_id', toDelete);
        
      if (sunError) {
        console.error('❌ Error deleting sun snapshots:', sunError.message);
        return;
      }
      
      // Delete duplicate spots
      console.log('📍 Deleting duplicate spots...');
      const { error: spotsError } = await supabase
        .from('spots')
        .delete()
        .in('id', toDelete);
      
      if (spotsError) {
        console.error('❌ Error deleting spots:', spotsError.message);
        return;
      }
      
      console.log(`✅ Successfully deleted ${toDelete.length} duplicate spots!`);
      console.log(`📊 Final database state: ${spots.length - toDelete.length} unique spots`);
    }
    
  } catch (error) {
    console.error('❌ Error during cleanup:', error.message);
  }
}

// Parse command line arguments
const args = process.argv.slice(2);
const execute = args.includes('--execute');

cleanupDuplicateSpots(!execute);