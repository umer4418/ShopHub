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
  status TEXT NOT NULL DEFAULT 'placed',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ==============================================================================
-- Row Level Security (RLS) Policies
-- ==============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

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

-- ==============================================================================
-- Seed Data (Initial Categories & Products)
-- ==============================================================================

INSERT INTO public.categories (id, name, icon, image_url) VALUES
('electronics', 'Electronics', 'devices', 'assets/images/categories/electronics.png'),
('fashion', 'Fashion', 'checkroom', 'assets/images/categories/fashion.png'),
('home', 'Home & Living', 'chair', 'assets/images/categories/home.png'),
('beauty', 'Beauty & Health', 'spa', 'assets/images/categories/beauty.png'),
('sports', 'Sports & Outdoor', 'sports_soccer', 'assets/images/categories/sports.png'),
('groceries', 'Groceries', 'shopping_basket', 'assets/images/categories/groceries.png'),
('baby', 'Baby & Toys', 'child_care', 'assets/images/categories/baby.png'),
('phones', 'Mobile Phones', 'smartphone', 'assets/images/categories/phones.png')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.products (id, name, category_id, image_url, price, original_price, rating, review_count, short_description, description, stock, featured, popular) VALUES
('p1', 'Ultra Wireless ANC Headphones Pro', 'electronics', 'assets/images/products/headphones.png', 12499, 16999, 4.8, 412, 'Active noise cancelling headphones with 40h battery.', 'Premium over-ear wireless headphones featuring industry-leading active noise cancellation, high-resolution audio drivers, transparency mode, and ultra-soft memory foam ear cushions. Up to 40 hours of battery life on a single charge with USB-C fast charging.', 25, true, true),
('p2', 'Pro Series Smart Watch AMOLED', 'electronics', 'assets/images/products/smartwatch.png', 8999, 12999, 4.6, 289, '1.43-inch AMOLED display with Bluetooth calling & SpO2.', 'Stay connected in style. Features crisp AMOLED always-on display, heart rate and blood oxygen monitoring, 100+ sports modes, waterproof zinc-alloy body, and 7-day battery life.', 40, true, true),
('p3', 'Mechanical RGB Gaming Keyboard', 'electronics', 'assets/images/products/keyboard.png', 6499, 8499, 4.7, 198, 'Hot-swappable tactile switches with customizable RGB.', 'Compact mechanical keyboard built for gamers and typists. Features hot-swappable switches, sound dampening foam, per-key RGB backlighting, and braided detachable USB-C cable.', 18, true, false),
('p4', 'True Wireless Earbuds with BassBoost', 'electronics', 'assets/images/products/earbuds.png', 3999, 5999, 4.5, 630, 'Deep bass, environmental noise reduction, 30h playtime.', 'Ergonomic in-ear earbuds with 10mm dynamic drivers delivering punchy bass and crystal clear vocals. IPX5 water resistance for workouts and rain.', 55, false, true),
('p5', 'Classic Oxford Cotton Casual Shirt', 'fashion', 'assets/images/products/shirt.png', 2499, 3499, 4.4, 87, '100% breathable combed cotton, tailored regular fit.', 'Versatile button-down casual shirt crafted from premium breathable combed cotton. Perfect for office wear or weekend gatherings. Easy iron and machine washable.', 60, true, false),
('p6', 'Ergonomic Mesh Office Chair', 'home', 'assets/images/products/chair.png', 18999, 24999, 4.7, 94, 'Breathable mesh back with adjustable lumbar support.', 'High-back ergonomic executive office chair with dynamic lumbar support, 3D armrests, heavy-duty nylon base, and 135-degree recline locking mechanism.', 12, true, true),
('p7', 'Hydrating Vitamin C Facial Serum', 'beauty', 'assets/images/products/serum.png', 1899, 2699, 4.6, 340, 'Brightening and anti-aging serum with hyaluronic acid.', 'Dermatologist tested facial serum packed with pure Vitamin C, Vitamin E, and hyaluronic acid to fade dark spots, boost radiance, and even skin tone.', 85, true, false),
('p8', 'Smart Flagship 5G Smartphone 256GB', 'phones', 'assets/images/products/phone.png', 89999, 99999, 4.9, 510, '120Hz AMOLED, 50MP OIS triple camera, 67W Turbo Charge.', 'Next-generation 5G flagship smartphone boasting vivid 6.67-inch AMOLED display, flagship octa-core processor, professional-grade 50MP camera, and 5000mAh battery with 67W turbo charge.', 15, true, true)
ON CONFLICT (id) DO NOTHING;
