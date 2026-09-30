-- ==============================================================================
-- ShopHub Payment Receipt & Stripe Reference Migration
-- Run this script in your Supabase Dashboard -> SQL Editor
-- ==============================================================================

-- 1. Add stripe_payment_id to store Stripe PaymentIntent or charge reference ID
ALTER TABLE public.orders 
  ADD COLUMN IF NOT EXISTS stripe_payment_id TEXT DEFAULT NULL;

-- 2. Add payment_status to track 'Paid', 'Pending', 'Failed'
ALTER TABLE public.orders 
  ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'Pending';

-- 3. Add delivery_fee to record delivery charges
ALTER TABLE public.orders 
  ADD COLUMN IF NOT EXISTS delivery_fee NUMERIC DEFAULT 0;

-- 4. Create index on stripe_payment_id for fast lookup
CREATE INDEX IF NOT EXISTS idx_orders_stripe_payment_id 
  ON public.orders (stripe_payment_id);

-- 5. Mark existing Stripe card orders as 'Paid'
UPDATE public.orders 
SET payment_status = 'Paid'
WHERE payment_method ILIKE '%stripe%' AND payment_status = 'Pending';
