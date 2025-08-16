# Scenic Cloud Architecture Design Document
## Supabase + Cloudinary Implementation

---

## 1. Executive Summary

This document outlines the cloud architecture for Scenic using:
- **Supabase**: PostgreSQL database, authentication, real-time subscriptions, and edge functions
- **Cloudinary**: Media storage, transformation, and CDN delivery
- **iOS Client**: SwiftUI app with Supabase SDK integration

### Key Benefits
- **Scalability**: Both services auto-scale with usage
- **Cost-effective**: Generous free tiers, pay-as-you-grow model
- **Developer-friendly**: Excellent SDKs, real-time capabilities built-in
- **Performance**: Global CDN for media, edge functions for low latency
- **Security**: Row-level security (RLS), secure media upload flows

---

## 2. Architecture Overview

```
┌─────────────────┐         ┌──────────────────┐
│                 │         │                  │
│   iOS Client    │◄────────┤    Cloudinary    │
│   (SwiftUI)     │         │   (Media CDN)    │
│                 │         │                  │
└────────┬────────┘         └────────▲─────────┘
         │                           │
         │                           │ Upload URLs
         │                           │
         ▼                           │
┌─────────────────────────────────────────────┐
│                                             │
│              Supabase Platform              │
│                                             │
│  ┌─────────────┐  ┌──────────────────┐    │
│  │   Auth      │  │   PostgreSQL     │    │
│  │  Service    │  │    Database      │    │
│  └─────────────┘  └──────────────────┘    │
│                                             │
│  ┌─────────────┐  ┌──────────────────┐    │
│  │  Realtime   │  │  Edge Functions  │    │
│  │   (WSS)     │  │   (Deno)         │    │
│  └─────────────┘  └──────────────────┘    │
│                                             │
│  ┌────────────────────────────────────┐    │
│  │    Row Level Security (RLS)        │    │
│  └────────────────────────────────────┘    │
│                                             │
└─────────────────────────────────────────────┘
```

---

## 3. Database Schema (Supabase PostgreSQL)

### 3.1 Core Tables

```sql
-- Users table (extends Supabase auth.users)
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    display_name TEXT,
    bio TEXT,
    avatar_url TEXT,
    explorer_score INTEGER DEFAULT 0,
    explorer_level TEXT DEFAULT 'novice',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Settings
    privacy_mode TEXT DEFAULT 'public', -- public, friends, private
    email_notifications BOOLEAN DEFAULT true,
    push_notifications BOOLEAN DEFAULT true,
    
    -- Stats
    spots_created INTEGER DEFAULT 0,
    photos_shared INTEGER DEFAULT 0,
    plans_created INTEGER DEFAULT 0,
    comments_made INTEGER DEFAULT 0,
    spots_discovered INTEGER DEFAULT 0,
    
    CONSTRAINT username_length CHECK (char_length(username) >= 3)
);

-- Spots table
CREATE TABLE public.spots (
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
CREATE INDEX spots_location_idx ON spots USING GIST (location);
CREATE INDEX spots_created_at_idx ON spots(created_at DESC);
CREATE INDEX spots_created_by_idx ON spots(created_by);

-- Media table
CREATE TABLE public.media (
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

-- Sun/Weather snapshots
CREATE TABLE public.sun_snapshots (
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

CREATE TABLE public.weather_snapshots (
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
CREATE TABLE public.access_info (
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

-- Social tables
CREATE TABLE public.comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spot_id UUID REFERENCES spots(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(id),
    parent_id UUID REFERENCES comments(id), -- For replies
    
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    upvote_count INTEGER DEFAULT 0,
    is_pinned BOOLEAN DEFAULT false
);

CREATE TABLE public.votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id),
    spot_id UUID REFERENCES spots(id) ON DELETE CASCADE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, spot_id)
);

CREATE TABLE public.saves (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id),
    spot_id UUID REFERENCES spots(id) ON DELETE CASCADE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, spot_id)
);

-- Plans
CREATE TABLE public.plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id),
    
    title TEXT NOT NULL,
    description TEXT,
    planned_date DATE,
    
    is_public BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.plan_spots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id UUID REFERENCES plans(id) ON DELETE CASCADE,
    spot_id UUID REFERENCES spots(id),
    
    order_index INTEGER NOT NULL,
    arrival_time TIME,
    duration_minutes INTEGER,
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Explorer mechanics
CREATE TABLE public.achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    icon_url TEXT,
    points INTEGER DEFAULT 10,
    category TEXT
);

CREATE TABLE public.user_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id),
    achievement_id UUID REFERENCES achievements(id),
    
    earned_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, achievement_id)
);

-- Activity feed
CREATE TABLE public.activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id),
    type TEXT NOT NULL, -- spot_created, photo_added, plan_shared, etc.
    
    spot_id UUID REFERENCES spots(id),
    plan_id UUID REFERENCES plans(id),
    target_user_id UUID REFERENCES profiles(id),
    
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX activities_user_idx ON activities(user_id, created_at DESC);
CREATE INDEX activities_type_idx ON activities(type);
```

### 3.2 Row Level Security (RLS) Policies

```sql
-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE spots ENABLE ROW LEVEL SECURITY;
ALTER TABLE media ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE saves ENABLE ROW LEVEL SECURITY;
ALTER TABLE plans ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Public profiles are viewable by everyone"
    ON profiles FOR SELECT
    USING (true);

CREATE POLICY "Users can update own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id);

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

-- Comments policies
CREATE POLICY "Comments are viewable by everyone"
    ON comments FOR SELECT
    USING (true);

CREATE POLICY "Authenticated users can comment"
    ON comments FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can edit own comments"
    ON comments FOR UPDATE
    USING (auth.uid() = user_id);

-- Votes policies
CREATE POLICY "Votes are viewable by everyone"
    ON votes FOR SELECT
    USING (true);

CREATE POLICY "Authenticated users can vote"
    ON votes FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can remove own votes"
    ON votes FOR DELETE
    USING (auth.uid() = user_id);

-- Plans policies
CREATE POLICY "Public plans viewable by everyone"
    ON plans FOR SELECT
    USING (is_public = true OR user_id = auth.uid());

CREATE POLICY "Users can create own plans"
    ON plans FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own plans"
    ON plans FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own plans"
    ON plans FOR DELETE
    USING (auth.uid() = user_id);
```

---

## 4. Authentication Flow

### 4.1 Sign Up Flow
```swift
// 1. User signs up with email or Sign in with Apple
let user = try await supabase.auth.signUp(
    email: email,
    password: password
)

// 2. Create profile
let profile = Profile(
    id: user.id,
    username: username,
    displayName: displayName
)
try await supabase
    .from("profiles")
    .insert(profile)
    .execute()

// 3. Upload avatar to Cloudinary (optional)
let avatarUrl = try await uploadToCloudinary(
    image: avatarImage,
    folder: "avatars",
    publicId: user.id
)

// 4. Update profile with avatar
try await supabase
    .from("profiles")
    .update(["avatar_url": avatarUrl])
    .eq("id", user.id)
    .execute()
```

### 4.2 Authentication Methods
1. **Email/Password**: Standard Supabase auth
2. **Sign in with Apple**: Required for iOS, trusted
3. **Magic Link**: Passwordless email auth
4. **Phone OTP**: SMS verification (optional)

### 4.3 Session Management
- Supabase SDK handles token refresh automatically
- Persist session in iOS Keychain
- Check session on app launch
- Handle expired sessions gracefully

---

## 5. Media Handling with Cloudinary

### 5.1 Upload Flow

```swift
// 1. Get upload preset from Edge Function (secure)
let uploadData = try await supabase.functions
    .invoke("get-cloudinary-signature", body: [
        "folder": "spots/\(spotId)",
        "tags": ["spot", "user:\(userId)"]
    ])

// 2. Upload to Cloudinary
let cloudinaryResponse = try await uploadToCloudinary(
    image: photo,
    uploadPreset: uploadData.preset,
    signature: uploadData.signature,
    timestamp: uploadData.timestamp
)

// 3. Store reference in Supabase
let media = Media(
    spotId: spotId,
    userId: userId,
    cloudinaryPublicId: cloudinaryResponse.publicId,
    cloudinaryUrl: cloudinaryResponse.url,
    // ... EXIF data
)
try await supabase
    .from("media")
    .insert(media)
    .execute()

// 4. Trigger processing for optimized versions
try await supabase.functions
    .invoke("process-media", body: [
        "mediaId": media.id,
        "transformations": ["thumbnail", "optimized", "webp"]
    ])
```

### 5.2 Cloudinary Transformations

```javascript
// Transformation presets
const transformations = {
    thumbnail: "c_thumb,w_150,h_150,g_auto",
    card: "c_fill,w_400,h_300,g_auto,q_auto",
    detail: "c_limit,w_1200,h_1200,q_auto",
    optimized: "f_auto,q_auto,dpr_auto,w_auto",
    blur: "e_blur:2000,q_1,f_auto", // For NSFW content
};

// Responsive image URLs
const responsiveUrl = `https://res.cloudinary.com/${cloudName}/image/upload/w_auto,c_scale,q_auto,dpr_auto/${publicId}`;
```

### 5.3 Media Processing Pipeline

1. **Upload**: Original to Cloudinary
2. **Extract EXIF**: Parse metadata client-side
3. **Generate Variants**: 
   - Thumbnail (150x150)
   - Card (400x300)
   - Detail (1200x1200 max)
   - WebP for web
4. **Content Moderation**: Auto-tag with AWS Rekognition
5. **CDN Distribution**: Global edge caching

---

## 6. API Design (Edge Functions)

### 6.1 Core Edge Functions

```typescript
// get-cloudinary-signature
export async function handler(req: Request) {
    const { folder, tags } = await req.json();
    const timestamp = Math.round(Date.now() / 1000);
    
    const signature = cloudinary.utils.api_sign_request({
        timestamp,
        folder,
        tags: tags.join(','),
        upload_preset: 'scenic_mobile'
    }, CLOUDINARY_API_SECRET);
    
    return new Response(JSON.stringify({
        signature,
        timestamp,
        apiKey: CLOUDINARY_API_KEY,
        cloudName: CLOUDINARY_CLOUD_NAME,
        uploadPreset: 'scenic_mobile'
    }));
}

// process-media
export async function handler(req: Request) {
    const { mediaId, transformations } = await req.json();
    
    // Get media record
    const { data: media } = await supabase
        .from('media')
        .select('*')
        .eq('id', mediaId)
        .single();
    
    // Generate transformation URLs
    const urls = {};
    for (const transform of transformations) {
        urls[transform] = cloudinary.url(media.cloudinary_public_id, {
            transformation: transformations[transform]
        });
    }
    
    // Update media record
    await supabase
        .from('media')
        .update({
            thumbnail_url: urls.thumbnail,
            optimized_url: urls.optimized,
            processing_status: 'completed'
        })
        .eq('id', mediaId);
    
    return new Response(JSON.stringify({ success: true, urls }));
}

// discover-feed
export async function handler(req: Request) {
    const { latitude, longitude, radius = 50000 } = await req.json();
    
    // Get spots within radius or globally if no location
    const query = supabase
        .from('spots')
        .select(`
            *,
            media(
                cloudinary_secure_url,
                thumbnail_url
            ),
            profiles!created_by(
                username,
                avatar_url
            ),
            sun_snapshots(
                golden_hour_start_utc,
                golden_hour_end_utc
            )
        `)
        .eq('privacy', 'public')
        .order('created_at', { ascending: false })
        .limit(50);
    
    if (latitude && longitude) {
        // Use PostGIS for spatial query
        query.rpc('nearby_spots', {
            lat: latitude,
            lng: longitude,
            radius_meters: radius
        });
    }
    
    const { data: spots } = await query;
    
    return new Response(JSON.stringify(spots));
}

// calculate-sun-times
export async function handler(req: Request) {
    const { latitude, longitude, date } = await req.json();
    
    const sunTimes = SunCalc.getTimes(
        new Date(date),
        latitude,
        longitude
    );
    
    return new Response(JSON.stringify({
        sunrise: sunTimes.sunrise,
        sunset: sunTimes.sunset,
        goldenHourStart: sunTimes.goldenHour,
        goldenHourEnd: sunTimes.sunset,
        blueHourStart: sunTimes.dusk,
        blueHourEnd: sunTimes.night
    }));
}
```

---

## 7. Real-time Features

### 7.1 Real-time Subscriptions

```swift
// Subscribe to new spots in area
let subscription = supabase
    .from("spots")
    .on(.insert) { payload in
        // New spot added nearby
        handleNewSpot(payload.new)
    }
    .subscribe()

// Subscribe to comments on a spot
let commentSub = supabase
    .from("comments")
    .on(.insert)
    .filter("spot_id", .eq, spotId) { payload in
        // New comment added
        handleNewComment(payload.new)
    }
    .subscribe()

// Activity feed subscription
let activitySub = supabase
    .from("activities")
    .on(.insert)
    .filter("user_id", .in, followedUserIds) { payload in
        // New activity from followed users
        handleNewActivity(payload.new)
    }
    .subscribe()
```

### 7.2 Presence (Who's viewing)

```swift
// Track who's viewing a spot
let presence = supabase.channel("spot:\(spotId)")
    .on(.presence) { state in
        // Update viewer count
        updateViewerCount(state.presences.count)
    }
    .subscribe()

// Send presence
presence.track([
    "user_id": userId,
    "username": username,
    "avatar_url": avatarUrl
])
```

---

## 8. Migration Strategy

### 8.1 Phase 1: Dual Mode (Week 1-2)
1. Keep Core Data functional
2. Add Supabase SDK and authentication
3. Implement cloud sync for new data
4. Test with small user group

### 8.2 Phase 2: Migration (Week 3)
1. Export Core Data to JSON
2. Create migration Edge Function
3. Upload existing media to Cloudinary
4. Import data to Supabase
5. Verify data integrity

### 8.3 Phase 3: Cloud-First (Week 4)
1. Switch to Supabase as primary
2. Keep Core Data for offline cache
3. Implement sync conflict resolution
4. Remove Core Data dependencies

---

## 9. Security Considerations

### 9.1 API Security
- **Row Level Security**: Enforced at database level
- **API Rate Limiting**: 100 requests/minute per user
- **Upload Validation**: File type, size limits
- **Content Moderation**: Auto-flag inappropriate content

### 9.2 Media Security
- **Signed Upload URLs**: Prevent unauthorized uploads
- **Watermarking**: Optional for premium content
- **DMCA Compliance**: Report and takedown system
- **Privacy Controls**: User-controlled visibility

### 9.3 Data Privacy
- **GDPR Compliance**: Right to deletion, data export
- **Encryption**: TLS in transit, AES-256 at rest
- **PII Protection**: Minimal personal data collection
- **Location Privacy**: Optional location fuzzing

---

## 10. Cost Analysis

### 10.1 Supabase Pricing (Free Tier)
- **Database**: 500MB storage
- **Auth**: Unlimited users
- **Realtime**: 200 concurrent connections
- **Edge Functions**: 500K invocations/month
- **Bandwidth**: 2GB/month

### 10.2 Supabase Pro ($25/month)
- **Database**: 8GB storage
- **Auth**: Unlimited users
- **Realtime**: 500 concurrent connections
- **Edge Functions**: 2M invocations/month
- **Bandwidth**: 50GB/month
- **Daily backups**: 7 days retention

### 10.3 Cloudinary Pricing (Free Tier)
- **Storage**: 25 monthly credits
- **Bandwidth**: 25GB/month
- **Transformations**: 25K/month
- **API Calls**: Unlimited

### 10.4 Cloudinary Plus ($89/month)
- **Storage**: 225 monthly credits
- **Bandwidth**: 225GB/month
- **Transformations**: 225K/month
- **Auto-backup**: Included
- **Advanced analytics**: Included

### 10.5 Estimated Costs by User Scale

| Users | Storage | Bandwidth | Supabase | Cloudinary | Total/Month |
|-------|---------|-----------|----------|------------|-------------|
| 100   | 5GB     | 10GB      | Free     | Free       | $0          |
| 1K    | 50GB    | 100GB     | $25      | $89        | $114        |
| 10K   | 500GB   | 1TB       | $25      | $299       | $324        |
| 100K  | 5TB     | 10TB      | $599     | $899       | $1,498      |

---

## 11. Implementation Roadmap

### Week 1: Foundation
- [ ] Set up Supabase project
- [ ] Create database schema
- [ ] Configure RLS policies
- [ ] Set up Cloudinary account
- [ ] Implement authentication in iOS app

### Week 2: Core Features
- [ ] Implement spot creation with cloud sync
- [ ] Media upload to Cloudinary
- [ ] Basic Edge Functions
- [ ] Real-time subscriptions
- [ ] Update iOS models for cloud

### Week 3: Social Features
- [ ] Comments system
- [ ] Voting mechanism
- [ ] User profiles
- [ ] Activity feed
- [ ] Push notifications setup

### Week 4: Advanced Features
- [ ] Planning with LLM integration
- [ ] Explorer achievements
- [ ] Content moderation
- [ ] Analytics dashboard
- [ ] Performance optimization

### Week 5: Migration & Testing
- [ ] Migrate existing data
- [ ] Load testing
- [ ] Security audit
- [ ] Bug fixes
- [ ] Beta user onboarding

### Week 6: Launch Preparation
- [ ] Documentation
- [ ] Admin panel
- [ ] Monitoring setup
- [ ] Backup procedures
- [ ] Go-live checklist

---

## 12. iOS Implementation Details

### 12.1 Dependencies

```swift
// Package.swift or SPM
dependencies: [
    .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0"),
    .package(url: "https://github.com/cloudinary/cloudinary_ios", from: "3.0.0")
]
```

### 12.2 Configuration

```swift
// SupabaseManager.swift
class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://YOUR_PROJECT.supabase.co")!,
            supabaseKey: "YOUR_ANON_KEY"
        )
    }
    
    func signIn(email: String, password: String) async throws -> User {
        let response = try await client.auth.signIn(
            email: email,
            password: password
        )
        return response.user
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }
}

// CloudinaryManager.swift
class CloudinaryManager: ObservableObject {
    static let shared = CloudinaryManager()
    
    let cloudinary: CLDCloudinary
    
    private init() {
        let config = CLDConfiguration(
            cloudName: "YOUR_CLOUD_NAME",
            secure: true
        )
        cloudinary = CLDCloudinary(configuration: config)
    }
    
    func upload(image: UIImage, folder: String) async throws -> CloudinaryResponse {
        // Implementation
    }
}
```

### 12.3 Offline Support

```swift
// CoreDataSyncManager.swift
class CoreDataSyncManager {
    func syncToCloud() async throws {
        // 1. Get unsynced records from Core Data
        let unsyncedSpots = fetchUnsyncedSpots()
        
        // 2. Upload to Supabase
        for spot in unsyncedSpots {
            let cloudSpot = try await uploadSpot(spot)
            
            // 3. Update Core Data with cloud ID
            spot.cloudId = cloudSpot.id
            spot.syncedAt = Date()
        }
        
        // 4. Save Core Data
        try viewContext.save()
    }
    
    func syncFromCloud() async throws {
        // 1. Fetch latest from Supabase
        let cloudSpots = try await fetchCloudSpots()
        
        // 2. Merge with Core Data
        for cloudSpot in cloudSpots {
            updateOrCreateLocalSpot(from: cloudSpot)
        }
        
        // 3. Save Core Data
        try viewContext.save()
    }
}
```

---

## 13. Monitoring & Analytics

### 13.1 Key Metrics
- **User Growth**: Daily/Weekly/Monthly active users
- **Content Creation**: Spots/Photos per day
- **Engagement**: Comments, votes, saves per spot
- **Performance**: API latency, upload success rate
- **Costs**: Storage, bandwidth, API calls

### 13.2 Monitoring Stack
- **Supabase Dashboard**: Built-in analytics
- **Cloudinary Dashboard**: Media analytics
- **Sentry**: Error tracking
- **PostHog**: Product analytics
- **Custom Dashboard**: Business metrics

---

## 14. Risk Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Data loss | Low | High | Daily backups, multi-region storage |
| Service outage | Low | High | Offline mode, graceful degradation |
| Cost overrun | Medium | Medium | Usage alerts, rate limiting |
| Security breach | Low | High | RLS, encryption, security audits |
| Scaling issues | Medium | Medium | Auto-scaling, caching, CDN |
| Bad content | Medium | Low | Auto-moderation, reporting system |

---

## 15. Success Criteria

### Technical Success
- [ ] 99.9% uptime
- [ ] < 200ms API response time (p95)
- [ ] < 3s image upload time
- [ ] Zero data loss incidents
- [ ] Successful migration of existing data

### Business Success
- [ ] 1000+ active users in first month
- [ ] 50+ spots created daily
- [ ] 4.5+ App Store rating maintained
- [ ] < $500/month infrastructure cost
- [ ] 30% of users using planning feature

---

## Appendix A: Database Functions

```sql
-- Function to find nearby spots
CREATE OR REPLACE FUNCTION nearby_spots(
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    radius_meters INTEGER DEFAULT 50000
)
RETURNS SETOF spots AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM spots
    WHERE ST_DWithin(
        location::geography,
        ST_MakePoint(lng, lat)::geography,
        radius_meters
    )
    ORDER BY location <-> ST_MakePoint(lng, lat)::geography;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate explorer score
CREATE OR REPLACE FUNCTION calculate_explorer_score(user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    score INTEGER := 0;
BEGIN
    -- Base points for content
    SELECT INTO score
        (COUNT(DISTINCT s.id) * 100) + -- 100 points per spot
        (COUNT(DISTINCT m.id) * 10) +  -- 10 points per photo
        (COUNT(DISTINCT c.id) * 5) +   -- 5 points per comment
        (COUNT(DISTINCT v.id) * 2)     -- 2 points per vote
    FROM profiles p
    LEFT JOIN spots s ON s.created_by = p.id
    LEFT JOIN media m ON m.user_id = p.id
    LEFT JOIN comments c ON c.user_id = p.id
    LEFT JOIN votes v ON v.user_id = p.id
    WHERE p.id = user_id;
    
    -- Bonus for achievements
    SELECT score + (COUNT(*) * a.points)
    INTO score
    FROM user_achievements ua
    JOIN achievements a ON a.id = ua.achievement_id
    WHERE ua.user_id = user_id;
    
    RETURN score;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update vote counts
CREATE OR REPLACE FUNCTION update_vote_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE spots
        SET vote_count = vote_count + 1
        WHERE id = NEW.spot_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE spots
        SET vote_count = vote_count - 1
        WHERE id = OLD.spot_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_spot_votes
AFTER INSERT OR DELETE ON votes
FOR EACH ROW
EXECUTE FUNCTION update_vote_count();
```

---

## Appendix B: Example Queries

```swift
// Find spots near user
let nearbySpots = try await supabase
    .rpc("nearby_spots", params: [
        "lat": userLocation.latitude,
        "lng": userLocation.longitude,
        "radius_meters": 10000
    ])
    .select("""
        *,
        media(cloudinary_secure_url, thumbnail_url),
        profiles!created_by(username, avatar_url)
    """)
    .execute()

// Get trending spots
let trendingSpots = try await supabase
    .from("spots")
    .select("""
        *,
        media(cloudinary_secure_url),
        vote_count,
        comment_count
    """)
    .eq("privacy", "public")
    .gte("created_at", lastWeek)
    .order("vote_count", ascending: false)
    .limit(20)
    .execute()

// User's activity feed
let activities = try await supabase
    .from("activities")
    .select("""
        *,
        profiles!user_id(username, avatar_url),
        spots(title, media(thumbnail_url))
    """)
    .in("user_id", followedUserIds)
    .order("created_at", ascending: false)
    .limit(50)
    .execute()
```

---

## Conclusion

This architecture provides a scalable, cost-effective foundation for Scenic's cloud infrastructure. The combination of Supabase and Cloudinary offers:

1. **Rapid Development**: Excellent SDKs and built-in features
2. **Scalability**: Both services handle growth automatically
3. **Real-time**: Native support for live features
4. **Security**: Enterprise-grade security built-in
5. **Cost-effective**: Generous free tiers, predictable scaling costs

The implementation can be done incrementally, starting with authentication and gradually migrating features to the cloud while maintaining the existing Core Data functionality for offline support.