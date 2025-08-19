const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

async function checkCoordinates() {
  const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);
  const { data: spots } = await supabase.from('spots').select('id, title, latitude, longitude').limit(15);
  
  console.log('Checking spot coordinates:');
  spots?.forEach(s => {
    const lat = s.latitude;
    const lng = s.longitude;
    const isValidLat = typeof lat === 'number' && isFinite(lat) && Math.abs(lat) <= 90;
    const isValidLng = typeof lng === 'number' && isFinite(lng) && Math.abs(lng) <= 180;
    
    if (!isValidLat || !isValidLng) {
      console.log(`❌ ${s.title}: lat=${lat}, lng=${lng} (INVALID)`);
    } else {
      console.log(`✅ ${s.title}: lat=${lat}, lng=${lng}`);
    }
  });
}

checkCoordinates().catch(console.error);