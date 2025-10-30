# Profile Avatars Storage Setup Guide for Supabase

## 📋 Overview
This guide will help you create a storage bucket for user profile avatars in Supabase.

## ⚠️ Important Note
**If you don't set up the storage bucket, the edit profile feature will still work!** Users can update their name and bio, but avatar upload will be disabled. A dialog will warn users that avatar upload is not available.

---

## 📁 Quick Setup (Recommended)

### Option 1: Manual Setup via Dashboard (Easiest)

1. Go to your Supabase Dashboard
2. Click **Storage** in the sidebar
3. Click **"New bucket"**
4. Enter name: `profile-avatars`
5. Make it **Public** ✅
6. Click **Create bucket**
7. Done! The app will now allow avatar uploads.

---

## 📁 Option 2: Complete Setup with SQL (Advanced)

### Step 1: Create the Bucket

In Supabase Dashboard → Storage → New bucket:
- Name: `profile-avatars`
- Public: ✅ Yes
- Click Create

### Step 2: Set Storage Policies

Run this SQL in Supabase SQL Editor:

```sql
-- Policy: Users can upload their own avatars
CREATE POLICY "Users can upload own avatars"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'profile-avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Policy: Anyone can view profile avatars
CREATE POLICY "Anyone can view profile avatars"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'profile-avatars');

-- Policy: Users can update their own avatars
CREATE POLICY "Users can update own avatars"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'profile-avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Policy: Users can delete their own avatars
CREATE POLICY "Users can delete own avatars"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'profile-avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );
```

---

## 📊 Step 3: Add Bio Field to Profiles Table (If Not Already Done)

```sql
-- Add bio column to profiles table if it doesn't exist
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS bio TEXT;

-- Update existing profiles with a default bio
UPDATE public.profiles 
SET bio = 'Turning e-waste into e-wonderful! ♻️✨ Creator and seller of unique upcycled art.'
WHERE bio IS NULL;
```

---

## 📂 Storage Structure

The avatars will be organized like this:

```
profile-avatars/
  └── avatars/
      ├── {user_id}_{timestamp}.jpg
      ├── {user_id}_{timestamp}.jpg
      └── ...
```

Each user's avatars are stored with their user ID prefix for easy identification and security.

---

## 🔍 Useful Queries

### Get a user's avatar URL:
```sql
SELECT avatar_url 
FROM public.profiles 
WHERE id = '{user_id}';
```

### Update a user's profile:
```sql
UPDATE public.profiles 
SET 
  name = 'New Name',
  bio = 'New bio text',
  avatar_url = 'https://your-project.supabase.co/storage/v1/object/public/profile-avatars/avatars/filename.jpg',
  updated_at = NOW()
WHERE id = '{user_id}';
```

### List all avatars in storage:
```sql
SELECT name, created_at 
FROM storage.objects 
WHERE bucket_id = 'profile-avatars' 
ORDER BY created_at DESC;
```

---

## 🧪 Test Your Setup

Run these queries to verify everything works:

```sql
-- Check if bucket exists
SELECT * FROM storage.buckets 
WHERE name = 'profile-avatars';

-- Check storage policies
SELECT policyname, cmd 
FROM pg_policies 
WHERE schemaname = 'storage' 
  AND tablename = 'objects'
  AND policyname LIKE '%avatar%';

-- Check if bio field exists in profiles
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'profiles' 
  AND column_name = 'bio';
```

---

## 🔐 Security Features

1. **User-Specific Upload:** Users can only upload avatars to their own folder
2. **Public Viewing:** Anyone can view avatars (needed for profile display)
3. **Ownership-Based Deletion:** Users can only delete their own avatars
4. **File Organization:** Avatars organized by user ID prefix for security

---

## 💾 Profiles Table Schema Update

After adding the bio field, your profiles table should have:

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key (references auth.users) |
| `name` | TEXT | User's display name |
| `email` | TEXT | User's email |
| `avatar_url` | TEXT | Full URL to avatar in storage bucket |
| `bio` | TEXT | User's biography/description |
| `created_at` | TIMESTAMPTZ | When profile was created |
| `updated_at` | TIMESTAMPTZ | When profile was last updated |

---

## ✅ Verification Checklist

Before using the edit profile feature:

- [ ] `profile-avatars` storage bucket created (Public)
- [ ] Storage policies applied to allow uploads/updates/deletes
- [ ] `bio` field added to `profiles` table
- [ ] Test queries run without errors
- [ ] Can view storage bucket in Supabase dashboard

---

## 🚀 Features Now Available

After completing this setup:

✅ **Avatar Upload**
- Users can select and upload profile pictures from gallery
- Supports both web and mobile platforms
- Automatic image optimization (max 1024x1024, 85% quality)

✅ **Profile Editing**
- Update display name
- Change profile bio (10-200 characters)
- Upload new profile picture
- Real-time preview of changes

✅ **Data Validation**
- Name validation (minimum 2 characters)
- Bio validation (minimum 10 characters, maximum 200)
- Form validation before submission

✅ **User Experience**
- Unsaved changes warning dialog
- Loading states during upload
- Success/error feedback messages
- Cancel functionality

---

## 🆘 Troubleshooting

### Error: "permission denied for storage.objects"
- Make sure storage policies are created
- Check that you're authenticated when uploading
- Verify bucket name is `profile-avatars`

### Error: "bucket does not exist"
- Verify bucket name matches exactly: `profile-avatars`
- Check that bucket is set to Public
- Ensure bucket was created successfully

### Avatar not displaying
- Verify the avatar URL format is correct
- Check that storage policies allow public SELECT
- Ensure the file was uploaded successfully
- Check browser console for CORS errors

### Can't upload files
- Check INSERT policy on storage.objects
- Verify user is authenticated
- Ensure file size is within limits (should be optimized to ~1MB)
- Check that image picker has necessary permissions

### Bio field error
- Run the ALTER TABLE command to add the bio field
- Check if migrations ran successfully
- Verify field exists with information_schema query

---

## 📝 Example Usage

### Upload Avatar (Handled by App):
```dart
final file = File('/path/to/image.jpg');
final userId = user.id;
final filePath = 'avatars/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

await supabase.storage
  .from('profile-avatars')
  .upload(filePath, file);

final publicUrl = supabase.storage
  .from('profile-avatars')
  .getPublicUrl(filePath);
```

### Update Profile (Handled by App):
```dart
await supabase.from('profiles').update({
  'name': 'New Name',
  'bio': 'New bio',
  'avatar_url': publicUrl,
  'updated_at': DateTime.now().toIso8601String(),
}).eq('id', userId);
```

---

## 🎨 Best Practices

1. **Image Optimization:** App automatically optimizes images before upload
2. **File Naming:** Uses timestamp to avoid conflicts
3. **Error Handling:** Proper error messages shown to users
4. **Validation:** Client-side validation before database updates
5. **User Feedback:** Loading states and success/error messages

Your profile editing system is now ready to use! 🎉
