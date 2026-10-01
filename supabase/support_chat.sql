-- ==============================================================================
-- ShopHub Customer Support Chat System Schema & RLS Policies
-- Execute this script in your Supabase Project:
--   Dashboard -> SQL Editor -> New Query -> Run
-- ==============================================================================

-- 1. Create support_conversations table
CREATE TABLE IF NOT EXISTS public.support_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  customer_name TEXT,
  customer_email TEXT,
  order_id TEXT REFERENCES public.orders(id) ON DELETE SET NULL,
  subject TEXT,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  last_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  closed_at TIMESTAMP WITH TIME ZONE NULL
);

-- Migration helpers if table already exists
ALTER TABLE public.support_conversations ADD COLUMN IF NOT EXISTS customer_name TEXT;
ALTER TABLE public.support_conversations ADD COLUMN IF NOT EXISTS customer_email TEXT;
ALTER TABLE public.support_conversations ADD COLUMN IF NOT EXISTS order_id TEXT REFERENCES public.orders(id) ON DELETE SET NULL;
ALTER TABLE public.support_conversations ADD COLUMN IF NOT EXISTS subject TEXT;
ALTER TABLE public.support_conversations ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'open';
ALTER TABLE public.support_conversations ADD COLUMN IF NOT EXISTS last_message TEXT;
ALTER TABLE public.support_conversations ADD COLUMN IF NOT EXISTS closed_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.support_conversations ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());

-- 2. Create support_messages table
CREATE TABLE IF NOT EXISTS public.support_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.support_conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL,
  sender_type TEXT NOT NULL CHECK (sender_type IN ('customer', 'admin')),
  sender_role TEXT NOT NULL DEFAULT 'customer' CHECK (sender_role IN ('customer', 'admin')),
  message TEXT NOT NULL CHECK (length(trim(message)) > 0),
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Migration helpers if table already exists
ALTER TABLE public.support_messages ADD COLUMN IF NOT EXISTS conversation_id UUID REFERENCES public.support_conversations(id) ON DELETE CASCADE;
ALTER TABLE public.support_messages ADD COLUMN IF NOT EXISTS sender_type TEXT DEFAULT 'customer';
ALTER TABLE public.support_messages ADD COLUMN IF NOT EXISTS sender_role TEXT DEFAULT 'customer';
ALTER TABLE public.support_messages ADD COLUMN IF NOT EXISTS message TEXT DEFAULT '';
ALTER TABLE public.support_messages ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT false;
ALTER TABLE public.support_messages ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());

-- 3. Performance Indexes
CREATE INDEX IF NOT EXISTS idx_support_conv_customer ON public.support_conversations(customer_id);
CREATE INDEX IF NOT EXISTS idx_support_conv_status ON public.support_conversations(status);
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
DROP POLICY IF EXISTS "Allow delete on support_conversations" ON public.support_conversations;
DROP POLICY IF EXISTS "Users and admins can view support conversations" ON public.support_conversations;
DROP POLICY IF EXISTS "Users and admins can insert support conversations" ON public.support_conversations;
DROP POLICY IF EXISTS "Users and admins can update support conversations" ON public.support_conversations;
DROP POLICY IF EXISTS "Users and admins can delete support conversations" ON public.support_conversations;

DROP POLICY IF EXISTS "Customers can view their conversation messages" ON public.support_messages;
DROP POLICY IF EXISTS "Customers can insert messages into their own conversation" ON public.support_messages;
DROP POLICY IF EXISTS "Admins can view and manage all messages" ON public.support_messages;
DROP POLICY IF EXISTS "Allow select on support_messages" ON public.support_messages;
DROP POLICY IF EXISTS "Allow insert on support_messages" ON public.support_messages;
DROP POLICY IF EXISTS "Allow update on support_messages" ON public.support_messages;
DROP POLICY IF EXISTS "Allow delete on support_messages" ON public.support_messages;
DROP POLICY IF EXISTS "Users and admins can view support messages" ON public.support_messages;
DROP POLICY IF EXISTS "Users and admins can insert support messages" ON public.support_messages;
DROP POLICY IF EXISTS "Users and admins can update support messages" ON public.support_messages;
DROP POLICY IF EXISTS "Users and admins can delete support messages" ON public.support_messages;

-- 6. Strict RLS Policies for support_conversations
-- SELECT: Customers view their own conversations; Admins view all conversations
CREATE POLICY "Users and admins can view support conversations"
  ON public.support_conversations FOR SELECT
  TO authenticated
  USING (
    auth.uid() = customer_id
    OR (customer_email IS NOT NULL AND customer_email = (auth.jwt() ->> 'email'))
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND (is_admin = true OR role = 'admin')
    )
  );

-- INSERT: Customers create their own conversation; Admins can create conversations
CREATE POLICY "Users and admins can insert support conversations"
  ON public.support_conversations FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = customer_id
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND (is_admin = true OR role = 'admin')
    )
  );

-- UPDATE: Customers can update their own conversation; Admins can update any conversation (close/reopen)
CREATE POLICY "Users and admins can update support conversations"
  ON public.support_conversations FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = customer_id
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND (is_admin = true OR role = 'admin')
    )
  )
  WITH CHECK (
    auth.uid() = customer_id
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND (is_admin = true OR role = 'admin')
    )
  );

-- DELETE: Customers delete their own; Admins delete any conversation
CREATE POLICY "Users and admins can delete support conversations"
  ON public.support_conversations FOR DELETE
  TO authenticated
  USING (
    auth.uid() = customer_id
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND (is_admin = true OR role = 'admin')
    )
  );

-- 7. Strict RLS Policies for support_messages
-- SELECT: Customers view messages in their conversations; Admins view all messages
CREATE POLICY "Users and admins can view support messages"
  ON public.support_messages FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.support_conversations c
      WHERE c.id = conversation_id
      AND (
        c.customer_id = auth.uid()
        OR (c.customer_email IS NOT NULL AND c.customer_email = (auth.jwt() ->> 'email'))
      )
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND (is_admin = true OR role = 'admin')
    )
  );

-- INSERT: Customers send to their own conversation; Admins send to any conversation
CREATE POLICY "Users and admins can insert support messages"
  ON public.support_messages FOR INSERT
  TO authenticated
  WITH CHECK (
    (
      auth.uid() = sender_id
      AND EXISTS (
        SELECT 1 FROM public.support_conversations c
        WHERE c.id = conversation_id
        AND (
          c.customer_id = auth.uid()
          OR (c.customer_email IS NOT NULL AND c.customer_email = (auth.jwt() ->> 'email'))
        )
      )
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND (is_admin = true OR role = 'admin')
    )
  );

-- UPDATE: Mark messages as read
CREATE POLICY "Users and admins can update support messages"
  ON public.support_messages FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.support_conversations c
      WHERE c.id = conversation_id
      AND (
        c.customer_id = auth.uid()
        OR (c.customer_email IS NOT NULL AND c.customer_email = (auth.jwt() ->> 'email'))
      )
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND (is_admin = true OR role = 'admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.support_conversations c
      WHERE c.id = conversation_id
      AND (
        c.customer_id = auth.uid()
        OR (c.customer_email IS NOT NULL AND c.customer_email = (auth.jwt() ->> 'email'))
      )
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND (is_admin = true OR role = 'admin')
    )
  );

-- DELETE: Conversation owner or Admin can delete messages
CREATE POLICY "Users and admins can delete support messages"
  ON public.support_messages FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.support_conversations c
      WHERE c.id = conversation_id
      AND c.customer_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND (is_admin = true OR role = 'admin')
    )
  );

-- 8. Realtime Publication Setup
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

ALTER TABLE public.support_conversations REPLICA IDENTITY FULL;
ALTER TABLE public.support_messages REPLICA IDENTITY FULL;

-- 9. Force PostgREST schema cache reload immediately
NOTIFY pgrst, 'reload schema';
