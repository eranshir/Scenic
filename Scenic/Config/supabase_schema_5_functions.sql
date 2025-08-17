-- Phase 5: Database Functions and Helpers
-- Run this after Phase 4

-- Function to find nearby spots
CREATE OR REPLACE FUNCTION nearby_spots(
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    radius_meters INTEGER DEFAULT 50000
)
RETURNS TABLE (
    id UUID,
    title TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    distance_meters DOUBLE PRECISION,
    difficulty INTEGER,
    subject_tags TEXT[],
    vote_count INTEGER,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.title,
        s.latitude,
        s.longitude,
        ST_Distance(
            s.location::geography,
            ST_MakePoint(lng, lat)::geography
        ) as distance_meters,
        s.difficulty,
        s.subject_tags,
        s.vote_count,
        s.created_at
    FROM spots s
    WHERE ST_DWithin(
        s.location::geography,
        ST_MakePoint(lng, lat)::geography,
        radius_meters
    )
    AND s.privacy = 'public'
    AND s.status = 'active'
    ORDER BY distance_meters ASC;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate explorer score
CREATE OR REPLACE FUNCTION calculate_explorer_score(user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    score INTEGER := 0;
    spot_count INTEGER;
    photo_count INTEGER;
    comment_count INTEGER;
    vote_count INTEGER;
BEGIN
    -- Count spots created
    SELECT COUNT(*) INTO spot_count
    FROM spots WHERE created_by = user_id;
    
    -- Count photos shared
    SELECT COUNT(*) INTO photo_count
    FROM media WHERE media.user_id = calculate_explorer_score.user_id;
    
    -- Count comments made
    SELECT COUNT(*) INTO comment_count
    FROM comments WHERE comments.user_id = calculate_explorer_score.user_id;
    
    -- Count votes given
    SELECT COUNT(*) INTO vote_count
    FROM votes WHERE votes.user_id = calculate_explorer_score.user_id;
    
    -- Calculate score
    score := (spot_count * 100) + -- 100 points per spot
             (photo_count * 10) +  -- 10 points per photo
             (comment_count * 5) + -- 5 points per comment
             (vote_count * 2);     -- 2 points per vote
    
    -- Update profile
    UPDATE profiles 
    SET 
        explorer_score = score,
        spots_created = spot_count,
        photos_shared = photo_count,
        comments_made = comment_count,
        explorer_level = CASE
            WHEN score < 100 THEN 'novice'
            WHEN score < 500 THEN 'explorer'
            WHEN score < 1000 THEN 'adventurer'
            WHEN score < 5000 THEN 'pathfinder'
            ELSE 'legend'
        END
    WHERE id = calculate_explorer_score.user_id;
    
    RETURN score;
END;
$$ LANGUAGE plpgsql;

-- Function to get spot with all details
CREATE OR REPLACE FUNCTION get_spot_details(spot_id UUID)
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'spot', row_to_json(s.*),
        'creator', row_to_json(p.*),
        'media', COALESCE(json_agg(DISTINCT m.*) FILTER (WHERE m.id IS NOT NULL), '[]'::json),
        'access_info', row_to_json(ai.*),
        'tips', COALESCE(json_agg(DISTINCT st.*) FILTER (WHERE st.id IS NOT NULL), '[]'::json),
        'recent_comments', COALESCE(json_agg(DISTINCT c.*) FILTER (WHERE c.id IS NOT NULL), '[]'::json)
    ) INTO result
    FROM spots s
    LEFT JOIN profiles p ON s.created_by = p.id
    LEFT JOIN media m ON m.spot_id = s.id
    LEFT JOIN access_info ai ON ai.spot_id = s.id
    LEFT JOIN spot_tips st ON st.spot_id = s.id
    LEFT JOIN LATERAL (
        SELECT * FROM comments
        WHERE comments.spot_id = s.id
        ORDER BY created_at DESC
        LIMIT 5
    ) c ON true
    WHERE s.id = get_spot_details.spot_id
    GROUP BY s.id, p.id, ai.id;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Function to record activity
CREATE OR REPLACE FUNCTION record_activity(
    p_user_id UUID,
    p_type TEXT,
    p_spot_id UUID DEFAULT NULL,
    p_plan_id UUID DEFAULT NULL,
    p_metadata JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    activity_id UUID;
BEGIN
    INSERT INTO activities (user_id, type, spot_id, plan_id, metadata)
    VALUES (p_user_id, p_type, p_spot_id, p_plan_id, p_metadata)
    RETURNING id INTO activity_id;
    
    RETURN activity_id;
END;
$$ LANGUAGE plpgsql;

-- View for trending spots (last 7 days)
CREATE OR REPLACE VIEW trending_spots AS
SELECT 
    s.*,
    p.username as creator_username,
    p.avatar_url as creator_avatar,
    (s.vote_count * 2 + s.comment_count * 3 + s.view_count) as trending_score
FROM spots s
JOIN profiles p ON s.created_by = p.id
WHERE s.privacy = 'public'
AND s.status = 'active'
AND s.created_at > NOW() - INTERVAL '7 days'
ORDER BY trending_score DESC
LIMIT 20;

-- View for user stats
CREATE OR REPLACE VIEW user_stats AS
SELECT 
    p.id,
    p.username,
    p.explorer_score,
    p.explorer_level,
    COUNT(DISTINCT s.id) as total_spots,
    COUNT(DISTINCT m.id) as total_photos,
    COUNT(DISTINCT pl.id) as total_plans,
    COALESCE(SUM(s.vote_count), 0) as total_votes_received
FROM profiles p
LEFT JOIN spots s ON s.created_by = p.id
LEFT JOIN media m ON m.user_id = p.id
LEFT JOIN plans pl ON pl.user_id = p.id
GROUP BY p.id, p.username, p.explorer_score, p.explorer_level;