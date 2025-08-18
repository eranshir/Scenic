-- Phase 6: Attribution System for Flickr Import
-- Run this after existing schema phases

-- =====================================================
-- PROFILES TABLE EXTENSIONS FOR FLICKR ACCOUNTS
-- =====================================================

-- Add Flickr account support to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS account_type TEXT DEFAULT 'user';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS flickr_user_id TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS flickr_username TEXT;  
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS claimable BOOLEAN DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS original_source TEXT DEFAULT 'user_signup';

-- Create index for Flickr lookups
CREATE INDEX IF NOT EXISTS profiles_flickr_user_id_idx ON profiles(flickr_user_id);
CREATE INDEX IF NOT EXISTS profiles_account_type_idx ON profiles(account_type);

-- Add constraint for account types
ALTER TABLE profiles ADD CONSTRAINT profiles_account_type_check 
    CHECK (account_type IN ('user', 'flickr_placeholder', 'claimed'));

-- Add constraint for original sources
ALTER TABLE profiles ADD CONSTRAINT profiles_original_source_check 
    CHECK (original_source IN ('user_signup', 'flickr_import', 'google_oauth', 'apple_signin'));

-- =====================================================
-- MEDIA TABLE EXTENSIONS FOR ATTRIBUTION
-- =====================================================

-- Add attribution fields to media table
ALTER TABLE media ADD COLUMN IF NOT EXISTS attribution_text TEXT;
ALTER TABLE media ADD COLUMN IF NOT EXISTS original_source TEXT DEFAULT 'user_upload';
ALTER TABLE media ADD COLUMN IF NOT EXISTS original_photo_id TEXT;
ALTER TABLE media ADD COLUMN IF NOT EXISTS license_type TEXT DEFAULT 'All Rights Reserved';

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS media_original_photo_id_idx ON media(original_photo_id);
CREATE INDEX IF NOT EXISTS media_original_source_idx ON media(original_source);
CREATE INDEX IF NOT EXISTS media_attribution_text_idx ON media(attribution_text);

-- Add constraint for media sources
ALTER TABLE media ADD CONSTRAINT media_original_source_check 
    CHECK (original_source IN ('user_upload', 'flickr', 'instagram', 'other'));

-- Add constraint for license types
ALTER TABLE media ADD CONSTRAINT media_license_type_check 
    CHECK (license_type IN ('All Rights Reserved', 'CC-BY', 'CC-BY-SA', 'CC-BY-NC', 'CC-BY-NC-SA', 'CC0', 'CC (See Flickr)'));

-- =====================================================
-- UPDATE RLS POLICIES FOR NEW FIELDS
-- =====================================================

-- Update media policies to handle attribution
DROP POLICY IF EXISTS "Media viewable with spot access" ON media;
CREATE POLICY "Media viewable with spot access"
    ON media FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM spots
            WHERE spots.id = media.spot_id
            AND (spots.privacy = 'public' OR spots.created_by = auth.uid())
        )
    );

-- Ensure Flickr placeholder accounts are viewable
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
CREATE POLICY "Public profiles are viewable by everyone"
    ON profiles FOR SELECT
    USING (true);

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Function to generate unique Flickr usernames
CREATE OR REPLACE FUNCTION generate_flickr_username(flickr_username TEXT)
RETURNS TEXT AS $$
DECLARE
    base_username TEXT;
    final_username TEXT;
    counter INTEGER := 1;
BEGIN
    -- Clean the flickr username and add prefix
    base_username := 'flickr_' || regexp_replace(lower(flickr_username), '[^a-z0-9_]', '', 'g');
    final_username := base_username;
    
    -- Check for existing usernames and increment if needed
    WHILE EXISTS (SELECT 1 FROM profiles WHERE username = final_username) LOOP
        final_username := base_username || '_' || counter;
        counter := counter + 1;
    END LOOP;
    
    RETURN final_username;
END;
$$ LANGUAGE plpgsql;

-- Function to create Flickr placeholder account
CREATE OR REPLACE FUNCTION create_flickr_placeholder(
    flickr_user_id_param TEXT,
    flickr_username_param TEXT,
    display_name_param TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    new_user_id UUID;
    generated_username TEXT;
BEGIN
    -- Generate a new UUID for the placeholder user
    new_user_id := gen_random_uuid();
    
    -- Generate unique username
    generated_username := generate_flickr_username(flickr_username_param);
    
    -- Insert the placeholder profile
    INSERT INTO profiles (
        id,
        username,
        display_name,
        account_type,
        flickr_user_id,
        flickr_username,
        claimable,
        original_source,
        created_at,
        updated_at
    ) VALUES (
        new_user_id,
        generated_username,
        COALESCE(display_name_param, flickr_username_param),
        'flickr_placeholder',
        flickr_user_id_param,
        flickr_username_param,
        true,
        'flickr_import',
        NOW(),
        NOW()
    );
    
    RETURN new_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- MIGRATION VERIFICATION
-- =====================================================

-- Verify schema changes
DO $$
BEGIN
    -- Check if all columns were added
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'account_type') THEN
        RAISE EXCEPTION 'Failed to add account_type column to profiles table';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'media' AND column_name = 'attribution_text') THEN
        RAISE EXCEPTION 'Failed to add attribution_text column to media table';
    END IF;
    
    RAISE NOTICE 'Attribution schema migration completed successfully!';
END $$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION generate_flickr_username(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION create_flickr_placeholder(TEXT, TEXT, TEXT) TO service_role;