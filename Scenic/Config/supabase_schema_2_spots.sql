-- Phase 2: Spots and Media Tables
-- Run this after Phase 1

-- Spots table
CREATE TABLE IF NOT EXISTS public.spots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    
    -- Location
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    heading_degrees INTEGER,
    elevation_meters INTEGER,
    
    -- Reverse geocoding cache
    country TEXT,
    country_code TEXT,
    administrative_area TEXT,
    sub_administrative_area TEXT,
    locality TEXT,
    sub_locality TEXT,
    thoroughfare TEXT,
    sub_thoroughfare TEXT,
    postal_code TEXT,
    location_name TEXT,
    areas_of_interest TEXT[],
    
    -- Metadata
    difficulty INTEGER CHECK (difficulty BETWEEN 1 AND 5),
    subject_tags TEXT[],
    privacy TEXT DEFAULT 'public',
    license TEXT DEFAULT 'CC-BY-NC',
    status TEXT DEFAULT 'active',
    
    -- Creator
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Engagement
    vote_count INTEGER DEFAULT 0,
    comment_count INTEGER DEFAULT 0,
    view_count INTEGER DEFAULT 0,
    save_count INTEGER DEFAULT 0,
    
    -- Discovery
    is_featured BOOLEAN DEFAULT false,
    featured_at TIMESTAMPTZ,
    verified_at TIMESTAMPTZ,
    verified_by UUID REFERENCES profiles(id)
);

-- Create spatial index for location queries
CREATE INDEX IF NOT EXISTS spots_location_idx ON spots USING GIST (location);
CREATE INDEX IF NOT EXISTS spots_created_at_idx ON spots(created_at DESC);
CREATE INDEX IF NOT EXISTS spots_created_by_idx ON spots(created_by);

-- Media table
CREATE TABLE IF NOT EXISTS public.media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spot_id UUID REFERENCES spots(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(id),
    
    -- Cloudinary references
    cloudinary_public_id TEXT NOT NULL,
    cloudinary_url TEXT NOT NULL,
    cloudinary_secure_url TEXT NOT NULL,
    thumbnail_url TEXT,
    optimized_url TEXT, -- Auto-optimized version
    
    -- Media info
    type TEXT CHECK (type IN ('photo', 'video', 'live')),
    width INTEGER,
    height INTEGER,
    format TEXT,
    bytes INTEGER,
    duration REAL, -- For videos
    
    -- Photography metadata
    capture_time_utc TIMESTAMPTZ,
    device TEXT,
    lens TEXT,
    focal_length_mm REAL,
    aperture REAL,
    shutter_speed TEXT,
    iso INTEGER,
    
    -- EXIF from photo
    heading_degrees INTEGER,
    altitude_meters REAL,
    gps_latitude DOUBLE PRECISION,
    gps_longitude DOUBLE PRECISION,
    
    -- Processing
    presets TEXT[],
    filters TEXT[],
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    processing_status TEXT DEFAULT 'pending'
);

CREATE INDEX IF NOT EXISTS media_spot_idx ON media(spot_id);
CREATE INDEX IF NOT EXISTS media_user_idx ON media(user_id);

-- Enable RLS
ALTER TABLE spots ENABLE ROW LEVEL SECURITY;
ALTER TABLE media ENABLE ROW LEVEL SECURITY;

-- Spots policies
CREATE POLICY "Public spots are viewable by everyone"
    ON spots FOR SELECT
    USING (privacy = 'public' OR created_by = auth.uid());

CREATE POLICY "Users can create spots"
    ON spots FOR INSERT
    WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Users can update own spots"
    ON spots FOR UPDATE
    USING (auth.uid() = created_by);

-- Media policies
CREATE POLICY "Media viewable with spot access"
    ON media FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM spots
            WHERE spots.id = media.spot_id
            AND (spots.privacy = 'public' OR spots.created_by = auth.uid())
        )
    );

CREATE POLICY "Users can upload media to own spots"
    ON media FOR INSERT
    WITH CHECK (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM spots
            WHERE spots.id = media.spot_id
            AND spots.created_by = auth.uid()
        )
    );

-- Updated at triggers
CREATE TRIGGER set_timestamp
BEFORE UPDATE ON spots
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();