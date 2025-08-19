-- Plans Feature Migration: Update from Simple to Comprehensive Plans
-- This migrates the existing basic plans table to the new comprehensive structure

-- Step 1: Backup existing tables by renaming them
ALTER TABLE IF EXISTS plans RENAME TO plans_old;
ALTER TABLE IF EXISTS plan_spots RENAME TO plan_spots_old;

-- Step 2: Create enum types for the new structure
CREATE TYPE plan_item_type AS ENUM ('spot', 'accommodation', 'restaurant', 'attraction');
CREATE TYPE timing_preference AS ENUM ('sunrise', 'sunset', 'golden_hour', 'blue_hour', 'flexible');

-- Step 3: Create new comprehensive plans table
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

-- Step 4: Create new comprehensive plan_items table
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

-- Step 5: Migrate existing data from old tables to new structure
INSERT INTO plans (
    id, 
    title, 
    description, 
    created_by, 
    created_at, 
    updated_at, 
    is_public,
    start_date
)
SELECT 
    p.id,
    p.title,
    p.description,
    p.user_id, -- Map user_id to created_by
    p.created_at,
    p.updated_at,
    p.is_public,
    p.planned_date -- Map planned_date to start_date
FROM plans_old p;

-- Step 6: Migrate plan spots to plan items
INSERT INTO plan_items (
    id,
    plan_id,
    type,
    order_index,
    spot_id,
    notes,
    created_at,
    scheduled_start_time
)
SELECT 
    ps.id,
    ps.plan_id,
    'spot'::plan_item_type, -- All existing items are spots
    ps.order_index,
    ps.spot_id,
    ps.notes,
    ps.created_at,
    -- Convert arrival_time to full timestamp using plan's start_date
    CASE 
        WHEN ps.arrival_time IS NOT NULL AND p.start_date IS NOT NULL 
        THEN (p.start_date + ps.arrival_time)::TIMESTAMPTZ
        ELSE NULL
    END
FROM plan_spots_old ps
JOIN plans p ON p.id = ps.plan_id;

-- Step 7: Create indexes for performance
CREATE INDEX idx_plans_created_by ON plans(created_by);
CREATE INDEX idx_plans_is_public ON plans(is_public);
CREATE INDEX idx_plans_created_at ON plans(created_at DESC);
CREATE INDEX idx_plan_items_plan_id ON plan_items(plan_id);
CREATE INDEX idx_plan_items_order ON plan_items(plan_id, order_index);
CREATE INDEX idx_plan_items_scheduled_date ON plan_items(scheduled_date);
CREATE INDEX idx_plan_items_type ON plan_items(type);

-- Step 8: Enable Row Level Security (RLS)
ALTER TABLE plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE plan_items ENABLE ROW LEVEL SECURITY;

-- Step 9: Create RLS policies for plans
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

-- Step 10: Create RLS policies for plan_items
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

-- Step 11: Create trigger for updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_plans_updated_at BEFORE UPDATE ON plans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Step 12: Create helper function for plan statistics
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

-- Step 13: Update activities table to reference new plans structure (if it exists)
-- Fix foreign key constraint to point to new plans table
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'activities') THEN
        -- Drop existing foreign key constraint
        ALTER TABLE activities DROP CONSTRAINT IF EXISTS activities_plan_id_fkey;
        
        -- Add new foreign key constraint
        ALTER TABLE activities ADD CONSTRAINT activities_plan_id_fkey 
            FOREIGN KEY (plan_id) REFERENCES plans(id);
    END IF;
END $$;

-- Step 14: Verification queries (comment these out after running)
-- SELECT 'Migration Summary:' as status;
-- SELECT COUNT(*) as old_plans_count FROM plans_old;
-- SELECT COUNT(*) as new_plans_count FROM plans;
-- SELECT COUNT(*) as old_plan_spots_count FROM plan_spots_old;
-- SELECT COUNT(*) as new_plan_items_count FROM plan_items;

-- Step 15: Cleanup (OPTIONAL - only run after verifying migration worked)
-- UNCOMMENT THESE LINES ONLY AFTER VERIFYING THE MIGRATION WAS SUCCESSFUL:
-- DROP TABLE IF EXISTS plans_old;
-- DROP TABLE IF EXISTS plan_spots_old;

-- Sample POI data structure for reference (stored in poi_data JSONB column):
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