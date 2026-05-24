-- ============================================================
-- YETI SMART RETAIL - FULL DATABASE SCHEMA
-- Jalankan di Supabase SQL Editor (project baru)
-- ============================================================

-- 1. Aktifkan extension yang dibutuhkan
-- PENTING: Jika gagal, aktifkan manual di Dashboard > Database > Extensions > cari "vector" > Enable
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA extensions;

-- ============================================================
-- 2. TABEL: profiles
-- ============================================================
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  role TEXT NOT NULL DEFAULT 'customer',  -- 'admin' atau 'customer'
  phone TEXT,
  address TEXT,
  gender TEXT,
  dob TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger: Auto-create profile saat user baru sign up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
    'customer'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 3. TABEL: categories
-- ============================================================
CREATE TABLE public.categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE
);

-- Seed data kategori
INSERT INTO public.categories (name) VALUES
  ('Sembako'),
  ('Minyak'),
  ('Mie Instan'),
  ('Bumbu'),
  ('Susu'),
  ('Snack'),
  ('Minuman'),
  ('Kebut. Rumah'),
  ('Produk Online'),
  ('Lainnya'),
  ('Air Mineral'),
  ('Detergen & Laundry'),
  ('Frozen Food'),
  ('Kopi'),
  ('Makanan Kaleng'),
  ('Minuman Serbuk'),
  ('Minuman Siap Minum'),
  ('Pasta Gigi & Sikat Gigi'),
  ('Produk Bayi'),
  ('Sabun & Personal Care'),
  ('Snack & Biskuit')
ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- 4. TABEL: products
-- ============================================================
CREATE TABLE public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  price NUMERIC NOT NULL DEFAULT 0,
  stock INTEGER NOT NULL DEFAULT 0,
  category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
  image_url TEXT,
  embedding VECTOR(384),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 5. TABEL: orders
-- ============================================================
CREATE TABLE public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  total_amount NUMERIC NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending',  -- pending, diantar, selesai, cancelled
  lat_location DOUBLE PRECISION,
  lng_location DOUBLE PRECISION,
  address TEXT,
  items JSONB,  -- [{product_id, name, price, image_url, quantity}]
  payment_receipt_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 6. TABEL: carts
-- ============================================================
CREATE TABLE public.carts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL DEFAULT 1,
  UNIQUE(user_id, product_id)
);

-- ============================================================
-- 7. RPC FUNCTION: get_similar_products (AI Search)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_similar_products(
  query_embedding VECTOR(384),
  match_threshold FLOAT DEFAULT 0.70,
  match_count INT DEFAULT 50
)
RETURNS SETOF public.products
LANGUAGE sql STABLE
AS $$
  SELECT *
  FROM public.products
  WHERE embedding IS NOT NULL
    AND 1 - (embedding <=> query_embedding) >= match_threshold
  ORDER BY embedding <=> query_embedding
  LIMIT match_count;
$$;

-- ============================================================
-- 8. ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.carts ENABLE ROW LEVEL SECURITY;

-- Helper function: cek apakah user adalah admin (SECURITY DEFINER = bypass RLS)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  );
$$;

-- ---- PROFILES ----
-- User bisa baca profil sendiri
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

-- Admin bisa baca semua profil (pakai function, tidak recursive)
CREATE POLICY "Admin can view all profiles"
  ON public.profiles FOR SELECT
  USING (public.is_admin());

-- User bisa update profil sendiri
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- ---- CATEGORIES ----
-- Semua user bisa baca kategori
CREATE POLICY "Public read categories"
  ON public.categories FOR SELECT
  USING (true);

-- Admin bisa manage kategori
CREATE POLICY "Admin can manage categories"
  ON public.categories FOR ALL
  USING (public.is_admin());

-- ---- PRODUCTS ----
-- Semua user bisa baca produk
CREATE POLICY "Public read products"
  ON public.products FOR SELECT
  USING (true);

-- Admin bisa insert/update/delete produk
CREATE POLICY "Admin can manage products"
  ON public.products FOR ALL
  USING (public.is_admin());

-- ---- ORDERS ----
-- Customer bisa baca pesanan sendiri
CREATE POLICY "Customers can view own orders"
  ON public.orders FOR SELECT
  USING (auth.uid() = customer_id);

-- Admin bisa baca semua pesanan
CREATE POLICY "Admin can view all orders"
  ON public.orders FOR SELECT
  USING (public.is_admin());

-- Customer bisa buat pesanan
CREATE POLICY "Customers can create orders"
  ON public.orders FOR INSERT
  WITH CHECK (auth.uid() = customer_id);

-- Customer bisa update pesanan sendiri (cancel)
CREATE POLICY "Customers can update own orders"
  ON public.orders FOR UPDATE
  USING (auth.uid() = customer_id);

-- Admin bisa update semua pesanan (ubah status)
CREATE POLICY "Admin can update all orders"
  ON public.orders FOR UPDATE
  USING (public.is_admin());

-- ---- CARTS ----
-- User hanya bisa akses cart sendiri
CREATE POLICY "Users can manage own cart"
  ON public.carts FOR ALL
  USING (auth.uid() = user_id);

-- ============================================================
-- 9. STORAGE BUCKETS (buat manual di Dashboard atau jalankan ini)
-- ============================================================
-- Catatan: SQL di bawah ini mungkin perlu dijalankan terpisah
-- atau dibuat manual via Dashboard Supabase > Storage

INSERT INTO storage.buckets (id, name, public) VALUES ('product-images', 'product-images', true);
INSERT INTO storage.buckets (id, name, public) VALUES ('receipts', 'receipts', true);
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true);

-- Storage policies: allow authenticated users to upload
CREATE POLICY "Authenticated users can upload product images"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'product-images' AND auth.role() = 'authenticated');

CREATE POLICY "Public can view product images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'product-images');

CREATE POLICY "Authenticated users can upload receipts"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'receipts' AND auth.role() = 'authenticated');

CREATE POLICY "Public can view receipts"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'receipts');

CREATE POLICY "Authenticated users can upload avatars"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'avatars' AND auth.role() = 'authenticated');

CREATE POLICY "Public can view avatars"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

-- ============================================================
-- SELESAI! Database siap digunakan.
-- ============================================================

-- ============================================================
-- 10. TABEL: order_chats (Chat per pesanan)
-- ============================================================
CREATE TABLE public.order_chats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  is_admin BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.order_chats ENABLE ROW LEVEL SECURITY;

-- Customer bisa baca/kirim chat di pesanan miliknya
CREATE POLICY "Customer can read own order chats"
  ON public.order_chats FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.orders WHERE id = order_id AND customer_id = auth.uid())
  );

CREATE POLICY "Customer can send chat on own order"
  ON public.order_chats FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (SELECT 1 FROM public.orders WHERE id = order_id AND customer_id = auth.uid())
  );

-- Admin bisa baca/kirim semua chat
CREATE POLICY "Admin can read all order chats"
  ON public.order_chats FOR SELECT
  USING (public.is_admin());

CREATE POLICY "Admin can send chat"
  ON public.order_chats FOR INSERT
  WITH CHECK (auth.uid() = sender_id AND public.is_admin());

-- Grant access
GRANT SELECT, INSERT ON public.order_chats TO authenticated;

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.order_chats;
