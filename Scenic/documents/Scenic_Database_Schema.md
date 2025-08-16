# Scenic — Database Schema (PostgreSQL + PostGIS)

Use UTC everywhere; add `created_at`, `updated_at` to all tables. PostGIS for geospatial, GIN for tags/text search.

```sql
-- Users
CREATE TABLE users (
  id UUID PRIMARY KEY,
  handle TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  reputation_score INT DEFAULT 0,
  home_region TEXT,
  roles TEXT[] DEFAULT ARRAY['user'],
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Spots
CREATE TABLE spots (
  id UUID PRIMARY KEY,
  title TEXT,
  location GEOGRAPHY(POINT, 4326) NOT NULL,
  heading_deg SMALLINT,  -- 0-359
  elevation_m INT,
  subject_tags TEXT[],
  difficulty SMALLINT,   -- 1-5
  created_by UUID REFERENCES users(id),
  privacy TEXT CHECK (privacy IN ('public','private')) DEFAULT 'public',
  license TEXT DEFAULT 'CC-BY-NC',
  status TEXT CHECK (status IN ('active','pending','removed')) DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_spots_geo ON spots USING GIST (location);
CREATE INDEX idx_spots_tags ON spots USING GIN (subject_tags);

-- Media
CREATE TABLE media (
  id UUID PRIMARY KEY,
  spot_id UUID REFERENCES spots(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  type TEXT CHECK (type IN ('photo','video','live')) NOT NULL,
  url TEXT NOT NULL,
  thumbnail_url TEXT,
  capture_time_utc TIMESTAMPTZ,
  exif_json JSONB,
  device TEXT, lens TEXT,
  focal_length_mm REAL, aperture REAL, shutter_s REAL, iso INT,
  resolution_w INT, resolution_h INT,
  presets TEXT[], filters TEXT[],
  heading_from_exif BOOLEAN,
  original_filename TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_media_spot ON media(spot_id);
CREATE INDEX idx_media_capture_time ON media(capture_time_utc);

-- Sun snapshots
CREATE TABLE sun_snapshots (
  id UUID PRIMARY KEY,
  spot_id UUID REFERENCES spots(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  sunrise_utc TIMESTAMPTZ, sunset_utc TIMESTAMPTZ,
  golden_start_utc TIMESTAMPTZ, golden_end_utc TIMESTAMPTZ,
  blue_start_utc TIMESTAMPTZ, blue_end_utc TIMESTAMPTZ,
  closest_event TEXT CHECK (closest_event IN ('sunrise','sunset')),
  rel_minutes_to_event INT
);
CREATE UNIQUE INDEX ux_sun_spot_date ON sun_snapshots(spot_id, date);

-- Weather snapshots
CREATE TABLE weather_snapshots (
  id UUID PRIMARY KEY,
  spot_id UUID REFERENCES spots(id) ON DELETE CASCADE,
  time_utc TIMESTAMPTZ NOT NULL,
  source TEXT,
  temperature_c REAL, wind_mps REAL, clouds_pct REAL,
  precipitation_mm REAL, visibility_m REAL, condition_code TEXT
);
CREATE INDEX idx_weather_spot_time ON weather_snapshots(spot_id, time_utc);

-- Access info
CREATE TABLE access_info (
  id UUID PRIMARY KEY,
  spot_id UUID UNIQUE REFERENCES spots(id) ON DELETE CASCADE,
  parking_point GEOGRAPHY(POINT, 4326),
  route_polyline TEXT, -- encoded polyline or GeoJSON
  route_distance_m INT,
  route_elevation_gain_m INT,
  route_difficulty SMALLINT,
  hazards TEXT[], fees TEXT[], notes TEXT
);

-- Comments
CREATE TABLE comments (
  id UUID PRIMARY KEY,
  spot_id UUID REFERENCES spots(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  body TEXT NOT NULL,
  attachments UUID[] REFERENCES media(id)[],
  parent_id UUID REFERENCES comments(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_comments_spot ON comments(spot_id);

-- Votes
CREATE TABLE votes (
  id UUID PRIMARY KEY,
  target_type TEXT CHECK (target_type IN ('spot','media','comment')),
  target_id UUID NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  value SMALLINT CHECK (value IN (1,-1)) DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (target_type, target_id, user_id)
);

-- Plans
CREATE TABLE plans (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  name TEXT,
  start_date DATE,
  timezone TEXT,
  is_offline_cached BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE plan_items (
  id UUID PRIMARY KEY,
  plan_id UUID REFERENCES plans(id) ON DELETE CASCADE,
  spot_id UUID REFERENCES spots(id) ON DELETE CASCADE,
  target_date DATE,
  planned_arrival_utc TIMESTAMPTZ,
  planned_departure_utc TIMESTAMPTZ,
  backup_rank SMALLINT
);
CREATE INDEX idx_plan_items_plan ON plan_items(plan_id);

-- Badges & user badges
CREATE TABLE badges (
  id UUID PRIMARY KEY,
  code TEXT UNIQUE,
  name TEXT,
  criteria_json JSONB
);
CREATE TABLE user_badges (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  badge_id UUID REFERENCES badges(id) ON DELETE CASCADE,
  awarded_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, badge_id)
);

-- Reports
CREATE TABLE reports (
  id UUID PRIMARY KEY,
  target_type TEXT,
  target_id UUID,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  reason TEXT, status TEXT DEFAULT 'open',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Follows
CREATE TABLE follows (
  follower_id UUID REFERENCES users(id) ON DELETE CASCADE,
  followee_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (follower_id, followee_id)
);
```

## Indexes & Search
- PostGIS GIST on `spots.location`
- GIN on tags and full‑text search (`spots.title`, tips, comments)
- Time‑based indexes for recency
