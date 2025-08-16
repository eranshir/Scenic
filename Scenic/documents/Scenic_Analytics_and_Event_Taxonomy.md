# Scenic — Analytics & Event Taxonomy

## Identity & Governance
- device_id, user_id (post sign‑in), session_id, consent flags

## Core Events (examples)
- `map_filter_apply` → {region_bbox, tags[], time_window, difficulty[]}
- `spot_save_to_plan` → {spot_id, plan_id, date}
- `add_publish_success` → {spot_id, media_count, has_route, has_parking, license}
- `plan_offline_dl` → {plan_id, bytes, tiles, success}
- `comment_post` → {spot_id, length, attachments}
- `reputation_change` → {user_id, delta, reason}

## Funnels
- Discover → Spot Detail → Save to Plan → Offline DL → Trip Day Open
- Add Media → Confirm Metadata → Add Route → Publish

## KPIs
- Content health: avg votes/spot, % spots with route+parking, % spots with sun/conditions filled
- Planning efficacy: % plans executed (trip day opened at location ±10km), hit‑rate of golden/blue windows
