# Supabase Storage Setup Guide for Gallery Images

## Problem
If you're getting a `StorageException` when trying to upload gallery images, it means the storage bucket doesn't exist or isn't configured properly.

## Solution: Create the Storage Bucket

### Step 1: Access Supabase Dashboard
1. Go to [https://supabase.com](https://supabase.com)
2. Sign in to your account
3. Select your project: **wkayjcularwgjctoxzwt**

### Step 2: Create Storage Bucket
1. In the left sidebar, click on **Storage**
2. Click the **"New bucket"** button
3. Configure the bucket:
   - **Name**: `gallery-images` (must be exactly this name)
   - **Public bucket**: Toggle **ON** (✓ enabled)
   - **File size limit**: 50 MB (recommended)
   - **Allowed MIME types**: Leave empty or add: `image/jpeg, image/png, image/jpg, image/gif, image/webp`
4. Click **"Create bucket"**

### Step 3: Set Bucket Policies (Public Access)
1. After creating the bucket, click on the **gallery-images** bucket
2. Click on **"Policies"** tab at the top
3. Click **"New Policy"**

#### Policy 1: Allow Public Reads (View Images)
- **Policy name**: `Public Read Access`
- **Allowed operations**: Check **SELECT**
- **Target roles**: `public` (or `anon`)
- **USING expression**: `true`
- Click **"Save policy"**

Or use this SQL in the SQL Editor:
```sql
CREATE POLICY "Public Read Access"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'gallery-images');
```

#### Policy 2: Allow Authenticated Users to Upload
- **Policy name**: `Authenticated Upload`
- **Allowed operations**: Check **INSERT**
- **Target roles**: `authenticated`
- **WITH CHECK expression**: `true`
- Click **"Save policy"**

Or use this SQL:
```sql
CREATE POLICY "Authenticated Upload"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'gallery-images');
```

#### Policy 3: Allow Users to Update Their Own Files
```sql
CREATE POLICY "Users can update own files"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'gallery-images' AND auth.uid()::text = (storage.foldername(name))[1])
WITH CHECK (bucket_id = 'gallery-images' AND auth.uid()::text = (storage.foldername(name))[1]);
```

#### Policy 4: Allow Users to Delete Their Own Files
```sql
CREATE POLICY "Users can delete own files"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'gallery-images' AND auth.uid()::text = (storage.foldername(name))[1]);
```

### Step 4: Verify Setup
1. Go back to **Storage** → **gallery-images**
2. You should see an empty bucket
3. The bucket should show **"Public"** badge

### Step 5: Test the Upload
1. Run your Flutter app
2. Navigate to the Gallery screen
3. Click **"New Project"** or **"Start Creating"**
4. Select an image and add a description
5. Click **"Confirm"**
6. The image should upload successfully!

## Quick SQL Setup (All Policies at Once)

If you prefer, run this in the Supabase SQL Editor:

```sql
-- Enable public read access
CREATE POLICY "Public Read Access"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'gallery-images');

-- Enable authenticated users to upload
CREATE POLICY "Authenticated Upload"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'gallery-images');

-- Allow users to update their own files
CREATE POLICY "Users can update own files"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'gallery-images' AND auth.uid()::text = (storage.foldername(name))[1])
WITH CHECK (bucket_id = 'gallery-images' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Allow users to delete their own files
CREATE POLICY "Users can delete own files"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'gallery-images' AND auth.uid()::text = (storage.foldername(name))[1]);
```

## Troubleshooting

### Still Getting Errors?

1. **Check bucket name**: Must be exactly `gallery-images` (lowercase, with hyphen)
2. **Verify public access**: The bucket should show a "Public" badge
3. **Check policies**: Make sure at least the "Public Read Access" and "Authenticated Upload" policies exist
4. **Check authentication**: Make sure you're logged in (user should not be null)
5. **Check internet connection**: The upload requires internet access
6. **Check file size**: Images are compressed to 85% quality with max 1920x1080 resolution
7. **Check Supabase project URL**: Verify it matches in `lib/config/supabase_config.dart`

### View Detailed Error
The app now shows a "Details" button on the error message. Click it to see the full error details.

## File Structure in Storage
Images will be organized by user ID:
```
gallery-images/
  ├── user-id-1/
  │   ├── 1234567890_image1.jpg
  │   └── 1234567891_image2.png
  ├── user-id-2/
  │   └── 1234567892_photo.jpg
  ...
```

This keeps files organized and makes it easy to manage permissions per user.
