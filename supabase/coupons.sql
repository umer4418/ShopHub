-- ==============================================================================
-- ShopHub Supabase Schema Migration: Coupons Table & Order Coupon Tracking
-- Run this in your Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ==============================================================================

-- 1. Create Coupons Table
CREATE TABLE IF NOT EXISTS public.coupons (
  id TEXT PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  discount_percent INT NOT NULL,
  min_order_amount NUMERIC NOT NULL DEFAULT 0,
  expiry_date TIMESTAMP WITH TIME ZONE NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  usage_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Add Coupon Tracking Columns to Orders Table (if not already present)
ALTER TABLE public.orders 
  ADD COLUMN IF NOT EXISTS coupon_code TEXT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS discount_amount NUMERIC DEFAULT NULL;

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies
DROP POLICY IF EXISTS "Coupons viewable by everyone" ON public.coupons;
CREATE POLICY "Coupons viewable by everyone" 
  ON public.coupons FOR SELECT USING (true);

DROP POLICY IF EXISTS "Coupons insertable by everyone" ON public.coupons;
CREATE POLICY "Coupons insertable by everyone" 
  ON public.coupons FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Coupons updatable by everyone" ON public.coupons;
CREATE POLICY "Coupons updatable by everyone" 
  ON public.coupons FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Coupons deletable by everyone" ON public.coupons;
CREATE POLICY "Coupons deletable by everyone" 
  ON public.coupons FOR DELETE USING (true);

-- 5. Seed Initial Promo Coupons (Including CUPON15 with 30% OFF)
INSERT INTO public.coupons (id, code, discount_percent, min_order_amount, expiry_date, is_active, usage_count) VALUES
  ('cp_1', 'SHOPHUB20', 20, 1500, now() + interval '60 days', true, 42),
  ('cp_2', 'WELCOME10', 10, 500, now() + interval '90 days', true, 118),
  ('cp_3', 'SUPERADMIN50', 50, 2500, now() + interval '120 days', true, 15),
  ('cp_4', 'EIDMEGA', 30, 4000, now() + interval '45 days', true, 67),
  ('cp_5', 'CUPON15', 30, 500, now() + interval '90 days', true, 23)
ON CONFLICT (code) DO UPDATE SET
  discount_percent = EXCLUDED.discount_percent,
  min_order_amount = EXCLUDED.min_order_amount,
  expiry_date = EXCLUDED.expiry_date,
  is_active = EXCLUDED.is_active;
