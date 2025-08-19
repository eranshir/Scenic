# Plan Feature - Project Implementation Plan

## 1. Overview & Vision

The Plan feature transforms Scenic from a photo spot discovery app into a comprehensive trip planning platform. Users can create detailed, hour-by-hour itineraries that consider optimal photography timing, logistics, and social sharing.

### Core Value Proposition
- **For Photographers**: Optimize shooting schedules around golden hour, sunrise, and sunset
- **For Travelers**: Discover and organize scenic locations with accommodations and dining
- **For Community**: Share and fork proven itineraries

## 2. Feature Requirements

### 2.1 Plan Creation & Management
- [ ] Create new plans without pre-populated dates
- [ ] Plans can be Private or Public (toggle anytime)
- [ ] Public plans are discoverable by other users
- [ ] Public plans can be forked/copied by other users
- [ ] Public plans hide specific dates (show relative timing instead)

### 2.2 Content Management
- [ ] Add photo spots to plans from spot detail views
- [ ] Add accommodations, restaurants, and attractions via Apple Maps/Mapbox integration
- [ ] Manual reordering of plan items
- [ ] Remove items from plans

### 2.3 AI Organization Engine
- [ ] LLM-powered plan organization
- [ ] Requires either specific dates OR trip duration in days
- [ ] Iterative refinement based on user feedback
- [ ] Considers travel time between locations
- [ ] Optimizes for photography timing preferences

### 2.4 Timing & Scheduling
- [ ] Hour-by-hour itinerary generation
- [ ] Integration with sunrise/sunset calculations
- [ ] User preferences for timing:
  - Sunrise visits
  - Sunset visits  
  - Golden hour visits
  - Blue hour visits
  - No timing preference
- [ ] Automatic schedule optimization based on preferences

### 2.5 Social Features
- [ ] Public plan discovery and browsing
- [ ] Plan forking with attribution to original creator
- [ ] Plan sharing via standard iOS share sheet

## 3. Data Model Design

### 3.1 Core Entities

#### Plan
```swift
struct Plan {
    let id: UUID
    let title: String
    let description: String?
    let createdBy: UUID // User ID
    let createdAt: Date
    let updatedAt: Date
    let isPublic: Bool
    let originalPlanId: UUID? // For forked plans
    let estimatedDuration: Int? // Days
    let startDate: Date?
    let endDate: Date?
}
```

#### PlanItem
```swift
struct PlanItem {
    let id: UUID
    let planId: UUID
    let type: PlanItemType // .spot, .accommodation, .restaurant, .attraction
    let order: Int
    let scheduledDate: Date?
    let scheduledStartTime: Date?
    let scheduledEndTime: Date?
    let timingPreference: TimingPreference?
    let spotId: UUID? // If type is .spot
    let poiData: POIData? // If type is accommodation/restaurant/attraction
    let notes: String?
}
```

#### Supporting Types
```swift
enum PlanItemType: String, CaseIterable {
    case spot = "spot"
    case accommodation = "accommodation" 
    case restaurant = "restaurant"
    case attraction = "attraction"
}

enum TimingPreference: String, CaseIterable {
    case sunrise = "sunrise"
    case sunset = "sunset"
    case goldenHour = "golden_hour"
    case blueHour = "blue_hour"
    case flexible = "flexible"
}

struct POIData {
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let category: String
    let phoneNumber: String?
    let website: String?
    let mapItemIdentifier: String? // Apple Maps MKMapItem identifier
}
```

### 3.2 Database Schema (Supabase)

#### plans table
```sql
CREATE TABLE plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_public BOOLEAN DEFAULT FALSE,
    original_plan_id UUID REFERENCES plans(id) ON DELETE SET NULL,
    estimated_duration INTEGER, -- days
    start_date DATE,
    end_date DATE
);
```

#### plan_items table
```sql
CREATE TABLE plan_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id UUID REFERENCES plans(id) ON DELETE CASCADE,
    type plan_item_type NOT NULL,
    order_index INTEGER NOT NULL,
    scheduled_date DATE,
    scheduled_start_time TIMESTAMPTZ,
    scheduled_end_time TIMESTAMPTZ,
    timing_preference timing_preference,
    spot_id UUID REFERENCES spots(id) ON DELETE CASCADE,
    poi_data JSONB, -- For non-spot items
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## 4. UI/UX Design Requirements

### 4.1 Navigation Structure
```
Plans Tab
├── My Plans List
│   ├── Create New Plan
│   └── Plan Detail View
│       ├── Plan Items List
│       ├── Map View (All Items)
│       ├── Add Items (Search/Browse)
│       ├── Organize with AI
│       └── Share/Privacy Settings
└── Discover Public Plans
    ├── Browse/Search Public Plans
    └── View Public Plan (Read-only)
        └── Fork This Plan
```

### 4.2 Key Screens

#### Plans List View
- List of user's plans (private and public)
- Filter by public/private
- Search plans
- Create new plan button
- Each plan shows: title, duration, item count, privacy status

#### Plan Detail View
- Plan header: title, description, privacy toggle
- Timeline/list view toggle
- Plan items in chronological order (if scheduled)
- Map view showing all locations
- Add item button (floating action)
- Organize button (AI feature)
- Share button

#### Add to Plan Modal (from Spot Detail)
- List of user's existing plans
- "Create new plan" option
- Quick add with timing preference selection

#### Plan Organization View
- Current plan layout
- "Organize with AI" button
- Duration/dates input
- Timing preferences per item
- Iterative improvement suggestions

### 4.3 Map Integration
- Show all plan items on unified map
- Different pins for spots, accommodations, restaurants, attractions
- Route visualization between items
- Day-by-day filtering for multi-day plans

## 5. Technical Implementation Plan

### 5.1 Phase 1: Core Data Models & UI (2-3 weeks)

#### Week 1: Database & Models
- [ ] Create Supabase tables and types
- [ ] Implement Core Data models for offline caching
- [ ] Create Plan and PlanItem Swift models
- [ ] Set up data sync service between Supabase and Core Data

#### Week 2: Basic UI Framework
- [ ] Create Plans tab in main navigation
- [ ] Implement Plans list view
- [ ] Create Plan detail view with basic CRUD
- [ ] Add plan creation flow
- [ ] Implement privacy toggle

#### Week 3: Plan Item Management
- [ ] Add "Add to Plan" functionality to Spot Detail view
- [ ] Create add item modal
- [ ] Implement manual item reordering
- [ ] Basic map view showing plan items

### 5.2 Phase 2: POI Integration & Search (2 weeks)

#### Week 4: Apple Maps Integration
- [ ] Implement MapKit local search for accommodations
- [ ] Add restaurant search functionality  
- [ ] Implement attraction search
- [ ] Create POI selection and addition flow

#### Week 5: Enhanced Plan Management
- [ ] Implement plan item detail editing
- [ ] Add timing preference selection
- [ ] Create plan sharing functionality
- [ ] Implement plan forking for public plans

### 5.3 Phase 3: AI Organization Engine (3-4 weeks)

#### Week 6-7: LLM Integration
- [ ] Design prompt templates for plan organization
- [ ] Integrate with OpenAI or Claude API
- [ ] Implement initial organization algorithm
- [ ] Add travel time calculations between locations

#### Week 8-9: Schedule Optimization
- [ ] Implement sunrise/sunset timing integration
- [ ] Create hour-by-hour schedule generation
- [ ] Add iterative improvement system
- [ ] Implement schedule visualization

### 5.4 Phase 4: Social Features & Polish (2 weeks)

#### Week 10: Public Plans & Discovery
- [ ] Implement public plan discovery
- [ ] Create plan browsing and search
- [ ] Add plan forking functionality
- [ ] Implement attribution system

#### Week 11: Polish & Testing
- [ ] UI/UX refinements
- [ ] Performance optimization
- [ ] Comprehensive testing
- [ ] Bug fixes and edge cases

## 6. API Integrations Required

### 6.1 Apple Maps / MapKit
- **Purpose**: Search for accommodations, restaurants, attractions
- **APIs**: `MKLocalSearch`, `MKLocalSearchRequest`
- **Data**: POI names, addresses, coordinates, categories

### 6.2 OpenAI / Claude API
- **Purpose**: Plan organization and optimization
- **Input**: List of plan items, user preferences, timing constraints
- **Output**: Optimized schedule with reasoning

### 6.3 Travel Time APIs (Optional Enhancement)
- **Purpose**: Accurate travel time between locations
- **Options**: Apple Maps directions, Google Maps API
- **Use**: Realistic schedule generation

## 7. User Experience Flows

### 7.1 Create New Plan Flow
1. User taps "Create Plan" from Plans tab
2. Enter plan title and optional description
3. Choose to add items immediately or later
4. Plan created, navigate to Plan Detail view

### 7.2 Add Spot to Plan Flow
1. User viewing Spot Detail
2. Tap "Add to Plan" button
3. Select existing plan or create new
4. Choose timing preference (sunrise/sunset/etc.)
5. Item added to plan with preferences

### 7.3 AI Organization Flow
1. User has plan with multiple unscheduled items
2. Tap "Organize with AI" 
3. Specify trip duration or specific dates
4. AI generates optimized schedule
5. User reviews and can request modifications
6. Accept or iterate on the suggestions

### 7.4 Plan Sharing Flow
1. User makes plan public via privacy toggle
2. Plan becomes discoverable in public plans
3. Other users can view (dates hidden) and fork
4. Original creator gets attribution

## 8. Key Technical Considerations

### 8.1 Performance
- Lazy loading of plan items and POI data
- Efficient Core Data queries with proper indexing
- Map view optimization for plans with many items
- Background sync for plan updates

### 8.2 Offline Support
- Core Data caching of plan data
- Offline map tiles for plan locations
- Queue API calls when offline
- Conflict resolution for concurrent edits

### 8.3 Privacy & Security
- Row Level Security (RLS) for private plans
- Proper user authentication checks
- Sanitize public plan data (remove personal info)
- Rate limiting for AI organization requests

### 8.4 Scalability
- Pagination for large plans
- Efficient database queries
- CDN for plan-related media
- Caching strategy for public plan discovery

## 9. Success Metrics

### 9.1 Adoption Metrics
- Plans created per user
- Plan items added per plan (target: 5-10)
- Public plan creation rate
- Plan fork rate

### 9.2 Engagement Metrics  
- AI organization feature usage
- Plan sharing frequency
- Time spent in plan views
- Return visits to modify plans

### 9.3 Quality Metrics
- AI organization satisfaction ratings
- Plan completion rates (items actually visited)
- User feedback on schedule accuracy
- Support tickets related to plan features

## 10. Risk Mitigation

### 10.1 Technical Risks
- **LLM API reliability**: Implement fallback organization algorithms
- **Apple Maps API limits**: Cache POI data, implement usage monitoring
- **Complex scheduling logic**: Start with simple algorithms, iterate

### 10.2 Product Risks
- **Feature complexity**: Phase rollout, gather feedback early
- **User adoption**: Ensure core value is clear, minimize friction
- **Performance issues**: Load testing with realistic data volumes

## 11. Future Enhancements (Post-MVP)

- [ ] Weather integration for plan recommendations
- [ ] Collaborative plan editing
- [ ] Plan templates for common trip types
- [ ] Integration with calendar apps
- [ ] Expense tracking within plans
- [ ] Local guide recommendations
- [ ] Advanced AI features (budget optimization, crowd avoidance)

---

**Estimated Timeline**: 10-11 weeks
**Team Size**: 1-2 developers
**Priority**: High - Core differentiator for Scenic platform