-- Phase 3: Metadata Tables (Sun, Weather, Access, Tips)
-- Run this after Phase 2

-- Sun/Weather snapshots
CREATE TABLE IF NOT EXISTS public.sun_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spot_id UUID REFERENCES spots(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    
    sunrise_utc TIMESTAMPTZ,
    sunset_utc TIMESTAMPTZ,
    golden_hour_start_utc TIMESTAMPTZ,
    golden_hour_end_utc TIMESTAMPTZ,
    blue_hour_start_utc TIMESTAMPTZ,
    blue_hour_end_utc TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(spot_id, date)
);

CREATE TABLE IF NOT EXISTS public.weather_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spot_id UUID REFERENCES spots(id) ON DELETE CASCADE,
    datetime_utc TIMESTAMPTZ NOT NULL,
    
    temperature_c REAL,
    feels_like_c REAL,
    conditions TEXT,
    wind_speed_kmh REAL,
    wind_direction INTEGER,
    humidity_percent INTEGER,
    visibility_km REAL,
    cloud_cover_percent INTEGER,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Access info
CREATE TABLE IF NOT EXISTS public.access_info (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spot_id UUID REFERENCES spots(id) ON DELETE CASCADE,
    
    parking_location GEOGRAPHY(POINT, 4326),
    parking_notes TEXT,
    route_coordinates GEOGRAPHY(LINESTRING, 4326),
    route_distance_meters INTEGER,
    route_duration_minutes INTEGER,
    
    permit_required BOOLEAN DEFAULT false,
    permit_details TEXT,
    fees TEXT[],
    hazards TEXT[],
    
    best_time_of_day TEXT,
    best_season TEXT,
    equipment_tips TEXT,
    composition_tips TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Photography Tips (user-contributed)
CREATE TABLE IF NOT EXISTS public.spot_tips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spot_id UUID REFERENCES spots(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(id),
    
    -- Tip categories
    type TEXT CHECK (type IN (
        'composition', 'timing', 'equipment', 'settings', 
        'weather', 'season', 'access', 'safety', 'general'
    )),
    
    title TEXT,
    body TEXT NOT NULL,
    
    -- Optional specific recommendations
    recommended_focal_length TEXT,
    recommended_aperture TEXT,
    recommended_time TEXT,
    recommended_season TEXT,
    
    -- Engagement
    helpful_count INTEGER DEFAULT 0,
    verified_by_creator BOOLEAN DEFAULT false,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS spot_tips_spot_idx ON spot_tips(spot_id);
CREATE INDEX IF NOT EXISTS spot_tips_type_idx ON spot_tips(type);

-- Media-specific annotations
CREATE TABLE IF NOT EXISTS public.media_annotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id UUID REFERENCES media(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(id),
    
    -- Annotation type
    type TEXT CHECK (type IN (
        'composition_note', 'camera_settings', 'processing_tip', 
        'location_marker', 'subject_highlight'
    )),
    
    -- Content
    text TEXT,
    
    -- Optional positioning for overlays (percentage of image)
    x_percent REAL CHECK (x_percent >= 0 AND x_percent <= 100),
    y_percent REAL CHECK (y_percent >= 0 AND y_percent <= 100),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE sun_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE weather_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_info ENABLE ROW LEVEL SECURITY;
ALTER TABLE spot_tips ENABLE ROW LEVEL SECURITY;
ALTER TABLE media_annotations ENABLE ROW LEVEL SECURITY;

-- Sun/Weather policies (viewable by all)
CREATE POLICY "Sun snapshots viewable by all"
    ON sun_snapshots FOR SELECT USING (true);

CREATE POLICY "Weather snapshots viewable by all"
    ON weather_snapshots FOR SELECT USING (true);

-- Access info policies
CREATE POLICY "Access info viewable with spot access"
    ON access_info FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM spots
            WHERE spots.id = access_info.spot_id
            AND (spots.privacy = 'public' OR spots.created_by = auth.uid())
        )
    );

CREATE POLICY "Spot creators can manage access info"
    ON access_info FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM spots
            WHERE spots.id = access_info.spot_id
            AND spots.created_by = auth.uid()
        )
    );

-- Spot tips policies
CREATE POLICY "Tips are viewable by everyone"
    ON spot_tips FOR SELECT USING (true);

CREATE POLICY "Authenticated users can add tips"
    ON spot_tips FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can edit own tips"
    ON spot_tips FOR UPDATE
    USING (auth.uid() = user_id);

-- Media annotations policies
CREATE POLICY "Annotations viewable with media access"
    ON media_annotations FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM media m
            JOIN spots s ON s.id = m.spot_id
            WHERE m.id = media_annotations.media_id
            AND (s.privacy = 'public' OR s.created_by = auth.uid())
        )
    );

CREATE POLICY "Authenticated users can annotate"
    ON media_annotations FOR INSERT
    WITH CHECK (auth.uid() = user_id);