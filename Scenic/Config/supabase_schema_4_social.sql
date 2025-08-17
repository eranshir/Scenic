-- Phase 4: Social Features (Comments, Votes, Plans)
-- Run this after Phase 3

-- Comments table
CREATE TABLE IF NOT EXISTS public.comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spot_id UUID REFERENCES spots(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(id),
    parent_id UUID REFERENCES comments(id), -- For replies
    
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    upvote_count INTEGER DEFAULT 0,
    is_pinned BOOLEAN DEFAULT false
);

CREATE INDEX IF NOT EXISTS comments_spot_idx ON comments(spot_id);
CREATE INDEX IF NOT EXISTS comments_user_idx ON comments(user_id);

-- Votes table
CREATE TABLE IF NOT EXISTS public.votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id),
    spot_id UUID REFERENCES spots(id) ON DELETE CASCADE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, spot_id)
);

-- Saves/Bookmarks table
CREATE TABLE IF NOT EXISTS public.saves (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id),
    spot_id UUID REFERENCES spots(id) ON DELETE CASCADE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, spot_id)
);

-- Plans table
CREATE TABLE IF NOT EXISTS public.plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id),
    
    title TEXT NOT NULL,
    description TEXT,
    planned_date DATE,
    
    is_public BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.plan_spots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id UUID REFERENCES plans(id) ON DELETE CASCADE,
    spot_id UUID REFERENCES spots(id),
    
    order_index INTEGER NOT NULL,
    arrival_time TIME,
    duration_minutes INTEGER,
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Activity feed
CREATE TABLE IF NOT EXISTS public.activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id),
    type TEXT NOT NULL, -- spot_created, photo_added, plan_shared, etc.
    
    spot_id UUID REFERENCES spots(id),
    plan_id UUID REFERENCES plans(id),
    target_user_id UUID REFERENCES profiles(id),
    
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS activities_user_idx ON activities(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS activities_type_idx ON activities(type);

-- Enable RLS
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE saves ENABLE ROW LEVEL SECURITY;
ALTER TABLE plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE plan_spots ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;

-- Comments policies
CREATE POLICY "Comments are viewable by everyone"
    ON comments FOR SELECT USING (true);

CREATE POLICY "Authenticated users can comment"
    ON comments FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can edit own comments"
    ON comments FOR UPDATE
    USING (auth.uid() = user_id);

-- Votes policies
CREATE POLICY "Votes are viewable by everyone"
    ON votes FOR SELECT USING (true);

CREATE POLICY "Authenticated users can vote"
    ON votes FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can remove own votes"
    ON votes FOR DELETE
    USING (auth.uid() = user_id);

-- Saves policies
CREATE POLICY "Users can view own saves"
    ON saves FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can save spots"
    ON saves FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can unsave spots"
    ON saves FOR DELETE
    USING (auth.uid() = user_id);

-- Plans policies
CREATE POLICY "Public plans viewable by everyone"
    ON plans FOR SELECT
    USING (is_public = true OR user_id = auth.uid());

CREATE POLICY "Users can create own plans"
    ON plans FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own plans"
    ON plans FOR UPDATE
    USING (auth.uid() = user_id);

-- Plan spots policies
CREATE POLICY "Plan spots viewable with plan access"
    ON plan_spots FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM plans
            WHERE plans.id = plan_spots.plan_id
            AND (plans.is_public = true OR plans.user_id = auth.uid())
        )
    );

-- Activities policies
CREATE POLICY "Activities viewable by all"
    ON activities FOR SELECT USING (true);

-- Trigger to update vote counts
CREATE OR REPLACE FUNCTION update_vote_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE spots
        SET vote_count = vote_count + 1
        WHERE id = NEW.spot_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE spots
        SET vote_count = vote_count - 1
        WHERE id = OLD.spot_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_spot_votes
AFTER INSERT OR DELETE ON votes
FOR EACH ROW
EXECUTE FUNCTION update_vote_count();

-- Trigger to update comment counts
CREATE OR REPLACE FUNCTION update_comment_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE spots
        SET comment_count = comment_count + 1
        WHERE id = NEW.spot_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE spots
        SET comment_count = comment_count - 1
        WHERE id = OLD.spot_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_spot_comments
AFTER INSERT OR DELETE ON comments
FOR EACH ROW
EXECUTE FUNCTION update_comment_count();