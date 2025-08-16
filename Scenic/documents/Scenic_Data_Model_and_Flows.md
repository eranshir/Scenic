# Scenic — Data Model & Data Flows

## Conceptual Entities
- **User**(id, name, handle, email, reputation_score, roles, home_region, created_at)
- **Spot**(id, title, location[lat,lng], heading_deg, elevation, subject_tags[], difficulty, created_by, created_at, status, privacy, license)
- **Media**(id, spot_id, user_id, type[photo|video|live], url, thumbnail_url, capture_time_utc, exif_json, device, lens, focal_length_mm, aperture, shutter_s, iso, resolution_w,h, presets[], filters[], heading_from_exif?, original_filename)
- **SunSnapshot**(id, spot_id, date, sunrise_utc, sunset_utc, golden_start_utc, golden_end_utc, blue_start_utc, blue_end_utc, closest_event, rel_minutes_to_event)
- **WeatherSnapshot**(id, spot_id, time_utc, source, temperature_c, wind_mps, clouds_pct, precipitation_mm, visibility_m, condition_code)
- **AccessInfo**(id, spot_id, parking_point[lat,lng], route_polyline, route_distance_m, route_elevation_gain_m, route_difficulty, hazards[], fees[], notes)
- **Comment**(id, spot_id, user_id, body, attachments[], created_at, parent_id)
- **Vote**(id, target_type[spot|media|comment], target_id, user_id, value)
- **Plan**(id, user_id, name, start_date, timezone, is_offline_cached)
- **PlanItem**(id, plan_id, spot_id, target_date, planned_arrival_utc, planned_departure_utc, backup_rank)
- **Badge**(id, code, name, criteria_json); **UserBadge**(id, user_id, badge_id, awarded_at); **Report**; **Follow**

## Relationships
- User 1‑* Spot, Media, Comment, Plan, Vote
- Spot 1‑* Media, Comment, Vote; 1‑1 AccessInfo; 1‑* SunSnapshot; 1‑* WeatherSnapshot
- Plan 1‑* PlanItem

## Taxonomies
- `subject_tags`: landscape, cityscape, astro, seascape, wildlife, architecture, waterfall, reflections, drone, long‑exposure, panorama, macro, night‑sky, milky‑way, street, portrait‑in‑scene
- `conditions`: fog, low‑clouds, snow, clear, waves, reflections, storm, aurora (future)
- `difficulty`: 1–5; `license`: CC‑BY‑NC (default), CC‑BY, All Rights Reserved

## Validation Examples
- `heading_deg` ∈ [0,359]
- If `privacy='private'` → exclude from discovery/social
- `planned_departure_utc` ≥ `planned_arrival_utc`

## Derived Fields
- `spot.score` (materialized) from votes + accuracy signals
- `spot.popularity_rank` per region

## Data Flows

### Contribute Flow
1. Select media → read EXIF on device
2. Compute sun times locally → request historical weather → cache
3. Confirm GPS/heading; draw/record route; add tips
4. Upload media to object storage; metadata to API (background/resumable)
5. Backend dedupe (spatial + perceptual hash), moderation, indexing

### Discovery & Planning
1. Apply region/filters → search/index → map clusters
2. Open spot → fetch detail + sun snapshot + historical weather
3. Save to plan → compute day timeline with sunrise/sunset & ETAs
4. Offline pack → tiles + metadata + thumbnails

### Reputation & Scoring
- Upvotes weighted by voter reputation; time‑decay
- Accuracy signals: confirmed parking/route, low edit churn
- Completion impact: planned → visited → uploaded at matched conditions
