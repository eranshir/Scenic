# Scenic — Non‑Functional Requirements & Acceptance Criteria

## Non‑Functional Requirements (NFRs)
- **Performance**: P95 cold start ≤ 3s; P95 map pan latency ≤ 16ms/frame; resumable background uploads; thumbnails LCP ≤ 1s on LTE.
- **Offline**: plans viewable; cached tiles for selected regions; metadata + thumbnails cached.
- **Reliability**: crash‑free sessions ≥ 99.5%; retries with backoff; idempotent writes.
- **Security**: TLS 1.2+; signed URLs; server‑side media validation; rate limiting; moderation audit logs.
- **Privacy**: limited photo permissions; location sharing controls; GDPR/CCPA export & delete within 30 days.
- **Accessibility**: Dynamic Type; VoiceOver; contrast; tap targets; reduce motion options.

## Acceptance Criteria — Core Flows

### AC‑Add‑01: Add Spot from Photo
- Given a geotagged photo, app pre‑fills GPS, capture time, device, lens, EXIF; computes nearest sunrise/sunset and relative minutes; shows weather snapshot.
- User can correct capture point within ±5km; heading within 0–359°.
- Publish succeeds via background upload with actionable retry on failure.

### AC‑Plan‑01: Build Plan for Date
- With ≥1 saved spot and a date, app computes sunrise/sunset for that spot (TZ aware), draws golden/blue bars on a day timeline, and sequences spots with ETAs.

### AC‑Discover‑01: Filter by Time Window & Weather
- Applying filters updates map/list within 300ms of network response; empty state proposes 3 alt spots within 50km.

### AC‑Detail‑01: Export GPX
- “Export GPX” produces a valid GPX including parking point and route polyline; shareable via iOS share sheet.
