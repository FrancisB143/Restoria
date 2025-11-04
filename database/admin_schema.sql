-- Add admin column to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;

-- Create an example admin user (replace the email with your actual admin email)
-- First, you need to find your user ID from the auth.users table
-- Run this query first to get your user ID:
-- SELECT id, email FROM auth.users WHERE email = 'your-admin-email@example.com';

-- Then update that user to be an admin:
-- UPDATE profiles SET is_admin = true WHERE email = 'your-admin-email@example.com';

-- Example: If you want to make a specific user an admin by their ID:
-- UPDATE profiles SET is_admin = true WHERE id = 'USER_UUID_HERE';

-- Create admin_actions table to log admin activities
CREATE TABLE IF NOT EXISTS admin_actions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  admin_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  action_type TEXT NOT NULL, -- 'delete_tutorial', 'delete_gallery_post', etc.
  target_id UUID, -- ID of the deleted item
  target_type TEXT, -- 'tutorial', 'gallery_post'
  target_title TEXT, -- Title/description of deleted content
  target_creator TEXT, -- Username of content creator
  target_image_url TEXT, -- Thumbnail/image URL of deleted content
  reason TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on admin_actions
ALTER TABLE admin_actions ENABLE ROW LEVEL SECURITY;

-- Only admins can view admin actions
CREATE POLICY "Admins can view all admin actions" 
  ON admin_actions FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.is_admin = true
    )
  );

-- Only admins can insert admin actions
CREATE POLICY "Admins can insert admin actions" 
  ON admin_actions FOR INSERT 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.is_admin = true
    )
  );

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_admin_actions_admin_id ON admin_actions(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_actions_created_at ON admin_actions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_is_admin ON profiles(is_admin) WHERE is_admin = true;

-- Function to check if user is admin
CREATE OR REPLACE FUNCTION is_user_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() 
    AND is_admin = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
