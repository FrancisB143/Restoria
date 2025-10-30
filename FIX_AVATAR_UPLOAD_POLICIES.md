# Fix Avatar Upload - Storage Policies Setup

## The Problem
You're getting this error:
```
StorageException(message: new row violates row-level security policy, statusCode: 403, error: Unauthorized)
```

This means your `profile-avatars` bucket exists but lacks the necessary Row-Level Security (RLS) policies.

## Quick Fix (2 minutes)

### Step 1: Go to Supabase Dashboard
1. Open https://supabase.com/dashboard
2. Select your **Restoria** project
3. Click **Storage** in the left sidebar
4. Click on your `profile-avatars` bucket

### Step 2: Add Policies

Click the **Policies** tab, then click **New Policy**, and create these 3 policies:

---

#### Policy 1: Allow Users to Upload Their Own Avatars

**Policy Name:** `Users can upload own avatars`

**Operation:** INSERT

**Target Roles:** authenticated

**USING expression:** (leave empty)

**WITH CHECK expression:**
```sql
bucket_id = 'profile-avatars' AND 
(storage.foldername(name))[1] = auth.uid()::text
```

---

#### Policy 2: Allow Public Viewing of Avatars

**Policy Name:** `Anyone can view profile avatars`

**Operation:** SELECT

**Target Roles:** public

**USING expression:**
```sql
bucket_id = 'profile-avatars'
```

**WITH CHECK expression:** (leave empty)

---

#### Policy 3: Allow Users to Update Their Own Avatars

**Policy Name:** `Users can update own avatars`

**Operation:** UPDATE

**Target Roles:** authenticated

**USING expression:**
```sql
bucket_id = 'profile-avatars' AND 
(storage.foldername(name))[1] = auth.uid()::text
```

**WITH CHECK expression:** (leave empty)

---

## Alternative: SQL Method (Faster)

If you prefer SQL, go to **SQL Editor** in Supabase and run this:

```sql
-- Policy 1: Users can upload their own avatars
CREATE POLICY "Users can upload own avatars"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'profile-avatars' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 2: Anyone can view profile avatars
CREATE POLICY "Anyone can view profile avatars"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'profile-avatars');

-- Policy 3: Users can update their own avatars
CREATE POLICY "Users can update own avatars"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'profile-avatars' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 4: Users can delete their own avatars
CREATE POLICY "Users can delete own avatars"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'profile-avatars' AND
  (storage.foldername(name))[1] = auth.uid()::text
);
```

---

## Test After Setup

1. **No need to restart your app** - policies take effect immediately
2. Try uploading an avatar again
3. You should see in the console:
   ```
   Starting avatar upload for user: [your-id]
   Attempting direct upload to profile-avatars bucket...
   Uploading for web, size: [bytes]
   Web upload successful
   Avatar uploaded successfully. Public URL: https://...
   ```

---

## What These Policies Do

✅ **INSERT Policy**: Allows authenticated users to upload files ONLY to their own folder (folder name must match their user ID)

✅ **SELECT Policy**: Allows anyone (public) to view/download avatar images (needed for displaying avatars in the app)

✅ **UPDATE Policy**: Allows users to replace their own avatars with upsert=true

✅ **DELETE Policy**: Allows users to delete their own old avatars

---

## Security Notes

🔒 **Folder Structure**: Avatars are uploaded to `avatars/[user-id]_[timestamp].jpg`

🔒 **User Isolation**: Users can only upload to paths that start with their user ID

🔒 **Public Read**: Anyone can view avatars (required for public profiles)

🔒 **Private Write**: Only the owner can upload/update their avatars

---

## Troubleshooting

### Still getting 403 error?
- Make sure policies are created on `storage.objects` table, not the bucket itself
- Verify your user is authenticated (check `auth.uid()` returns a value)
- Check that bucket name is exactly `profile-avatars` (case-sensitive)

### Bucket not public?
- In Storage → Click bucket → Settings → Toggle "Public bucket" ON

### Can't see the bucket?
- The bucket might exist but you don't have permission to list buckets
- That's OK - the upload will still work with the policies above

---

**After running the SQL or creating the policies, try uploading an avatar again - it should work immediately!** ✨
