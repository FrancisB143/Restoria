-- Create conversations table
-- A conversation is between two users (one-on-one messaging)
CREATE TABLE IF NOT EXISTS conversations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  participant1_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  participant2_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  -- Ensure no duplicate conversations (participant1 < participant2 by UUID to prevent duplicates)
  CONSTRAINT unique_conversation UNIQUE (participant1_id, participant2_id),
  -- Ensure users don't message themselves
  CONSTRAINT different_participants CHECK (participant1_id != participant2_id)
);

-- Create messages table
CREATE TABLE IF NOT EXISTS messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  is_read BOOLEAN DEFAULT false NOT NULL
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_conversations_participant1 ON conversations(participant1_id);
CREATE INDEX IF NOT EXISTS idx_conversations_participant2 ON conversations(participant2_id);
CREATE INDEX IF NOT EXISTS idx_conversations_updated_at ON conversations(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);

-- Enable Row Level Security
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies for conversations table
-- Users can view conversations they are part of
CREATE POLICY "Users can view their own conversations" 
  ON conversations FOR SELECT 
  USING (
    auth.uid() = participant1_id OR 
    auth.uid() = participant2_id
  );

-- Users can create conversations they are part of
CREATE POLICY "Users can create conversations" 
  ON conversations FOR INSERT 
  WITH CHECK (
    auth.uid() = participant1_id OR 
    auth.uid() = participant2_id
  );

-- Users can update conversations they are part of (for updated_at timestamp)
CREATE POLICY "Users can update their own conversations" 
  ON conversations FOR UPDATE 
  USING (
    auth.uid() = participant1_id OR 
    auth.uid() = participant2_id
  );

-- RLS Policies for messages table
-- Users can view messages from conversations they are part of
CREATE POLICY "Users can view messages from their conversations" 
  ON messages FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM conversations 
      WHERE conversations.id = messages.conversation_id 
      AND (conversations.participant1_id = auth.uid() OR conversations.participant2_id = auth.uid())
    )
  );

-- Users can insert messages into conversations they are part of
CREATE POLICY "Users can send messages to their conversations" 
  ON messages FOR INSERT 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM conversations 
      WHERE conversations.id = messages.conversation_id 
      AND (conversations.participant1_id = auth.uid() OR conversations.participant2_id = auth.uid())
    )
    AND auth.uid() = sender_id
  );

-- Users can update messages they sent (for is_read status)
CREATE POLICY "Users can update messages in their conversations" 
  ON messages FOR UPDATE 
  USING (
    EXISTS (
      SELECT 1 FROM conversations 
      WHERE conversations.id = messages.conversation_id 
      AND (conversations.participant1_id = auth.uid() OR conversations.participant2_id = auth.uid())
    )
  );

-- Function to update conversation's updated_at timestamp when a message is sent
CREATE OR REPLACE FUNCTION update_conversation_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE conversations 
  SET updated_at = NEW.created_at 
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update conversation timestamp
DROP TRIGGER IF EXISTS update_conversation_timestamp_trigger ON messages;
CREATE TRIGGER update_conversation_timestamp_trigger
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_timestamp();

-- Function to get or create a conversation between two users
CREATE OR REPLACE FUNCTION get_or_create_conversation(user1_id UUID, user2_id UUID)
RETURNS UUID AS $$
DECLARE
  conversation_id UUID;
  min_user_id UUID;
  max_user_id UUID;
BEGIN
  -- Ensure participant1_id is always the smaller UUID to prevent duplicates
  IF user1_id < user2_id THEN
    min_user_id := user1_id;
    max_user_id := user2_id;
  ELSE
    min_user_id := user2_id;
    max_user_id := user1_id;
  END IF;

  -- Try to find existing conversation
  SELECT id INTO conversation_id
  FROM conversations
  WHERE participant1_id = min_user_id AND participant2_id = max_user_id;

  -- If not found, create new conversation
  IF conversation_id IS NULL THEN
    INSERT INTO conversations (participant1_id, participant2_id)
    VALUES (min_user_id, max_user_id)
    RETURNING id INTO conversation_id;
  END IF;

  RETURN conversation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
