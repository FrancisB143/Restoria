# Follow System Database Setup Guide for Supabase

## 📋 Overview
This guide will help you create a database structure for the follow/follower system in Supabase.

---

## 🗄️ Step 1: Create User Follows Table

### Run this SQL in Supabase SQL Editor:

```sql
-- Create user_follows table to track who follows whom
CREATE TABLE IF NOT EXISTS public.user_follows (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  follower_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  following_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(follower_id, following_id)
);

-- Create indexes for faster queries
CREATE INDEX idx_user_follows_follower ON public.user_follows(follower_id);
CREATE INDEX idx_user_follows_following ON public.user_follows(following_id);

-- Enable Row Level Security
ALTER TABLE public.user_follows ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view all follow relationships
CREATE POLICY "Anyone can view follows"
  ON public.user_follows FOR SELECT
  USING (true);

-- Policy: Authenticated users can follow others
CREATE POLICY "Users can follow others"
  ON public.user_follows FOR INSERT
  WITH CHECK (auth.uid() = follower_id);

-- Policy: Users can unfollow (delete their own follows)
CREATE POLICY "Users can unfollow"
  ON public.user_follows FOR DELETE
  USING (auth.uid() = follower_id);
```

---

## 📊 Step 2: Add Bio Field to Profiles Table (Optional)

If you want to support custom user bios:

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

## 📊 Database Structure

### User Follows Table Schema:

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key (auto-generated) |
| `follower_id` | UUID | User who is following (references auth.users) |
| `following_id` | UUID | User being followed (references auth.users) |
| `created_at` | TIMESTAMPTZ | Timestamp when follow relationship created |

### Key Features:
- **UNIQUE constraint**: Prevents duplicate follow relationships
- **CASCADE DELETE**: Automatically removes follows when user is deleted
- **Indexed columns**: Fast queries for followers/following counts

---

## 🔍 Useful Queries

### Count a user's followers:
```sql
SELECT COUNT(*) 
FROM public.user_follows 
WHERE following_id = '{user_id}';
```

### Count how many people a user follows:
```sql
SELECT COUNT(*) 
FROM public.user_follows 
WHERE follower_id = '{user_id}';
```

### Check if user A follows user B:
```sql
SELECT * 
FROM public.user_follows 
WHERE follower_id = '{user_a_id}' 
  AND following_id = '{user_b_id}';
```

### Get list of a user's followers:
```sql
SELECT p.* 
FROM public.user_follows uf
JOIN public.profiles p ON p.id = uf.follower_id
WHERE uf.following_id = '{user_id}';
```

### Get list of users that someone follows:
```sql
SELECT p.* 
FROM public.user_follows uf
JOIN public.profiles p ON p.id = uf.following_id
WHERE uf.follower_id = '{user_id}';
```

---

## 🧪 Test Your Setup

Run these queries to verify everything works:

```sql
-- Check if table exists
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name = 'user_follows';

-- Check RLS policies
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE tablename = 'user_follows';

-- Test insert (replace with actual user IDs)
INSERT INTO public.user_follows (follower_id, following_id)
VALUES (
  (SELECT id FROM auth.users LIMIT 1 OFFSET 0),
  (SELECT id FROM auth.users LIMIT 1 OFFSET 1)
);

-- Test count
SELECT 
  following_id,
  COUNT(*) as follower_count
FROM public.user_follows
GROUP BY following_id;
```

---

## 🔐 Security Notes

1. **RLS Enabled:** Row Level Security ensures users can only create/delete their own follows
2. **Public Viewing:** Anyone can view follow relationships (good for social features)
3. **No Self-Following:** You can add a constraint if needed:

```sql
ALTER TABLE public.user_follows 
ADD CONSTRAINT no_self_follow 
CHECK (follower_id != following_id);
```

---

## ✅ Verification Checklist

Before proceeding:

- [ ] `user_follows` table created successfully
- [ ] Indexes created on `follower_id` and `following_id`
- [ ] RLS policies applied
- [ ] UNIQUE constraint prevents duplicates
- [ ] Test queries run without errors
- [ ] (Optional) `bio` field added to profiles table

---

## 🚀 Features Now Available

After completing this setup:

✅ **Follow/Unfollow System**
- Users can follow other creators
- Real-time follower/following counts
- Follow state persists across sessions

✅ **Creator Profiles**
- Display accurate follower/following counts
- Show all creator's projects (tutorials + gallery posts)
- Load data directly from database

✅ **Database Integration**
- Uses Supabase for follow relationships
- Falls back to SharedPreferences if database unavailable
- Automatic synchronization

---

## 🆘 Troubleshooting

### Error: "permission denied for table user_follows"
- Make sure RLS policies are created
- Check that you're authenticated when testing

### Error: "duplicate key value violates unique constraint"
- User already follows this person
- This is expected behavior (prevents duplicate follows)

### Counts are incorrect
- Check if test data exists in user_follows table
- Verify queries are using correct user IDs
- Make sure CASCADE DELETE is working properly

---

## 📝 Example Data

To insert test follow relationships:

```sql
-- User 1 follows User 2
INSERT INTO public.user_follows (follower_id, following_id)
VALUES (
  (SELECT id FROM auth.users WHERE email = 'user1@example.com'),
  (SELECT id FROM auth.users WHERE email = 'user2@example.com')
);

-- User 1 follows User 3
INSERT INTO public.user_follows (follower_id, following_id)
VALUES (
  (SELECT id FROM auth.users WHERE email = 'user1@example.com'),
  (SELECT id FROM auth.users WHERE email = 'user3@example.com')
);
```

Now User 1 follows 2 people, and Users 2 & 3 each have 1 follower!
