# Scenic Prototype Project Plan
## Current State Analysis & Feature Roadmap

---

## 1. Current Implementation Status

### ✅ Completed Features (v0.0.1)

#### Core Infrastructure
- ✅ SwiftUI app architecture with tab-based navigation
- ✅ Data models for Spot, User, Plan, Media, AccessInfo, Comments
- ✅ AppState management for global state
- ✅ Navigation flow between all major screens

#### Spot Discovery & Viewing
- ✅ Map view with gesture support (pinch, zoom, pan)
- ✅ List view for spots
- ✅ Basic spot detail view
- ✅ Search bar UI (non-functional)
- ✅ Filter UI (non-functional)
- ✅ Spot preview cards on map

#### Spot Creation
- ✅ Multi-step creation flow (Media → Metadata → Route → Publish)
- ✅ Photo picker with multi-select
- ✅ EXIF metadata extraction (camera, lens, settings)
- ✅ Location extraction from photos
- ✅ Manual metadata entry for all photography settings
- ✅ Route drawing with tap-to-place points
- ✅ Parking location setting
- ✅ Hazards and fees selection
- ✅ Photography tips fields (best time, equipment, composition, seasonal)
- ✅ Privacy and license selection
- ✅ Auto-focus on title field

#### UI/UX Polish
- ✅ Progress indicator for multi-step flows
- ✅ Proper button positioning above tab bar
- ✅ Consistent navigation patterns
- ✅ Responsive map interactions

#### Plans & Journal
- ✅ Basic UI shells for Plans and Journal tabs
- ✅ Plan creation view
- ✅ Plan detail view

---

## 2. Gap Analysis (PRD vs Current State)

### 🔴 Critical Missing Features
1. **Sun/Sunrise/Sunset Data** - Core to the app's value proposition
2. **Weather Integration** - Historical and forecast data
3. **Functional Search & Filters** - Currently just UI
4. **Data Persistence** - Everything is mock data
5. **Photo/Video Display** - Can select but not display media

### 🟡 Important Missing Features
1. **Route Distance/Elevation Calculation**
2. **Driving Directions to Parking**
3. **Comments System**
4. **Upvoting/Rating System**
5. **User Profiles & Credibility Scores**
6. **Spot Linking** (multiple photos from same spot)

### 🟢 Nice-to-Have for Prototype
1. **Offline Support**
2. **Export Functionality**
3. **Duplicate Detection**
4. **Advanced Moderation**
5. **Social Features**

---

## 3. Prioritized Feature Roadmap for Prototype Phase

### Phase 1: Core Value Features (Week 1-2)
**Goal: Make the app functionally demonstrate its core value proposition**

#### 1.1 Sun Position & Timing (Priority: CRITICAL)
- [ ] Integrate solar calculation library (NOAA algorithm)
- [ ] Calculate and display sunrise/sunset times for spots
- [ ] Show golden hour and blue hour windows
- [ ] Display current sun position/angle for spots
- [ ] Show "time until golden hour" in spot cards
- [ ] Add sun timeline widget to spot detail view

#### 1.2 Heading-Based Media Gallery (Priority: CRITICAL)
**Signature Feature: Spatial photo organization by compass heading**

**Core Gallery Experience:**
- [ ] Implement circular gallery where photos are ordered by compass heading (0° to 360°)
- [ ] Create dynamic strip layout showing current photo prominently with adjacent photos visible
- [ ] Enable smooth swiping to navigate through directional sequence (like turning 360° at the spot)
- [ ] Handle photos without heading data by placing them at end before wrapping around
- [ ] Enable swiping when 2+ photos exist in gallery

**Visual Components:**
- [ ] Add responsive compass rose indicator showing current photo's heading
- [ ] Display selected photos in spot creation flow with heading preview
- [ ] Support video playback within the circular gallery
- [ ] Show EXIF overlay on photos (toggleable)
- [ ] Add thumbnail generation for performance

**Future Enhancements (Deferred):**
- Grouping multiple photos with similar headings (±10-15°) in sub-galleries with smaller thumbnails
- AR overlay showing heading gaps to encourage complete coverage

#### 1.3 Local Data Persistence (Priority: CRITICAL)
- [ ] Implement CoreData or SwiftData models
- [ ] Save created spots locally
- [ ] Persist user's plans
- [ ] Cache spot data for offline viewing
- [ ] Store media references properly
- [ ] Implement data migration strategy

### Phase 2: Enhanced Discovery (Week 3)
**Goal: Make spot discovery actually functional**

#### 2.1 Functional Search & Filters
- [ ] Implement location-based search
- [ ] Add filter by difficulty
- [ ] Filter by golden/blue hour availability
- [ ] Filter by tags/subjects
- [ ] Sort by distance/popularity/recency
- [ ] Save filter preferences

#### 2.2 Weather Integration
- [ ] Integrate WeatherKit or alternative API
- [ ] Show current weather for spots
- [ ] Display weather forecast for planning
- [ ] Store historical weather with spots
- [ ] Add weather-based recommendations

#### 2.3 Enhanced Map Features
- [ ] Cluster spots on map when zoomed out
- [ ] Show user's current location
- [ ] Display route polylines on map
- [ ] Add heat map for popular areas
- [ ] Quick preview on marker tap

### Phase 3: Planning & Logistics (Week 4)
**Goal: Enable actual trip planning**

#### 3.1 Smart Itinerary Building
- [ ] Add spots to plans from detail view
- [ ] Calculate optimal visit order based on sun position
- [ ] Show driving times between spots
- [ ] Display parking-to-spot walking times
- [ ] Generate day schedule with timing
- [ ] Export plan to calendar

#### 3.2 Navigation & Directions
- [ ] Integrate with Apple Maps for directions
- [ ] Show turn-by-turn to parking locations
- [ ] Display trail maps for hiking routes
- [ ] Add offline map download option
- [ ] Create breadcrumb trail recording

#### 3.3 Route Intelligence
- [ ] Calculate route distance from drawn points
- [ ] Estimate hiking time based on distance/elevation
- [ ] Show elevation profile
- [ ] Add difficulty auto-calculation
- [ ] Display total elevation gain

### Phase 4: Social & Community (Week 5)
**Goal: Add basic social proof and engagement**

#### 4.1 Basic Social Features
- [ ] Implement upvote/like system
- [ ] Add view counters
- [ ] Create saved/bookmarked spots
- [ ] Show "photos from this spot" gallery
- [ ] Add spot verification badges

#### 4.2 User Contributions
- [ ] Allow adding photos to existing spots
- [ ] Enable spot information corrections
- [ ] Add "I've been here" marking
- [ ] Create personal statistics dashboard
- [ ] Show contribution history

### Phase 5: Polish & Demo Ready (Week 6)
**Goal: Prepare for user testing and demos**

#### 5.1 Sample Data & Content
- [ ] Create 50+ high-quality sample spots
- [ ] Add professional photos for demos
- [ ] Generate realistic user profiles
- [ ] Create sample itineraries
- [ ] Add diverse geographic coverage

#### 5.2 UI/UX Refinements
- [ ] Add loading states and skeletons
- [ ] Implement pull-to-refresh
- [ ] Add empty states with CTAs
- [ ] Create onboarding flow
- [ ] Add tooltips for complex features
- [ ] Implement haptic feedback

#### 5.3 Performance & Stability
- [ ] Optimize image loading and caching
- [ ] Implement lazy loading for lists
- [ ] Add error handling and recovery
- [ ] Create offline fallbacks
- [ ] Profile and fix memory leaks

---

## 4. Deferred for Post-Prototype (Backend Required)

### Authentication & User Management
- User registration/login
- Profile management
- OAuth integration
- Password reset flows

### Backend Infrastructure
- API development
- Database setup
- Cloud storage for media
- CDN configuration
- Push notifications

### Advanced Social Features
- Following system
- Direct messaging
- Spot sharing via links
- Social feed algorithm
- Content moderation system

### Monetization
- Premium features
- Subscription management
- In-app purchases
- Analytics integration

---

## 5. Technical Debt & Improvements

### Current Technical Debt
1. Mock data throughout the app
2. No error handling
3. No loading states
4. Limited accessibility support
5. No unit tests
6. No UI tests

### Recommended Improvements
1. Implement proper dependency injection
2. Add comprehensive error handling
3. Create reusable UI components library
4. Implement proper image caching
5. Add analytics hooks (prepare for future)
6. Document component APIs

---

## 6. Success Criteria for Prototype

### Minimum Viable Prototype
- [ ] User can discover spots on a map with real sun data
- [ ] User can view detailed spot information with photos
- [ ] User can create a new spot with full metadata
- [ ] User can plan a trip with multiple spots
- [ ] Data persists between app launches

### Demo-Ready Prototype
- [ ] 50+ sample spots across multiple locations
- [ ] Smooth navigation and interactions
- [ ] Realistic sun and weather data
- [ ] Functional search and filters
- [ ] Shareable trip plans

---

## 7. Resource Requirements

### Development
- 1 iOS Developer (full-time, 6 weeks)
- UI/UX Designer (part-time for refinements)
- QA Tester (week 5-6)

### Content Creation
- Sample photography content
- Spot descriptions and tips
- Test user profiles

### Third-Party Services (Prototype Phase)
- Apple Developer Account (existing)
- WeatherKit API (free tier)
- MapKit (included with iOS)

---

## 8. Risk Mitigation

### Technical Risks
- **Sun calculation accuracy**: Use proven NOAA algorithms, validate with online tools
- **Weather API limits**: Implement aggressive caching, consider fallback APIs
- **Photo storage**: Start with photo library references, defer upload to backend phase
- **Performance with large datasets**: Implement pagination early, use Core Data properly

### User Experience Risks
- **Complex creation flow**: Add progress saving, allow editing after creation
- **Information overload**: Progressive disclosure, smart defaults
- **Map usability**: Extensive testing on real devices, consider accessibility

---

## 9. Next Immediate Steps

1. **Set up Core Data models** - Foundation for all features
2. **Implement sun calculations** - Core value proposition
3. **Add photo display to spots** - Visual appeal critical for photographers
4. **Make search functional** - Basic discovery requirement
5. **Connect filters to data** - Enable targeted discovery

---

## Notes
- This plan prioritizes features that demonstrate value without requiring backend infrastructure
- Social features are minimized in favor of core photography planning features
- Each phase builds on the previous, allowing for incremental testing
- The prototype should be compelling enough to validate the concept with real photographers