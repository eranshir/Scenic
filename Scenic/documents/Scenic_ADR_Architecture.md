# Scenic — Architecture Decision Record (ADR): SwiftUI vs Cross‑Platform

## Problem
Pick the primary UI technology for the iOS app and assess cross‑platform alternatives.

## Options Considered
1. **SwiftUI (with UIKit interop)** — Native iOS
2. **React Native** — JS/TS cross‑platform
3. **Flutter** — Dart cross‑platform
4. **Kotlin Multiplatform Mobile (KMM)** — shared logic, native UIs

## Decision Matrix (1–5, higher is better)

| Criteria | SwiftUI | React Native | Flutter | KMM |
|---|---:|---:|---:|---:|
| Photos/HEIC/Live Photos integration | 5 | 3 | 3 | 5 (logic) |
| MapKit (clustering, overlays, Look Around) | 5 | 3 | 3 | 5 (logic) |
| WeatherKit & Apple services | 5 | 3 | 3 | 5 (logic) |
| Background uploads / URLSession | 5 | 3 | 3 | 5 |
| Performance & battery | 5 | 4 | 4 | 5 |
| Dev velocity (v1) | 4 | 4 | 4 | 3 |
| Cross‑platform reach (future) | 2 | 5 | 5 | 4 |
| Plugin maturity for advanced camera/EXIF | 5 | 3 | 3 | 5 |
| Offline maps & tiles | 5 | 3 | 3 | 5 |
| Hiring & community for iOS‑first | 5 | 4 | 4 | 3 |
| **Weighted total (iOS‑first priority)** | **4.8** | **3.4** | **3.4** | **4.4** |

## Decision
**SwiftUI + UIKit interop** for v1. KMM may be introduced later to share non‑UI logic if/when building Android.

## Rationale & Risks
- Tight integration with Apple frameworks (Photos/MapKit/WeatherKit), best perf & battery, lowest risk for background uploads and offline caching. 
- Risks: SwiftUI gaps on some complex UI cases → mitigate with UIKit wrappers.

## Technical Spikes
1. EXIF & Live Photo ingest (HEIC + ProRAW); benchmark on device.
2. Sun/Weather widget: implement NOAA SPA; cross‑check vs WeatherKit.
3. Map overlays & AR heading (clusters, routes, ARKit proof).
4. Background uploads: 1GB video, resume across network toggles.

## Proposed Services
- Auth: Sign in with Apple
- Storage/CDN: S3 or Cloudflare R2 + CDN
- Backend: Postgres + PostGIS, Redis, worker queue
- Weather: WeatherKit (forecast); historical via cache + licensed source
- Maps: Apple MapKit; optional Mapbox for custom tiles (later)
