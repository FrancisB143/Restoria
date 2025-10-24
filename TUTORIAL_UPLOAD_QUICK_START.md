# 🚀 Tutorial Upload System - Quick Start Guide

## ✅ What's Been Done

### 1. **Updated Tutorial Model**
- Added database fields (id, userId, createdAt, updatedAt)
- Added `fromJson()` factory for Supabase data parsing
- Added `toJson()` method for database inserts

### 2. **Completely Redesigned Upload Screen**
- Video picker from gallery (max 10 minutes)
- Image thumbnail picker
- File upload to Supabase Storage
- Progress indicators during upload
- Database insertion with all metadata
- User-friendly UI with validation

### 3. **Dynamic Tutorial Loading**
- Fetches tutorials from Supabase database
- Joins with profiles table to get creator names
- Falls back to sample data if database fails
- Auto-refreshes on new uploads

---

## 📋 Setup Steps (Do These In Order!)

### Step 1: Create Database Tables

1. Open Supabase Dashboard: https://wkayjcularwgjctoxzwt.supabase.co
2. Go to **SQL Editor**
3. Click **New Query**
4. Copy and paste this SQL:

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

-- Create indexes
CREATE INDEX idx_tutorials_user_id ON public.tutorials(user_id);
CREATE INDEX idx_tutorials_created_at ON public.tutorials(created_at DESC);

-- Enable RLS
ALTER TABLE public.tutorials ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Anyone can view tutorials"
  ON public.tutorials FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own tutorials"
  ON public.tutorials FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own tutorials"
  ON public.tutorials FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own tutorials"
  ON public.tutorials FOR DELETE
  USING (auth.uid() = user_id);
```

5. Click **Run** (or press F5)

### Step 2: Create Storage Buckets

#### A. Create Video Bucket
1. In Supabase Dashboard, go to **Storage**
2. Click **New bucket**
3. Name: `tutorial-videos`
4. Toggle **Public bucket** to **ON**
5. Click **Create bucket**

#### B. Create Image Bucket
1. Click **New bucket** again
2. Name: `tutorial-images`
3. Toggle **Public bucket** to **ON**
4. Click **Create bucket**

#### C. Set Storage Policies

Go back to **SQL Editor** and run:

```sql
-- Video upload policies
CREATE POLICY "Users can upload own videos"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'tutorial-videos' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Anyone can view tutorial videos"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'tutorial-videos');

CREATE POLICY "Users can delete own videos"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'tutorial-videos' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Image upload policies
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

### Step 3: Restart Your App

```powershell
flutter run
```

---

## 🎬 How to Upload a Tutorial

1. **Login** to your account
2. Go to **Tutorials/Learn** tab
3. Click the **"+"** button
4. Fill in the form:
   - **Title**: Give your tutorial a catchy name
   - **Category**: Select e-waste type (Electronics, Appliances, etc.)
   - **Description**: Write detailed step-by-step instructions
   - **Video**: Click "Select Video" and choose from gallery
   - **Thumbnail**: Click "Select Thumbnail" and choose an image
5. Click **Upload Tutorial**
6. Wait for upload to complete (progress indicator shows)
7. Tutorial appears in the feed!

---

## 📱 Features

### For Users:
- ✅ Upload videos from gallery (MP4, MOV, etc.)
- ✅ Add custom thumbnails
- ✅ Rich text descriptions
- ✅ Category organization
- ✅ Automatic creator attribution
- ✅ Real-time feed updates

### Technical Features:
- ✅ Supabase Storage integration
- ✅ Automatic file path generation (user_id/timestamp_filename)
- ✅ Public URL generation for videos/images
- ✅ Database transaction handling
- ✅ Error handling with user feedback
- ✅ Loading states during upload
- ✅ Row Level Security for data protection

---

## 🗄️ Database Structure

### Tutorials Table:
```
┌─────────────┬──────────┬─────────────────────────────┐
│ Column      │ Type     │ Description                 │
├─────────────┼──────────┼─────────────────────────────┤
│ id          │ UUID     │ Primary key (auto)          │
│ user_id     │ UUID     │ FK to auth.users            │
│ title       │ TEXT     │ Tutorial title              │
│ description │ TEXT     │ Step-by-step instructions   │
│ e_waste_type│ TEXT     │ Category                    │
│ video_url   │ TEXT     │ Full Supabase Storage URL   │
│ image_url   │ TEXT     │ Thumbnail URL               │
│ like_count  │ INTEGER  │ Number of likes             │
│ created_at  │ TIMESTAMP│ When created                │
│ updated_at  │ TIMESTAMP│ Last modified               │
└─────────────┴──────────┴─────────────────────────────┘
```

### Storage Structure:
```
tutorial-videos/
  └── {user_id}/
      └── {timestamp}_{original_filename}.mp4

tutorial-images/
  └── {user_id}/
      └── {timestamp}_{original_filename}.jpg
```

---

## 🧪 Testing Checklist

Before using in production:

- [ ] Can create buckets successfully
- [ ] Can upload video to tutorial-videos bucket
- [ ] Can upload image to tutorial-images bucket
- [ ] Can view uploaded files in Storage dashboard
- [ ] Tutorial appears in feed after upload
- [ ] Video plays correctly in tutorial detail screen
- [ ] Thumbnail displays in tutorial list
- [ ] Creator name shows correctly
- [ ] Only tutorial owner can edit/delete (when implemented)

---

## 🐛 Troubleshooting

### "Failed to upload file: 403"
- Check storage policies are created
- Verify buckets are set to Public
- Ensure user is authenticated

### "Failed to create tutorial: permission denied"
- Check RLS policies on tutorials table
- Verify user_id matches authenticated user
- Check that INSERT policy exists

### Video not playing
- Verify video URL is correct in database
- Check file was uploaded successfully in Storage
- Ensure video format is supported (MP4 recommended)

### "Bucket does not exist"
- Bucket names must be exactly: `tutorial-videos` and `tutorial-images`
- Check for typos in bucket creation
- Verify buckets are created in the correct project

### Large file upload fails
- Check your Supabase plan's storage limits
- Consider compressing videos before upload
- Break into smaller chunks if needed

---

## 📊 Example Data

### Test Tutorial Entry:
```sql
INSERT INTO public.tutorials (
  user_id,
  title,
  description,
  e_waste_type,
  video_url,
  image_url
) VALUES (
  auth.uid(),  -- Current user's ID
  'Plastic Bottle Plant Pot',
  'Transform old plastic bottles into beautiful hanging plant pots!',
  'Other',
  'https://wkayjcularwgjctoxzwt.supabase.co/storage/v1/object/public/tutorial-videos/{user_id}/test_video.mp4',
  'https://wkayjcularwgjctoxzwt.supabase.co/storage/v1/object/public/tutorial-images/{user_id}/test_image.jpg'
);
```

---

## 🔒 Security Features

1. **Row Level Security (RLS)**
   - Users can only modify their own tutorials
   - Everyone can view all tutorials (community platform)

2. **Storage Isolation**
   - Files organized by user_id
   - Users can only upload to their own folders
   - Users can only delete their own files

3. **Authentication Required**
   - Must be logged in to upload
   - User ID automatically captured from session

---

## 🚀 Next Steps (Future Enhancements)

- [ ] Add video compression before upload
- [ ] Add progress bar for large uploads
- [ ] Allow editing existing tutorials
- [ ] Add delete tutorial functionality
- [ ] Implement like/favorite system
- [ ] Add tutorial search and filtering
- [ ] Add comments system
- [ ] Add video preview before upload
- [ ] Support YouTube video links as alternative
- [ ] Add tutorial drafts feature

---

## 📝 Important Notes

1. **Video Size Limits:**
   - Free Supabase plan: 500MB per file
   - Consider compressing large videos

2. **Storage Costs:**
   - Free: 1GB total storage
   - Monitor usage in Supabase Dashboard

3. **Public Buckets:**
   - Videos and images are publicly accessible
   - Anyone with the URL can view them
   - Good for a community sharing platform

4. **File Organization:**
   - Files automatically organized by user_id
   - Prevents naming conflicts
   - Easy to track user uploads

---

## ✅ Verification Commands

Run these in Supabase SQL Editor to verify setup:

```sql
-- Check tutorials table
SELECT * FROM public.tutorials ORDER BY created_at DESC LIMIT 5;

-- Check storage buckets
SELECT * FROM storage.buckets WHERE name IN ('tutorial-videos', 'tutorial-images');

-- Check RLS policies
SELECT * FROM pg_policies WHERE tablename = 'tutorials';

-- Check storage policies
SELECT * FROM storage.policies;

-- Count tutorials by user
SELECT user_id, COUNT(*) as tutorial_count 
FROM public.tutorials 
GROUP BY user_id;
```

---

## 🎉 You're All Set!

Your tutorial upload system is now fully functional with:
- ✅ Video uploads to cloud storage
- ✅ Thumbnail image uploads
- ✅ Database integration
- ✅ User authentication
- ✅ Secure file management
- ✅ Real-time feed updates

Start uploading tutorials and building your e-waste upcycling community! 🌍♻️
