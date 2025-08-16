# Scenic — Product Requirements Document (PRD)

## 1. Problem & Opportunity
Photographers waste time finding exact vantage points, timing (golden/blue hour), and on‑site logistics (parking, hike route, safety). Existing apps either focus on generic POIs, basic EXIF journals, or standalone weather/sun apps. Scenic unifies these into a crowdsourced, metadata‑rich platform to plan, capture, and share proven photo spots.

## 2. Goals & Non‑Goals
### Goals
- Make it fast to discover verified scenic spots tailored to date/time/sun/weather.
- Capture and enrich spot submissions with rich metadata (EXIF, geospatial, heading, sun position, weather, access logistics, safety notes).
- Provide personal photo journal + public sharing with social feedback and credibility scoring.
- Enable itinerary building with dynamic adaptation to sunrise/sunset and forecast.

### Non‑Goals (v1)
- Full trip booking, car rentals, or accommodation search.
- Desktop web parity (read‑only web can be considered).
- ML quality scoring and auto‑culling of a user’s entire library (consider later).

## 3. Target Users & Personas
- **Avi (Hobbyist Photographer)**: weekend shooter, uses iPhone + occasional mirrorless, needs easy guidance.
- **Noa (Travel Creator / Pro)**: time‑sensitive, seeks exact coordinates, headings, and onsite logistics.
- **Tomer (Nature Lover)**: hikes casually, wants parking spots, trail difficulty, offline access.

## 4. Key Use Cases & User Stories
- **Discover**: “As Avi, I want to search a region and filter by golden/blue hour, weather windows, subject type, and difficulty.”
- **Plan**: “As Noa, I want to assemble a day plan that aligns with sunrise/sunset and drive times, including backup spots.”
- **Capture & Log**: “As Tomer, I want to upload photos/videos with auto‑extracted metadata and annotate the route from my parking spot.”
- **Share & Discuss**: “As Avi, I want to post a spot with tips and receive comments/upvotes.”
- **Credibility**: “As Noa, I want a visible score and titles that reflect contribution quality and consistency.”

## 5. Success Metrics (v1)
- D7 retention ≥ 25%, D30 ≥ 15%.
- ≥ 40% of active users save ≥ 3 spots to a plan in first month.
- ≥ 15% of sessions include viewing route/parking data.
- ≥ 20% of publicly shared spots receive comments/upvotes.

## 6. Feature Scope (v1)
- **Spot Discovery**: map/list with filters (subject, seasonality, light window proximity, weather, popularity, difficulty).
- **Spot Detail**: EXIF, heading, coordinates, sun timeline, historical weather snapshot, parking & route, tips, safety, comments, linked gallery from same spot.
- **Contribute Flow**: pick photos/videos → extract EXIF → confirm/enrich → draw route from parking → submit.
- **Journal Mode**: private timeline & map of personal captures, exportable.
- **Plans/Itineraries**: save spots to plan, auto‑adapt to chosen date; show sunrise/sunset per spot, drive/hike ETAs; offline download.
- **Social**: upvotes, comments, roles (“Explorer” of a spot), contributor score.
- **Moderation**: flagging, spam/NSFW detection, duplicate spot merge.

## 7. Constraints & Assumptions
- iOS 17+ to leverage modern Photos, MapKit, WeatherKit, and SwiftUI APIs.
- EXIF present in most DSLR/mirrorless; for iPhone HEIC/Live Photos use Photos framework.
- Weather: Apple WeatherKit (or alternative) for historical & forecast; caching required.
- Sun data: on‑device solar calc (e.g., NOAA algorithm) to avoid rate limits.
- Offline: maps + saved media + plan metadata cached locally.

## 8. Risks
- Inaccurate geotags or camera headings → reputation system + community edits + duplicate merge.
- Legal/privacy: people/property privacy, sensitive locations, safety at hazardous spots.
- Weather history licensing & costs; rate limiting.
- Content quality variance → ranking + editorial curation later.
