-- Fix for Flickr placeholder accounts
-- This removes the foreign key constraint temporarily to allow placeholder profiles

-- Check current constraint
SELECT 
    conname,
    pg_get_constraintdef(c.oid) AS constraint_def
FROM pg_constraint c
JOIN pg_namespace n ON n.oid = c.connamespace
WHERE c.conrelid = 'public.profiles'::regclass
AND c.contype = 'f';

-- Drop the foreign key constraint to auth.users
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_id_fkey;

-- Recreate the constraint as optional (allow NULLs for placeholder accounts)
-- Note: We'll need to make the id column nullable first if it isn't
ALTER TABLE profiles ALTER COLUMN id DROP NOT NULL;

-- Add a new constraint that allows NULLs
ALTER TABLE profiles ADD CONSTRAINT profiles_id_fkey 
    FOREIGN KEY (id) REFERENCES auth.users(id) 
    ON DELETE SET NULL;

-- Update the create_flickr_placeholder function to handle this
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
    -- Generate a new UUID for the placeholder user (won't be in auth.users)
    new_user_id := gen_random_uuid();
    
    -- Generate unique username
    generated_username := generate_flickr_username(flickr_username_param);
    
    -- Insert the placeholder profile with NULL id (no auth user)
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
        NULL,  -- No auth user for placeholders
        generated_username,
        COALESCE(display_name_param, flickr_username_param),
        'flickr_placeholder',
        flickr_user_id_param,
        flickr_username_param,
        true,
        'flickr_import',
        NOW(),
        NOW()
    )
    RETURNING id INTO new_user_id;
    
    RETURN new_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;