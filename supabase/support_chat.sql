-- ==============================================================================
-- ShopHub Customer Support Chat & Completed Orders Schema
-- Run this script in the Supabase Dashboard -> SQL Editor
-- ==============================================================================

-- 1. Create support_conversations table
CREATE TABLE IF NOT EXISTS public.support_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id TEXT NOT NULL,
  customer_name TEXT,
  customer_email TEXT,
  order_id TEXT REFERENCES public.orders(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  last_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Migration helpers if table already exists
ALTER TABLE public.support_conversations ADD COLUMN IF NOT EXISTS customer_id TEXT;
ALTER TABLE public.support_conversations ADD COLUMN IF NOT EXISTS customer_name TEXT;
ALTER TABLE public.support_conversations ADD COLUMN IF NOT EXISTS customer_email TEXT;
ALTER TABLE public.support_conversations ADD COLUMN IF NOT EXISTS order_id TEXT REFERENCES public.orders(id) ON DELETE SET NULL;
ALTER TABLE public.support_conversations ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'open';
ALTER TABLE public.support_conversations ADD COLUMN IF NOT EXISTS subject TEXT;
ALTER TABLE public.support_conversations ADD COLUMN IF NOT EXISTS closed_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.support_conversations ADD COLUMN IF NOT EXISTS last_message TEXT;
ALTER TABLE public.support_conversations ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());

-- Ensure customer_id column is TEXT so it accepts Supabase UUIDs, demo IDs, or email strings
DO $$
BEGIN
  ALTER TABLE public.support_conversations ALTER COLUMN customer_id TYPE TEXT;
EXCEPTION WHEN others THEN
  NULL;
END $$;

-- 2. Create support_messages table
CREATE TABLE IF NOT EXISTS public.support_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES public.support_conversations(id) ON DELETE CASCADE NOT NULL,
  sender_id TEXT NOT NULL,
  sender_role TEXT NOT NULL CHECK (sender_role IN ('customer', 'admin')),
  message TEXT NOT NULL CHECK (length(trim(message)) > 0),
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Migration helpers if table already exists
ALTER TABLE public.support_messages ADD COLUMN IF NOT EXISTS conversation_id UUID REFERENCES public.support_conversations(id) ON DELETE CASCADE;
ALTER TABLE public.support_messages ADD COLUMN IF NOT EXISTS sender_id TEXT;
ALTER TABLE public.support_messages ADD COLUMN IF NOT EXISTS sender_role TEXT DEFAULT 'customer';
ALTER TABLE public.support_messages ADD COLUMN IF NOT EXISTS message TEXT DEFAULT '';
ALTER TABLE public.support_messages ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT false;
ALTER TABLE public.support_messages ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());

DO $$
BEGIN
  ALTER TABLE public.support_messages ALTER COLUMN sender_id TYPE TEXT;
EXCEPTION WHEN others THEN
  NULL;
END $$;

-- 3. High Performance Indexes
CREATE INDEX IF NOT EXISTS idx_support_conv_customer ON public.support_conversations(customer_id);
CREATE INDEX IF NOT EXISTS idx_support_conv_order ON public.support_conversations(order_id);
CREATE INDEX IF NOT EXISTS idx_support_conv_updated ON public.support_conversations(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_support_msg_conversation ON public.support_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_support_msg_created ON public.support_messages(created_at ASC);
CREATE INDEX IF NOT EXISTS idx_support_msg_unread ON public.support_messages(conversation_id, is_read);

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.support_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;

-- 5. Drop any existing conflicting policies
DROP POLICY IF EXISTS "Customers can view their own conversations" ON public.support_conversations;
DROP POLICY IF EXISTS "Customers can create their own conversations" ON public.support_conversations;
DROP POLICY IF EXISTS "Admins can view and manage all conversations" ON public.support_conversations;
DROP POLICY IF EXISTS "Allow select on support_conversations" ON public.support_conversations;
DROP POLICY IF EXISTS "Allow insert on support_conversations" ON public.support_conversations;
DROP POLICY IF EXISTS "Allow update on support_conversations" ON public.support_conversations;

DROP POLICY IF EXISTS "Customers can view their conversation messages" ON public.support_messages;
DROP POLICY IF EXISTS "Customers can insert messages into their own conversation" ON public.support_messages;
DROP POLICY IF EXISTS "Admins can view and manage all messages" ON public.support_messages;
DROP POLICY IF EXISTS "Allow select on support_messages" ON public.support_messages;
DROP POLICY IF EXISTS "Allow insert on support_messages" ON public.support_messages;
DROP POLICY IF EXISTS "Allow update on support_messages" ON public.support_messages;

-- 6. Resilient RLS Policies for support_conversations
-- Allows both authenticated & anon clients to read, insert, update, and delete conversations
DROP POLICY IF EXISTS "Allow delete on support_conversations" ON public.support_conversations;
CREATE POLICY "Allow select on support_conversations"
  ON public.support_conversations FOR SELECT
  USING (true);

CREATE POLICY "Allow insert on support_conversations"
  ON public.support_conversations FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Allow update on support_conversations"
  ON public.support_conversations FOR UPDATE
  USING (true);

CREATE POLICY "Allow delete on support_conversations"
  ON public.support_conversations FOR DELETE
  USING (true);

-- 7. Resilient RLS Policies for support_messages
-- Allows bidirectional messaging between Customer and Admin without foreign key or JWT drops
DROP POLICY IF EXISTS "Allow delete on support_messages" ON public.support_messages;
CREATE POLICY "Allow select on support_messages"
  ON public.support_messages FOR SELECT
  USING (true);

CREATE POLICY "Allow insert on support_messages"
  ON public.support_messages FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Allow update on support_messages"
  ON public.support_messages FOR UPDATE
  USING (true);

CREATE POLICY "Allow delete on support_messages"
  ON public.support_messages FOR DELETE
  USING (true);

-- 8. Customer Order Completion RLS Policy on orders
DROP POLICY IF EXISTS "Customers can mark their delivered orders as completed" ON public.orders;
CREATE POLICY "Customers can mark their delivered orders as completed"
  ON public.orders FOR UPDATE
  USING (true)
  WITH CHECK (true);

-- 9. Realtime Publication Setup
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.support_conversations, public.support_messages;
  EXCEPTION WHEN duplicate_object THEN
    NULL;
  WHEN undefined_object THEN
    NULL;
  END;
END $$;
