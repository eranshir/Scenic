# Scenic — Project Plan & Work Breakdown Structure

## Priority Development Tasks (Updated: 2025-08-16)
- [ ] Implement the discover feed
- [ ] Implement authentication and user mgmt
- [ ] Implement server side
- [ ] Populate with spots all over the world 
- [ ] Implement Planning
    - [ ] Collect spots to a plan
    - [ ] Get guidance from LLM on your plan
    - [ ] Payment for planning feature 
- [ ] Implement comments/discussions/stars 
- [ ] Implement Explorer vanity mechanics 
- [ ] Implement onboarding 

## Timeline (Condensed)
- **Phase 0 (2–3 wks)** Foundations & spikes.
- **Phase 1 (6–8 wks)** iOS core client.
- **Phase 2 (6–8 wks)** Backend & ingestion.
- **Phase 3 (4–6 wks)** Social & reputation.
- **Phase 4 (4–6 wks)** Offline & itineraries+.
- **Phase 5 (3–4 wks)** Polish & Beta.

## Epics → Key Stories
- **E1 Discovery**: map clustering, filters (time/weather/tags/difficulty), bbox search, pin previews.
- **E2 Contribution**: EXIF parser, sun calc, historical weather fetch, heading adjuster, parking/route editor, background uploads.
- **E3 Spot Detail**: sun/blue/golden widget, weather snapshot, EXIF block, GPX export, AR heading overlay (optional v1.1).
- **E4 Plans**: timeline with light windows, add/reorder, ETAs, offline pack.
- **E5 Social**: votes, comments, follows, notifications.
- **E6 Reputation**: score calc, badges, titles, explorer status.
- **E7 Moderation**: reports, NSFW/abuse checks, duplicate merge tool.
- **E8 Offline**: tile cache, metadata/thumbnail bundles, sync engine.

## RACI (Sample)
- PM: PRD/roadmap; Design: UX/specs; iOS: client; Backend: API/data; DevOps: CI/CD; Data: scoring/analytics.

## Milestone Exit Criteria
- **M1 Alpha**: Add→Publish E2E; Map discover; Spot detail; Plans basic; Crash rate < 1%.
- **M2 Beta (TestFlight)**: Social + notifications; Offline packs; Basic moderation; P90 cold start < 2.5s.
- **M3 Launch**: Reputation; Growth hooks; App Review cleared; P95 crash‑free sessions ≥ 99.5%.

## Risks & Mitigations
- Weather history licensing → cache by `spot_id+date`; fallback “unknown” UX.
- Duplicate spots → perceptual hash + spatial clustering + merge tool.
- Sensitive locations → blocklist; user warnings & masking.
