-- ==============================================================================
-- ShopHub Supabase Row Level Security (RLS) for Orders Table
-- Run this script in the Supabase Dashboard -> SQL Editor
-- ==============================================================================

-- 1. Ensure user_id column exists on orders table referencing auth.users
ALTER TABLE public.orders 
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.orders 
  ADD COLUMN IF NOT EXISTS customer_email TEXT DEFAULT NULL;

-- 2. Enable Row Level Security (RLS) on orders
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- 3. Drop all previous permissive or conflicting policies on orders
DROP POLICY IF EXISTS "Orders viewable by everyone" ON public.orders;
DROP POLICY IF EXISTS "Orders insertable by everyone" ON public.orders;
DROP POLICY IF EXISTS "Orders updatable by everyone" ON public.orders;
DROP POLICY IF EXISTS "Users can view their own orders" ON public.orders;
DROP POLICY IF EXISTS "Users can insert their own orders" ON public.orders;
DROP POLICY IF EXISTS "Admins can view all orders" ON public.orders;
DROP POLICY IF EXISTS "Admins can update orders" ON public.orders;
DROP POLICY IF EXISTS "Admins can delete orders" ON public.orders;

-- 4. SELECT Policy:
-- Authenticated users can view their own orders (matching user_id or authenticated email).
-- Super Admins (is_admin = true or role = 'admin' in public.profiles) can view ALL orders.
CREATE POLICY "Users can view their own orders" 
  ON public.orders FOR SELECT 
  TO authenticated 
  USING (
    auth.uid() = user_id 
    OR (customer_email IS NOT NULL AND customer_email = (auth.jwt() ->> 'email'))
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() 
      AND (is_admin = true OR role = 'admin')
    )
  );

-- 5. INSERT Policy:
-- Authenticated users can insert their own orders (user_id = auth.uid()),
-- and guest checkout is supported if auth.uid() is null.
CREATE POLICY "Users can insert their own orders" 
  ON public.orders FOR INSERT 
  WITH CHECK (
    auth.uid() = user_id OR auth.uid() IS NULL OR user_id IS NULL
  );

-- 6. UPDATE Policy:
-- Users can update their own orders (e.g. For marking delivered -> completed, upserts),
-- and Super Admins can update any order.
CREATE POLICY "Users and admins can update orders" 
  ON public.orders FOR UPDATE 
  TO authenticated 
  USING (
    auth.uid() = user_id 
    OR (customer_email IS NOT NULL AND customer_email = (auth.jwt() ->> 'email'))
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() 
      AND (is_admin = true OR role = 'admin')
    )
  )
  WITH CHECK (
    auth.uid() = user_id 
    OR (customer_email IS NOT NULL AND customer_email = (auth.jwt() ->> 'email'))
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() 
      AND (is_admin = true OR role = 'admin')
    )
  );

-- 7. DELETE Policy:
-- Only Admins can delete orders.
CREATE POLICY "Admins can delete orders" 
  ON public.orders FOR DELETE 
  TO authenticated 
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() 
      AND (is_admin = true OR role = 'admin')
    )
  );
