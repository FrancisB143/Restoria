# Admin Panel Setup Guide

## Overview
The admin panel allows designated users to moderate content by removing tutorials and gallery posts that violate guidelines. All admin actions are logged for accountability.

## Features Implemented

### 1. Video Upload Limits (Add Tutorial Screen)
- **Maximum Duration**: 2 minutes
- **Maximum File Size**: 50MB
- File size is checked before upload
- User receives clear error messages if limits are exceeded

### 2. Admin Panel Screen
- **Tutorials Tab**: View and delete tutorials
- **Gallery Tab**: View and delete gallery posts
- **Actions Tab**: View history of all admin actions

### 3. Admin Action Logging
All deletions are logged with:
- Admin who performed the action
- Type of action (delete tutorial/gallery post)
- Deleted content title/description
- Original creator's name
- Thumbnail/image of deleted content
- Reason for deletion
- Timestamp

## Database Setup

### Step 1: Run Admin Schema SQL

1. Open Supabase Dashboard: https://supabase.com/dashboard
2. Select your project
3. Go to **SQL Editor**
4. Copy the entire contents of `database/admin_schema.sql`
5. Paste and click **Run**

This creates:
- `is_admin` column in profiles table
- `admin_actions` table for logging
- RLS policies for admin access
- Helper function `is_user_admin()`

### Step 2: Set Up Admin User

After running the schema, you need to designate at least one admin user.

**Option 1: Set admin by email**
```sql
UPDATE profiles 
SET is_admin = true 
WHERE email = 'your-admin-email@example.com';
```

**Option 2: Set admin by user ID**
```sql
-- First, find your user ID
SELECT id, email, name FROM profiles WHERE email = 'your-email@example.com';

-- Then set as admin
UPDATE profiles 
SET is_admin = true 
WHERE id = 'YOUR_USER_ID_HERE';
```

**Example Admin User Setup:**
```sql
-- Replace with your actual email or create a test admin
UPDATE profiles 
SET is_admin = true 
WHERE email = 'admin@restoria.com';
```

### Step 3: Verify Admin Access

1. Login to the app with your admin account
2. Go to Profile screen
3. You should see an orange **Admin Panel** icon (⚙️) next to the logout button
4. Click it to access the admin panel

## Admin Panel Usage

### Accessing the Admin Panel
1. Login with an admin account
2. Navigate to Profile screen
3. Click the **Admin Panel** icon (orange gear icon)
4. If you're not an admin, you'll see an "Access Denied" message

### Deleting Content

#### To Delete a Tutorial:
1. Go to **Tutorials** tab in admin panel
2. Find the tutorial you want to remove
3. Click the red **delete** icon
4. Confirm deletion
5. Enter a reason (e.g., "Violates safety guidelines")
6. Tutorial will be removed from database

#### To Delete a Gallery Post:
1. Go to **Gallery** tab in admin panel
2. Find the post you want to remove
3. Click the red **delete** icon
4. Confirm deletion
5. Enter a reason (e.g., "Inappropriate content")
6. Post will be removed from database

### Viewing Admin Actions
1. Go to **Actions** tab
2. See chronological list of all admin actions
3. Each entry shows:
   - **Thumbnail/Image** of the deleted content
   - Action type (Delete Tutorial/Delete Gallery Post)
   - **Title** of deleted content
   - **Creator** of the content
   - Admin who performed it
   - Reason given
   - When it occurred

The Actions tab now displays a visual history with images, making it easy to see what content was removed and by whom.

## Video Upload Limits

When uploading a tutorial, the following limits apply:

### Duration Limit
- **Maximum**: 2 minutes (120 seconds)
- The image picker restricts video selection to 2 minutes
- Videos longer than 2 minutes cannot be selected

### File Size Limit
- **Maximum**: 50MB
- Checked after video selection
- If video exceeds 50MB, user sees error:
  ```
  Video file size must be less than 50MB. 
  Your video is XX.XMB
  ```
- User must select a smaller video file

### Tips for Users
- Compress videos before uploading
- Use lower resolution if file size is too large
- Keep tutorials concise (under 2 minutes)
- Consider splitting long tutorials into parts

## Security Features

### Row Level Security (RLS)
- Only admins can view admin_actions table
- Only admins can insert admin actions
- Regular users cannot access admin functionality

### Access Control
- Admin panel checks `is_admin` flag in profiles table
- Non-admin users see "Access Denied" screen
- Admin button only appears for admin users

### Action Logging
- All deletions are permanently logged
- Cannot be deleted (even by admins)
- Provides accountability trail

## Database Schema Details

### profiles table (updated)
```sql
ALTER TABLE profiles ADD COLUMN is_admin BOOLEAN DEFAULT false;
```

### admin_actions table
| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| admin_id | UUID | Admin who performed action |
| action_type | TEXT | Type of action performed |
| target_id | UUID | ID of deleted item |
| target_type | TEXT | Type of item (tutorial/gallery_post) |
| target_title | TEXT | Title/description of deleted content |
| target_creator | TEXT | Username of content creator |
| target_image_url | TEXT | Thumbnail/image URL of deleted content |
| reason | TEXT | Reason for action |
| created_at | TIMESTAMPTZ | When action occurred |

## Guidelines for Admins

### When to Delete Content

**Delete if content:**
- Contains inappropriate or offensive material
- Violates safety guidelines
- Is spam or promotional
- Infringes copyright
- Contains false or misleading information
- Promotes dangerous activities

### Deletion Reasons (Examples)
- "Violates community guidelines"
- "Unsafe procedure - risk of injury"
- "Spam content"
- "Copyright infringement"
- "Inappropriate language/images"
- "Not related to e-waste upcycling"

### Best Practices
1. Always provide a clear reason for deletion
2. Be consistent in applying guidelines
3. Review content carefully before deleting
4. Document patterns of violations
5. Consider warnings before deletion for minor issues

## Troubleshooting

### Admin button not showing
- Verify `is_admin = true` in database
- Logout and login again
- Check that profile screen loaded correctly

### Cannot access admin panel
- Ensure admin schema SQL was run successfully
- Verify RLS policies were created
- Check user has `is_admin = true` in profiles

### Cannot delete content
- Ensure logged in as admin
- Check RLS policies on tutorials/gallery_posts tables
- Verify internet connection

### Video upload limits not working
- Clear app cache and restart
- Ensure using latest version of code
- Check file system permissions

## Testing Checklist

- [ ] Run admin schema SQL in Supabase
- [ ] Create at least one admin user
- [ ] Login with admin account
- [ ] Verify admin button appears in profile
- [ ] Access admin panel successfully
- [ ] View tutorials list in admin panel
- [ ] View gallery posts list in admin panel
- [ ] Delete a test tutorial with reason
- [ ] Delete a test gallery post with reason
- [ ] Verify deletions appear in Actions tab
- [ ] Verify deleted content removed from app
- [ ] Test video duration limit (try >2 min video)
- [ ] Test video file size limit (try >50MB video)
- [ ] Login with non-admin account
- [ ] Verify admin button doesn't appear
- [ ] Verify cannot access admin panel directly

## Example Admin Account

For testing, you can create a dedicated admin account:

```sql
-- After registering a user with email admin@restoria.com
UPDATE profiles 
SET is_admin = true, 
    name = 'Admin', 
    bio = 'Restoria Administrator'
WHERE email = 'admin@restoria.com';
```

Then login with:
- Email: admin@restoria.com
- Password: (whatever you set during registration)

## Future Enhancements (Optional)

1. **User Management**: Ban/suspend users
2. **Content Warnings**: Flag content instead of deleting
3. **Bulk Actions**: Delete multiple items at once
4. **Reports System**: Users can report violations
5. **Admin Roles**: Super admin, moderator levels
6. **Analytics**: Admin dashboard with statistics
7. **Appeal System**: Users can contest deletions
8. **Auto-Moderation**: AI-based content screening

## Summary

✅ Video upload limits implemented (2 minutes, 50MB)
✅ Admin panel created with delete functionality
✅ Admin actions logged to database
✅ Access control with is_admin flag
✅ Admin button in profile screen
✅ Clear reason required for deletions
✅ Security via RLS policies

The admin system is now fully functional and ready to use!
