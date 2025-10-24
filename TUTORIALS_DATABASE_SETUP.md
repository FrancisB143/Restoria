# Tutorials Database Setup Guide for Supabase

## 📋 Overview
This guide will help you create a complete database structure for storing user-uploaded tutorials in Supabase, including video/image storage.

---

## 🗄️ Step 1: Create Tutorials Table

### Run this SQL in Supabase SQL Editor:

```sql
-- Create tutorials table
CREATE TABLE IF NOT EXISTS public.tutorials (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  e_waste_type TEXT NOT NULL,
  video_url TEXT,
  image_url TEXT,
  like_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX idx_tutorials_user_id ON public.tutorials(user_id);
CREATE INDEX idx_tutorials_created_at ON public.tutorials(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.tutorials ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can view all tutorials
CREATE POLICY "Anyone can view tutorials"
  ON public.tutorials FOR SELECT
  USING (true);

-- Policy: Authenticated users can insert their own tutorials
CREATE POLICY "Users can insert own tutorials"
  ON public.tutorials FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own tutorials
CREATE POLICY "Users can update own tutorials"
  ON public.tutorials FOR UPDATE
  USING (auth.uid() = user_id);

-- Policy: Users can delete their own tutorials
CREATE POLICY "Users can delete own tutorials"
  ON public.tutorials FOR DELETE
  USING (auth.uid() = user_id);
```

---

## 📁 Step 2: Create Storage Buckets for Media Files

### A. Create Tutorial Videos Bucket

1. In Supabase Dashboard, go to **Storage**
2. Click **"New bucket"**
3. Name: `tutorial-videos`
4. Set to **Public** (so videos can be viewed by everyone)
5. Click **Create bucket**

### B. Create Tutorial Images Bucket

1. Click **"New bucket"** again
2. Name: `tutorial-images`
3. Set to **Public**
4. Click **Create bucket**

### C. Set Storage Policies

Run this SQL to allow users to upload their own files:

```sql
-- Policy: Users can upload their own tutorial videos
CREATE POLICY "Users can upload own videos"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'tutorial-videos' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Policy: Anyone can view tutorial videos
CREATE POLICY "Anyone can view tutorial videos"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'tutorial-videos');

-- Policy: Users can delete their own videos
CREATE POLICY "Users can delete own videos"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'tutorial-videos' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Same policies for images
CREATE POLICY "Users can upload own images"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'tutorial-images' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Anyone can view tutorial images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'tutorial-images');

CREATE POLICY "Users can delete own images"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'tutorial-images' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );
```

---

## 🔗 Step 3: Create View to Join Tutorials with User Profiles

This makes it easier to get tutorial data with creator information:

```sql
-- Create a view that joins tutorials with user profiles
CREATE OR REPLACE VIEW public.tutorials_with_profiles AS
SELECT 
  t.id,
  t.user_id,
  t.title,
  t.description,
  t.e_waste_type,
  t.video_url,
  t.image_url,
  t.like_count,
  t.created_at,
  t.updated_at,
  p.name as creator_name,
  p.email as creator_email
FROM public.tutorials t
LEFT JOIN public.profiles p ON t.user_id = p.id
ORDER BY t.created_at DESC;

-- Grant access to the view
GRANT SELECT ON public.tutorials_with_profiles TO authenticated;
GRANT SELECT ON public.tutorials_with_profiles TO anon;
```

---

## 📊 Database Structure

### Tutorials Table Schema:

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key (auto-generated) |
| `user_id` | UUID | Foreign key to auth.users (creator) |
| `title` | TEXT | Tutorial title |
| `description` | TEXT | Detailed tutorial description |
| `e_waste_type` | TEXT | Category (Electronics, Appliances, etc.) |
| `video_url` | TEXT | Full URL to video in storage bucket |
| `image_url` | TEXT | Full URL to thumbnail in storage bucket |
| `like_count` | INTEGER | Number of likes (default 0) |
| `created_at` | TIMESTAMPTZ | Timestamp when created |
| `updated_at` | TIMESTAMPTZ | Timestamp when last updated |

### Storage Structure:

```
tutorial-videos/
  └── {user_id}/
      ├── {tutorial_id}_video.mp4
      └── ...

tutorial-images/
  └── {user_id}/
      ├── {tutorial_id}_thumbnail.jpg
      └── ...
```

---

## 🧪 Test Your Setup

Run these queries to verify everything works:

```sql
-- Check if tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('tutorials', 'profiles');

-- Check if storage buckets exist
SELECT * FROM storage.buckets 
WHERE name IN ('tutorial-videos', 'tutorial-images');

-- Check RLS policies
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE tablename = 'tutorials';

-- Test view
SELECT * FROM public.tutorials_with_profiles LIMIT 1;
```

---

## 🔐 Security Notes

1. **RLS Enabled:** Row Level Security ensures users can only modify their own tutorials
2. **Public Viewing:** Anyone can view tutorials (good for a community platform)
3. **Authenticated Uploads:** Only logged-in users can create tutorials
4. **Storage Isolation:** Files are organized by user_id to prevent conflicts

---

## 📝 Example Data

To insert a test tutorial:

```sql
INSERT INTO public.tutorials (
  user_id, 
  title, 
  description, 
  e_waste_type, 
  video_url, 
  image_url
) VALUES (
  (SELECT id FROM auth.users LIMIT 1), -- Use first user's ID
  'Test Tutorial: Plastic Bottle Lamp',
  'Learn how to make a beautiful lamp from plastic bottles',
  'Electronics',
  'https://wkayjcularwgjctoxzwt.supabase.co/storage/v1/object/public/tutorial-videos/test/sample.mp4',
  'https://wkayjcularwgjctoxzwt.supabase.co/storage/v1/object/public/tutorial-images/test/sample.jpg'
);
```

---

## ✅ Verification Checklist

Before proceeding to the Flutter integration:

- [ ] `tutorials` table created successfully
- [ ] `tutorial-videos` storage bucket created (Public)
- [ ] `tutorial-images` storage bucket created (Public)
- [ ] RLS policies applied to tutorials table
- [ ] Storage policies applied to both buckets
- [ ] View `tutorials_with_profiles` created
- [ ] Test queries run without errors

---

## 🚀 Next Steps

After completing this setup:

1. The Flutter app will be updated to:
   - Upload videos/images to Supabase Storage
   - Save tutorial metadata to the `tutorials` table
   - Fetch tutorials from the database instead of hardcoded data
   - Allow users to edit/delete their own tutorials

2. Features you'll have:
   - ✅ User-uploaded tutorial videos
   - ✅ Thumbnail images
   - ✅ Real-time tutorial feed
   - ✅ Automatic creator attribution
   - ✅ Secure file storage
   - ✅ Like counts and engagement tracking

---

## 🆘 Troubleshooting

### Error: "permission denied for table tutorials"
- Make sure RLS policies are created
- Check that you're authenticated when testing

### Error: "bucket does not exist"
- Verify bucket names match exactly: `tutorial-videos` and `tutorial-images`
- Check that buckets are set to Public

### Videos not loading
- Verify the video URL format is correct
- Check that storage policies allow public SELECT
- Ensure the file was uploaded successfully

### Can't upload files
- Check INSERT policies on storage.objects
- Verify user is authenticated
- Ensure user_id matches the folder structure
