# Scenic — UX Specification & Screen Catalog

## Navigation
- **Tab Bar**: Home, Plans, Journal, Notifications, Profile
- **Deep Links**: `scenic://spot/{id}`, `scenic://plan/{id}`, `scenic://add`
- **Modals**: Filters, Route Drawer, Share Sheet

## Screen Table
| ID | Screen | Purpose | Primary Components | Primary Actions | Empty/Edge | Errors | Analytics |
|---|---|---|---|---|---|---|---|
| S-001 | Onboarding Intro | Value prop | Carousel, CTA | Continue | — | — | onboarding_view, onboarding_cta_tap |
| S-002 | Permissions | Request Photos/Location/Notifications | Permission cards, rationale modals | Grant / Not now | Limited mode explanation | Settings deep link | perm_view, perm_grant, perm_deny |
| S-010 | Home Map | Discover on map | MapKit clustering, search, filter chips, drawer | Filter, search, open preview | Suggest relax filters | Network/geo fail | map_view, map_filter_apply, map_pin_open, map_to_detail |
| S-011 | Home Feed | Card discovery | Card list w/ media, upvote/save | Open spot, upvote, save | Suggest connect region/interests | Pagination fail | feed_view, feed_card_open, feed_upvote, feed_save |
| S-020 | Spot Detail | Execute on site / plan | Media carousel, sun widget, weather row, EXIF, route drawer, comments | Save to plan, AR, copy GPS/GPX, upvote, comment | Prompt to enrich if missing | Snapshot fetch fail | spot_view, spot_save_to_plan, spot_gpx_copy, spot_upvote, comment_post |
| S-030 | Add: Media Picker | Seed spot | Photo grid (geotagged first), multi‑select | Select, continue | No permissions | Picker denied | add_media_open, add_media_select, add_media_continue |
| S-031 | Add: Metadata Confirm | Confirm/extract | Prefilled GPS/time/device/lens; sun offsets; weather | Edit fields, adjust heading, set capture point | No EXIF: place on map | Compute fail | add_meta_view, add_meta_edit, add_meta_continue |
| S-032 | Add: Parking & Route | Approach logistics | Map draw/record, distance/elevation, hazards/fees | Draw/record, set difficulty | No GPS: sketch | Save fail | add_route_view, add_route_draw, add_route_save |
| S-033 | Add: Tips & Publish | Submission | Text fields, toggles (license/visibility) | Publish (bg upload), edit after | Incomplete: disable publish | Upload fail | add_publish_attempt, add_publish_success, add_publish_error |
| S-040 | Plans | Itinerary | Date selector, timeline (sun bars), spots, backup | Add/reorder, offline pack, GPX | Suggest nearby | Offline pack fail | plan_view, plan_add, plan_offline_dl, plan_export_gpx |
| S-050 | Journal | Private record | Map of personal pins, timeline, stats | Export CSV/GPX, convert | Nudge first spot | Export fail | journal_view, journal_export |
| S-060 | Profile | Identity | Avatar, bio, badges, contributions | Follow, report, share | — | — | profile_view, follow_tap |
| S-061 | Reputation | Credibility | Score, titles, signals | — | — | — | reputation_view |
| S-070 | Notifications | Updates | Grouped notifications, filters | Open, mark read, settings | Tip to follow/save | Fetch fail | notif_view, notif_open_item |
| S-080 | Settings | Preferences & privacy | Permissions, units, licenses, data export/delete | Export, delete account | — | Delete warn | settings_view, data_export, account_delete_request |

## Key UI Components
- **Sun Widget** (sunrise/sunset, golden/blue ranges, relative minutes; expand for chart)
- **Weather Chip Row** (temp, clouds %, wind; tap for detail/forecast align)
- **Route Drawer** (mini‑map, distance, elevation, difficulty; full map; GPX export)
- **EXIF Block** (device/lens, focal/aperture/shutter/ISO, resolution, presets)
- **Vote Bar** (upvote, score, save)
- **Comment Thread** (rich text + media replies; sort)
