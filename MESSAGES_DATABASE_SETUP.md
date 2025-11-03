# Messages Database Setup Guide

## Overview
This guide will help you set up the database tables and policies needed for the messaging feature in Restoria.

## Step 1: Access Supabase SQL Editor

1. Go to https://supabase.com/dashboard
2. Select your project (wkayjcularwgjctoxzwt)
3. Click on **SQL Editor** in the left sidebar

## Step 2: Create the Database Schema

Copy and paste the entire contents of `database/messages_schema.sql` into the SQL Editor and click **Run**.

This will create:
- **conversations** table: Stores one-on-one conversations between two users
- **messages** table: Stores individual messages within conversations
- **Indexes**: For better query performance
- **RLS Policies**: Security policies to ensure users only see their own conversations
- **Triggers**: Automatically update conversation timestamps when messages are sent
- **Helper Function**: `get_or_create_conversation()` to find or create conversations

## Step 3: Verify Tables Were Created

Run this query to check if tables exist:

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('conversations', 'messages');
```

You should see both `conversations` and `messages` in the results.

## Step 4: Verify RLS Policies

Run this query to check RLS policies:

```sql
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE tablename IN ('conversations', 'messages');
```

You should see policies for viewing, creating, and updating conversations and messages.

## Database Schema Details

### conversations table
| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| participant1_id | UUID | First user in conversation (always smaller UUID) |
| participant2_id | UUID | Second user in conversation (always larger UUID) |
| created_at | TIMESTAMPTZ | When conversation was created |
| updated_at | TIMESTAMPTZ | Last message timestamp (auto-updated) |

### messages table
| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| conversation_id | UUID | References conversations(id) |
| sender_id | UUID | User who sent the message |
| content | TEXT | Message text content |
| created_at | TIMESTAMPTZ | When message was sent |
| is_read | BOOLEAN | Whether message has been read |

## Security Features

- **RLS Enabled**: Both tables have Row Level Security enabled
- **User Isolation**: Users can only see conversations they are part of
- **No Self-Messaging**: Constraint prevents users from messaging themselves
- **No Duplicates**: Unique constraint prevents duplicate conversations

## Helper Function

The `get_or_create_conversation(user1_id, user2_id)` function:
- Finds existing conversation between two users
- Creates new conversation if none exists
- Ensures participant1_id is always the smaller UUID to prevent duplicates
- Returns the conversation UUID

Example usage in Flutter:
```dart
final result = await supabase.rpc(
  'get_or_create_conversation',
  params: {'user1_id': currentUserId, 'user2_id': otherUserId},
);
final conversationId = result as String;
```

## Troubleshooting

### If you get "relation already exists" errors:
The tables already exist. You can drop them and recreate:
```sql
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS conversations CASCADE;
-- Then run the schema again
```

### If you get RLS policy errors:
Check if policies already exist and drop duplicates:
```sql
DROP POLICY IF EXISTS "Users can view their own conversations" ON conversations;
-- Repeat for other policies, then recreate
```

## Next Steps

After setting up the database:
1. Update `messages_screen.dart` to fetch real conversations
2. Update `conversation_screen.dart` to save/load messages from database
3. Test the messaging functionality
