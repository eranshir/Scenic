-- Plans Feature Database Schema
-- This creates the tables and types needed for the Plans feature

-- Create enum types
CREATE TYPE plan_item_type AS ENUM ('spot', 'accommodation', 'restaurant', 'attraction');
CREATE TYPE timing_preference AS ENUM ('sunrise', 'sunset', 'golden_hour', 'blue_hour', 'flexible');

-- Plans table
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

-- Plan items table
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
    poi_data JSONB, -- For non-spot items (accommodation, restaurant, attraction)
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(plan_id, order_index) -- Ensure unique ordering within each plan
);

-- Indexes for performance
CREATE INDEX idx_plans_created_by ON plans(created_by);
CREATE INDEX idx_plans_is_public ON plans(is_public);
CREATE INDEX idx_plans_created_at ON plans(created_at DESC);
CREATE INDEX idx_plan_items_plan_id ON plan_items(plan_id);
CREATE INDEX idx_plan_items_order ON plan_items(plan_id, order_index);
CREATE INDEX idx_plan_items_scheduled_date ON plan_items(scheduled_date);
CREATE INDEX idx_plan_items_type ON plan_items(type);

-- Row Level Security (RLS) policies
ALTER TABLE plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE plan_items ENABLE ROW LEVEL SECURITY;

-- Plans policies
CREATE POLICY "Users can view their own plans" ON plans
    FOR SELECT USING (created_by = auth.uid());

CREATE POLICY "Users can view public plans" ON plans
    FOR SELECT USING (is_public = true);

CREATE POLICY "Users can create their own plans" ON plans
    FOR INSERT WITH CHECK (created_by = auth.uid());

CREATE POLICY "Users can update their own plans" ON plans
    FOR UPDATE USING (created_by = auth.uid());

CREATE POLICY "Users can delete their own plans" ON plans
    FOR DELETE USING (created_by = auth.uid());

-- Plan items policies
CREATE POLICY "Users can view plan items for their plans" ON plan_items
    FOR SELECT USING (
        plan_id IN (
            SELECT id FROM plans 
            WHERE created_by = auth.uid() OR is_public = true
        )
    );

CREATE POLICY "Users can create plan items for their plans" ON plan_items
    FOR INSERT WITH CHECK (
        plan_id IN (
            SELECT id FROM plans 
            WHERE created_by = auth.uid()
        )
    );

CREATE POLICY "Users can update plan items for their plans" ON plan_items
    FOR UPDATE USING (
        plan_id IN (
            SELECT id FROM plans 
            WHERE created_by = auth.uid()
        )
    );

CREATE POLICY "Users can delete plan items for their plans" ON plan_items
    FOR DELETE USING (
        plan_id IN (
            SELECT id FROM plans 
            WHERE created_by = auth.uid()
        )
    );

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_plans_updated_at BEFORE UPDATE ON plans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Helper function to get plan statistics
CREATE OR REPLACE FUNCTION get_plan_stats(plan_uuid UUID)
RETURNS TABLE(
    item_count INTEGER,
    has_spots BOOLEAN,
    has_accommodations BOOLEAN,
    has_restaurants BOOLEAN,
    has_attractions BOOLEAN,
    earliest_date DATE,
    latest_date DATE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as item_count,
        COUNT(*) FILTER (WHERE type = 'spot') > 0 as has_spots,
        COUNT(*) FILTER (WHERE type = 'accommodation') > 0 as has_accommodations,
        COUNT(*) FILTER (WHERE type = 'restaurant') > 0 as has_restaurants,
        COUNT(*) FILTER (WHERE type = 'attraction') > 0 as has_attractions,
        MIN(scheduled_date) as earliest_date,
        MAX(scheduled_date) as latest_date
    FROM plan_items 
    WHERE plan_id = plan_uuid;
END;
$$ LANGUAGE plpgsql;

-- Sample POI data structure for reference (stored in poi_data JSONB column)
-- {
--   "name": "Hotel Roma",
--   "address": "Via del Corso 123, Rome, Italy",
--   "coordinate": {"latitude": 41.9028, "longitude": 12.4964},
--   "category": "accommodation",
--   "phone_number": "+39 06 1234567",
--   "website": "https://hotelroma.com",
--   "map_item_identifier": "MKMapItem_identifier_string",
--   "business_hours": {
--     "monday": {"open": "00:00", "close": "23:59"},
--     "tuesday": {"open": "00:00", "close": "23:59"}
--   },
--   "amenities": ["wifi", "parking", "breakfast"],
--   "rating": 4.2,
--   "price_range": "$$"
-- }