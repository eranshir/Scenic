#!/usr/bin/env node

const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(
  process.env.SUPABASE_URL || 'https://jhfnoritkmdomkcrwtqy.supabase.co',
  process.env.SUPABASE_SERVICE_KEY
);

async function checkDuplicateSpots() {
  try {
    console.log('🔍 Checking for duplicate spots by coordinates...');
    
    // Query to find spots with identical coordinates
    const { data: spots, error } = await supabase
      .from('spots')
      .select('id, title, latitude, longitude, created_at')
      .order('latitude')
      .order('longitude');
    
    if (error) throw error;
    
    console.log(`Total spots in database: ${spots.length}`);
    
    // Group by coordinates to find duplicates
    const coordinateGroups = {};
    
    spots.forEach(spot => {
      const key = `${spot.latitude},${spot.longitude}`;
      if (!coordinateGroups[key]) {
        coordinateGroups[key] = [];
      }
      coordinateGroups[key].push(spot);
    });
    
    // Find groups with more than one spot
    const duplicateGroups = Object.entries(coordinateGroups)
      .filter(([key, spots]) => spots.length > 1)
      .sort(([a, spotsA], [b, spotsB]) => spotsB.length - spotsA.length);
    
    console.log(`\nDuplicate coordinate groups found: ${duplicateGroups.length}`);
    console.log(`Unique coordinates: ${Object.keys(coordinateGroups).length}`);
    
    if (duplicateGroups.length > 0) {
      console.log('\n📍 TOP 10 DUPLICATE GROUPS:');
      duplicateGroups.slice(0, 10).forEach(([coords, spots], index) => {
        console.log(`\n[${index + 1}] Coordinates: ${coords} (${spots.length} spots)`);
        spots.forEach((spot, i) => {
          const date = new Date(spot.created_at).toLocaleString();
          console.log(`   ${i + 1}. ${spot.title} (ID: ${spot.id.slice(0, 8)}, Created: ${date})`);
        });
      });
      
      // Count total duplicate spots
      const totalDuplicates = duplicateGroups.reduce((sum, [key, spots]) => sum + spots.length - 1, 0);
      console.log(`\n📊 SUMMARY:`);
      console.log(`- Total spots: ${spots.length}`);
      console.log(`- Unique coordinates: ${Object.keys(coordinateGroups).length}`);
      console.log(`- Duplicate spots: ${totalDuplicates}`);
      console.log(`- Expected after deduplication: ${spots.length - totalDuplicates}`);
      
      // Show sample titles for most duplicated location
      if (duplicateGroups.length > 0) {
        const [coords, topDupes] = duplicateGroups[0];
        console.log(`\n🔍 Most duplicated location (${coords}):`);
        topDupes.forEach(spot => {
          console.log(`   - "${spot.title}"`);
        });
      }
    } else {
      console.log('✅ No duplicate coordinates found!');
    }
    
  } catch (error) {
    console.error('❌ Error checking duplicates:', error.message);
  }
}

checkDuplicateSpots();