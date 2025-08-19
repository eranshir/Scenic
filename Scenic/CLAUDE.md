# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## CRITICAL RULES

### File Organization
- **Documentation Files**: Always create `.md` documentation files in `/Scenic/documents/` directory
- **Script Files**: Always create script files (`.js`, `.py`, `.sh`, etc.) in `/scripts/` directory
- **Project Plans**: All project plans, specifications, and planning documents go in `/Scenic/documents/`
- **Import/Utility Scripts**: All data processing, import, and utility scripts go in `/scripts/`

### Package Management
- **NEVER** delete, remove, or modify Swift Package Manager dependencies in Xcode project files without explicit user approval
- **NEVER** remove package references from project.pbxproj without consulting the user first
- If package issues arise, suggest solutions but do not execute package removal
- Always preserve existing package configurations unless explicitly instructed otherwise

## Project Overview

Scenic is a crowdsourced photography platform for iOS that helps photographers discover optimal photo locations with detailed metadata including timing, sun position, weather conditions, and access logistics. The app unifies photo spot discovery, capture metadata, and social sharing for both hobbyist and professional photographers.

## Architecture & Technology Stack

### Platform Decision
- **Primary**: Native iOS using SwiftUI + UIKit interop
- **Target**: iOS 17+ for modern Photos, MapKit, WeatherKit APIs
- **Future**: Kotlin Multiplatform Mobile (KMM) for Android code sharing

### Core Services & Integrations
- **Authentication**: Sign in with Apple
- **Storage**: S3 or Cloudflare R2 + CDN for media
- **Database**: PostgreSQL + PostGIS for geospatial data
- **Cache**: Redis for session/query caching
- **Weather**: Apple WeatherKit (forecast), historical via cache
- **Maps**: Apple MapKit with clustering and overlays
- **Background Processing**: URLSession for uploads
- **Photos**: Photos framework for HEIC/Live Photos/ProRAW

### Database Schema
PostgreSQL with PostGIS extensions for geospatial queries. Key tables:
- `users`: Authentication, reputation scoring, roles
- `spots`: Core photo locations with PostGIS GEOGRAPHY points
- `media`: Photos/videos with EXIF metadata (JSONB)
- `sun_snapshots`: Cached sunrise/sunset/golden hour calculations
- `weather_snapshots`: Historical weather at capture time
- `access_info`: Parking locations, routes, hazards
- `plans`: User itineraries with spot scheduling
- Social features: `comments`, `votes`, `follows`, `badges`

All timestamps in UTC. GIN indexes for tags/text search, GIST for geospatial.

## Key Technical Components

### EXIF & Metadata Processing
- Extract from DSLR/mirrorless photos and iPhone HEIC/Live Photos
- Capture: GPS coordinates, heading, elevation, camera settings (focal length, aperture, shutter, ISO)
- Device/lens identification for gear tracking
- Support for ProRAW and Live Photo formats

### Sun Calculations
- Implement NOAA Solar Position Algorithm (SPA) on-device
- Calculate sunrise, sunset, golden hour, blue hour windows
- Cache results in `sun_snapshots` table by spot+date

### Geospatial Features
- PostGIS for radius queries and clustering
- Encoded polylines or GeoJSON for hiking routes
- MapKit integration with custom overlays and clusters
- AR heading overlay for precise camera positioning

### Offline Capabilities
- Map tile caching for selected regions
- Metadata and thumbnail bundles for saved plans
- Background sync engine for updates

## Development Phases

1. **Phase 0 (2-3 weeks)**: Technical spikes - EXIF parsing, sun calculations, map overlays, background uploads
2. **Phase 1 (6-8 weeks)**: iOS core - discovery map, spot details, contribution flow
3. **Phase 2 (6-8 weeks)**: Backend - API, ingestion pipeline, media processing
4. **Phase 3 (4-6 weeks)**: Social features - voting, comments, reputation system
5. **Phase 4 (4-6 weeks)**: Offline mode and advanced itinerary planning
6. **Phase 5 (3-4 weeks)**: Polish for App Store submission

## Performance Requirements

- Cold start < 2.5s (P90)
- Crash-free sessions ≥ 99.5% (P95)
- Background upload resilience for 1GB+ videos
- Offline map performance with 10K+ cached spots

## Security & Privacy Considerations

- No sensitive location exposure (military, private property)
- User-generated content moderation pipeline
- NSFW/abuse detection before publication
- Duplicate spot detection via perceptual hashing + spatial clustering
- Privacy controls for journal entries vs public spots

## Key User Flows

### Spot Discovery
Map view with clustering → Filter by time/weather/difficulty → Preview card → Detailed spot view

### Contribution Flow
Select photos → Extract EXIF → Confirm metadata → Draw parking/route → Add tips → Background upload

### Planning Flow
Browse spots → Add to plan → Auto-adjust for sunrise/sunset → Calculate drive times → Download offline pack

## Analytics Events

Core events to track:
- Discovery: `map_view`, `map_filter_apply`, `spot_view`
- Contribution: `add_media_select`, `add_publish_success`
- Engagement: `spot_upvote`, `comment_post`, `plan_add`
- Retention: `journal_export`, `offline_dl`

## Recent Development History

### Enhanced Photo Carousel & Caching System (August 2025)
**Commit**: `6c6518e` - "Feature: Enhanced photo carousel with comprehensive caching system"

#### Major Implementation
Implemented a complete overhaul of the photo management and display system:

**Photo Carousel Improvements:**
- Fixed photo loading and display issues in spot detail view
- Implemented smooth horizontal scrolling carousel with wrap-around navigation
- Added subtle visual hierarchy (5% size difference between center/side photos)
- Enhanced animations with spring effects and center-lock behavior
- Integrated compass rose overlays showing photo heading information
- Professional timing analysis with sun position context

**Unified Photo Caching System:**
- `PhotoCacheService`: Local storage management with file existence checking
- `PhotoLoader`: Unified loading from cached files with CDMedia integration  
- `UnifiedPhotoView`: Consistent photo loading component across all views
- Background sync capabilities for offline access
- Cache management with UUID-based file naming

**Core Data Integration:**
- Complete Core Data model matching PostgreSQL schema
- Entities: `CDSpot`, `CDMedia`, `CDSunSnapshot`, `CDWeatherSnapshot`, `CDAccessInfo`
- Extensions for seamless conversion between Core Data and Swift models
- `SpotDataService`: Data management layer with CRUD operations
- `PersistenceController`: Shared Core Data stack management

**Technical Solutions Implemented:**
- Fixed SwiftUI ForEach ID conflicts in infinite carousel arrays
- Resolved photo loading race conditions and cache misses
- Implemented proper offset calculations for carousel positioning
- Added comprehensive error handling and logging for debugging
- Created fallback loading strategies for missing cache files

**Files Created/Modified:**
- Services: `PhotoCacheService`, `PhotoLoader`, `SpotDataService`, `PersistenceController`
- Views: Enhanced `SpotDetailView` carousel, `UnifiedPhotoView`, `AsyncPhotoView`, `CachedPhotoView`
- Models: Complete Core Data model with extensions
- Integration: Journal view displays cached photos, spot list uses unified loading

This implementation establishes the foundation for offline photo access, consistent UI across all views, and professional photo presentation with metadata context.