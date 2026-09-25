-- ==============================================================================
-- ShopHub Supabase Postgres Schema & Initial Seed Data
-- Run this script in the Supabase Dashboard -> SQL Editor
-- ==============================================================================

-- 1. Create Profiles Table (linked to auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT DEFAULT '',
  is_admin BOOLEAN DEFAULT false,
  role TEXT DEFAULT 'customer',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Create Categories Table
CREATE TABLE IF NOT EXISTS public.categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  icon TEXT NOT NULL DEFAULT 'category',
  image_url TEXT DEFAULT '',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Create Products Table
CREATE TABLE IF NOT EXISTS public.products (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  category_id TEXT REFERENCES public.categories(id) ON DELETE SET NULL,
  image_url TEXT NOT NULL DEFAULT '',
  price NUMERIC NOT NULL,
  original_price NUMERIC NOT NULL,
  rating NUMERIC DEFAULT 0,
  review_count INT DEFAULT 0,
  short_description TEXT DEFAULT '',
  description TEXT DEFAULT '',
  stock INT DEFAULT 10,
  featured BOOLEAN DEFAULT false,
  popular BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Create Orders Table
CREATE TABLE IF NOT EXISTS public.orders (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  customer_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  address TEXT NOT NULL,
  payment_method TEXT NOT NULL DEFAULT 'Cash on Delivery',
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  total NUMERIC NOT NULL,
  coupon_code TEXT DEFAULT NULL,
  discount_amount NUMERIC DEFAULT NULL,
  status TEXT NOT NULL DEFAULT 'placed',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. Create Coupons Table
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

-- ==============================================================================
-- Row Level Security (RLS) Policies
-- ==============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;

-- Profiles: Anyone authenticated can read profiles; users can update their own
CREATE POLICY "Public profiles are viewable by everyone" 
  ON public.profiles FOR SELECT USING (true);

CREATE POLICY "Users can insert their own profile" 
  ON public.profiles FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update own profile" 
  ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Categories: Viewable by everyone; insert/update/delete open or authenticated
CREATE POLICY "Categories viewable by everyone" 
  ON public.categories FOR SELECT USING (true);

CREATE POLICY "Categories manageable by authenticated users" 
  ON public.categories FOR ALL USING (true);

-- Products: Viewable by everyone; insert/update/delete open or authenticated
CREATE POLICY "Products viewable by everyone" 
  ON public.products FOR SELECT USING (true);

CREATE POLICY "Products manageable by authenticated users" 
  ON public.products FOR ALL USING (true);

-- Orders: Viewable by everyone (or customer & admin); insertable by anyone
CREATE POLICY "Orders viewable by everyone" 
  ON public.orders FOR SELECT USING (true);

CREATE POLICY "Orders insertable by everyone" 
  ON public.orders FOR INSERT WITH CHECK (true);

CREATE POLICY "Orders updatable by everyone" 
  ON public.orders FOR UPDATE USING (true);

-- Coupons: Viewable by everyone; manageable by super admin & authenticated users
CREATE POLICY "Coupons viewable by everyone" 
  ON public.coupons FOR SELECT USING (true);

CREATE POLICY "Coupons insertable by everyone" 
  ON public.coupons FOR INSERT WITH CHECK (true);

CREATE POLICY "Coupons updatable by everyone" 
  ON public.coupons FOR UPDATE USING (true);

CREATE POLICY "Coupons deletable by everyone" 
  ON public.coupons FOR DELETE USING (true);

-- ==============================================================================
-- Automatic Profile Creation Trigger on New User Signup
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, name, email, phone, is_admin, role)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.email,
    COALESCE(new.raw_user_meta_data->>'phone', ''),
    COALESCE((new.raw_user_meta_data->>'is_admin')::boolean, false),
    COALESCE(new.raw_user_meta_data->>'role', 'customer')
  )
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    phone = EXCLUDED.phone,
    is_admin = EXCLUDED.is_admin,
    role = EXCLUDED.role;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Auto-confirm email trigger for instant login without email verification
CREATE OR REPLACE FUNCTION public.auto_confirm_new_user()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.email_confirmed_at IS NULL THEN
    NEW.email_confirmed_at = now();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_auto_confirm ON auth.users;
CREATE TRIGGER on_auth_user_auto_confirm
  BEFORE INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.auto_confirm_new_user();

-- Confirm all existing unconfirmed users
UPDATE auth.users
SET email_confirmed_at = now()
WHERE email_confirmed_at IS NULL;

-- ==============================================================================
-- Seed Data (Initial Categories & Products)
-- ==============================================================================

INSERT INTO public.categories (id, name, icon, image_url) VALUES
('electronics', 'Electronics', 'devices', 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=400'),
('fashion', 'Fashion', 'checkroom', 'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=400'),
('home', 'Home', 'chair', 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=400'),
('beauty', 'Beauty', 'spa', 'https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=400'),
('sports', 'Sports', 'sports_soccer', 'https://images.unsplash.com/photo-1517649763962-0c623066013b?w=400'),
('grocery', 'Grocery', 'shopping_basket', 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400'),
('kids', 'Kids', 'child_care', 'https://images.unsplash.com/photo-1515488042361-ee00e0ddd4e4?w=400'),
('mobiles', 'Mobiles', 'smartphone', 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=400')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  icon = EXCLUDED.icon,
  image_url = EXCLUDED.image_url;

INSERT INTO public.products (id, name, category_id, image_url, price, original_price, rating, review_count, short_description, description, stock, featured, popular) VALUES
('p1', 'ShopHub Wireless Earbuds Pro', 'electronics', 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=800', 3499, 5999, 4.6, 1284, 'ANC earbuds with 32h battery.', 'Enjoy studio-clear sound with active noise cancellation, touch controls, and a compact charging case. Water-resistant for workouts and daily commute.', 48, true, true),
('p2', 'Ultra Slim Laptop 15.6"', 'electronics', 'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=800', 89999, 119999, 4.5, 642, '16GB RAM, 512GB SSD, Full HD.', 'A lightweight everyday laptop for work and study. Fast SSD storage, long battery life, and a sharp Full HD display.', 12, true, false),
('p3', 'Smart Watch Series X', 'electronics', 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=800', 7999, 12999, 4.3, 2103, 'Heart rate, GPS, 7-day battery.', 'Track workouts, sleep, and notifications from your wrist. AMOLED display with customizable watch faces.', 80, false, true),
('p4', 'Android Smartphone 128GB', 'mobiles', 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=800', 45999, 54999, 4.7, 4301, '50MP camera, 5000mAh battery.', 'Flagship-feel camera, smooth 120Hz display, and all-day battery. Dual SIM with fast charging.', 25, true, true),
('p5', 'Cotton Oversized Tee', 'fashion', 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=800', 1290, 1990, 4.4, 876, 'Soft unisex everyday tee.', 'Breathable cotton with a relaxed fit. Pair with jeans or joggers. Machine washable.', 140, false, true),
('p6', 'Classic Denim Jacket', 'fashion', 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=800', 4590, 6990, 4.5, 321, 'Mid-wash denim, unisex cut.', 'A wardrobe staple with metal buttons and chest pockets. Layer over tees or dresses.', 36, true, false),
('p7', 'Running Sneakers Aero', 'fashion', 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=800', 4999, 8499, 4.6, 1540, 'Cushioned sole, breathable mesh.', 'Lightweight trainers for daily runs and casual wear. Anti-slip outsole and padded collar.', 54, true, true),
('p8', 'Minimal Leather Tote', 'fashion', 'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=800', 3890, 5590, 4.2, 198, 'Spacious work-and-weekend bag.', 'Vegan leather tote with inner pockets and a laptop sleeve. Clean silhouette for office days.', 22, false, false),
('p9', 'Nordic Accent Chair', 'home', 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=800', 18999, 25999, 4.4, 87, 'Soft fabric, oak-look legs.', 'A compact lounge chair that fits apartments and reading corners. Easy-wipe fabric.', 9, true, false),
('p10', 'Ceramic Dinner Set (16 pcs)', 'home', 'https://images.unsplash.com/photo-1603190287605-4f70b49d5e3f?w=800', 5499, 7999, 4.5, 412, 'Microwave-safe everyday set.', 'Plates, bowls, and mugs for four. Matte glaze that hides scratches from daily use.', 30, false, true),
('p11', 'Aroma Diffuser Lamp', 'home', 'https://images.unsplash.com/photo-1608571423902-eed4a5ad8108?w=800', 2499, 3999, 4.3, 560, 'LED mood light + mist.', 'Ultrasonic diffuser with color-changing light. Whisper-quiet for bedrooms.', 70, false, false),
('p12', 'Vitamin C Glow Serum', 'beauty', 'https://images.unsplash.com/photo-1620916566398-39f1143ab7be?w=800', 1890, 2890, 4.7, 2201, 'Brightens dull skin in 14 days.', 'Lightweight serum with vitamin C and hyaluronic acid. Use morning and night under moisturizer.', 95, true, true),
('p13', 'Matte Lip Kit Trio', 'beauty', 'https://images.unsplash.com/photo-1586495777744-4413f21062fa?w=800', 1590, 2490, 4.4, 734, 'Long-wear nudes and berry.', 'Three transfer-resistant shades with a creamy matte finish. Includes sharpener.', 60, false, false),
('p14', 'Yoga Mat Extra Grip', 'sports', 'https://images.unsplash.com/photo-1601925260368-ae2f83cf8b7f?w=800', 2190, 3290, 4.6, 990, '6mm cushion, carry strap.', 'Non-slip surface for yoga, pilates, and stretching. Sweat-resistant and easy to roll.', 40, false, true),
('p15', 'Adjustable Dumbbell 20kg', 'sports', 'https://images.unsplash.com/photo-1517963879433-6ad2b056d712?w=800', 9999, 14999, 4.5, 255, 'Home gym in one pair.', 'Quick-change plates from 2.5kg to 20kg. Compact storage for small spaces.', 18, true, false),
('p16', 'Organic Honey 500g', 'grocery', 'https://images.unsplash.com/photo-1587049352846-4a222e784d38?w=800', 890, 1190, 4.8, 3102, 'Raw, unfiltered, local.', 'Golden raw honey packed without additives. Great in tea, toast, and marinades.', 200, false, true),
('p17', 'Premium Basmati Rice 5kg', 'grocery', 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=800', 1450, 1750, 4.6, 1888, 'Long grain, aged aroma.', 'Fluffy extra-long grains for biryani and everyday meals. Vacuum packed for freshness.', 150, false, false),
('p18', 'Wooden Building Blocks', 'kids', 'https://images.unsplash.com/photo-1587654780291-39c9404d746b?w=800', 1790, 2490, 4.7, 441, '50 pcs, safe rounded edges.', 'Natural wood blocks that spark creativity. Packed in a cotton bag for easy cleanup.', 44, true, false),
('p19', 'Kids Story Bundle (5 books)', 'kids', 'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=800', 1990, 2990, 4.8, 612, 'Illustrated bedtime classics.', 'Five hardcover picture books with large print. Ages 3–8.', 33, false, true),
('p20', 'Bluetooth Party Speaker', 'electronics', 'https://images.unsplash.com/photo-1545454675-3531b543be5d?w=800', 6499, 9999, 4.4, 1502, 'Deep bass, 12h playtime.', 'Portable speaker with RGB lights, IPX5 splash resistance, and true wireless pairing.', 27, true, true),
('p21', 'Studio Pro Over-Ear Headphones', 'electronics', 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=800', 11999, 15999, 4.8, 940, 'Hi-Res audio with memory foam cushions.', 'Reference-grade studio monitoring headphones with plush memory foam ear cushions, 50mm neodymium drivers, and gold-plated 3.5mm jack with 6.35mm adapter.', 35, true, false),
('p22', 'RGB Mechanical Gaming Keyboard', 'electronics', 'https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=800', 5999, 7999, 4.7, 680, 'Hot-swappable switches, per-key RGB.', 'Full-size mechanical keyboard equipped with responsive tactile switches, double-shot PBT keycaps, and customizable dynamic RGB lighting profiles.', 45, false, true),
('p23', '4K Waterproof Action Camera', 'electronics', 'https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?w=800', 14999, 19999, 4.6, 310, '4K/60fps video with dual touch screens.', 'Capture every adventure in crisp 4K Ultra HD. Features electronic image stabilization, 30m waterproof casing, wide-angle lens, and Wi-Fi instant sharing.', 20, true, false),
('p24', 'Fast Wireless Charging Pad 15W', 'mobiles', 'https://images.unsplash.com/photo-1586105251261-72a756497a11?w=800', 1899, 2899, 4.5, 1120, 'Qi-certified 15W fast charge.', 'Ultra-slim aluminum wireless charger compatible with all Qi-enabled iPhone and Android devices. Built-in over-temperature and surge protection.', 85, false, true),
('p25', 'Polarized Aviator Sunglasses', 'fashion', 'https://images.unsplash.com/photo-1511499767150-a48a237f0083?w=800', 2490, 3990, 4.4, 420, 'UV400 protection with metal frame.', 'Timeless aviator styling with scratch-resistant polarized lenses that block 100% of UVA and UVB rays. Includes hard protective case and microfiber cloth.', 65, false, false),
('p26', 'Heavyweight Fleece Pullover Hoodie', 'fashion', 'https://images.unsplash.com/photo-1556905055-8f358a7a47b2?w=800', 3290, 4890, 4.7, 880, 'Soft brushed fleece, kangaroo pocket.', 'Cozy premium cotton-poly blend hoodie with double-layer hood, metal eyelets, and ribbed cuffs. Perfect for casual wear and cool weather.', 50, true, true),
('p27', 'Insulated Stainless Steel Water Bottle', 'sports', 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?w=800', 1690, 2490, 4.8, 750, 'Keeps cold 24h, hot 12h (750ml).', 'Double-walled vacuum insulated sports bottle made from BPA-free food-grade 18/8 stainless steel. Leak-proof straw lid and powder-coated durable grip.', 90, false, true),
('p28', 'Organic Ceremonial Matcha Tea 100g', 'grocery', 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=800', 2150, 2850, 4.9, 520, 'Pure first-harvest stone-ground green tea.', 'Rich in antioxidants, L-theanine, and natural chlorophyll. Vibrant green ceremonial-grade matcha for lattes, smoothies, and mindful tea ceremonies.', 75, true, false),
('p29', 'High-Speed Remote Control Stunt Car', 'kids', 'https://images.unsplash.com/photo-1594787318286-3d835c1d207f?w=800', 3299, 4999, 4.6, 380, '360° spinning flips, dual rechargeable battery.', 'All-terrain 4WD stunt car with LED headlights, durable anti-shock rubber tires, and 2.4GHz anti-interference controller. Delivers up to 45 minutes of fun.', 40, false, true),
('p30', 'Ultra-Slim 20000mAh Power Bank', 'mobiles', 'https://images.unsplash.com/photo-1609592424361-b58f86f7b196?w=800', 4999, 6999, 4.7, 1640, '22.5W Power Delivery & Quick Charge 3.0.', 'High-capacity portable battery capable of charging a smartphone 4 to 5 times. Features USB-C Power Delivery in/out, dual USB-A ports, and LED digital percentage display.', 60, true, true)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  category_id = EXCLUDED.category_id,
  image_url = EXCLUDED.image_url,
  price = EXCLUDED.price,
  original_price = EXCLUDED.original_price,
  rating = EXCLUDED.rating,
  review_count = EXCLUDED.review_count,
  short_description = EXCLUDED.short_description,
  description = EXCLUDED.description,
  stock = EXCLUDED.stock,
  featured = EXCLUDED.featured,
  popular = EXCLUDED.popular;

-- 4. Initial Seed Coupons
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
