# 📋 REKAP PENGEMBANGAN - Yeti Smart Retail
## Dokumen ini berisi semua perubahan, konfigurasi, dan hal penting untuk melanjutkan pengembangan

---

## 🔗 INFORMASI PROJECT

| Item | Detail |
|------|--------|
| **Nama Project** | Yeti Smart Retail |
| **GitHub Repo** | https://github.com/fikri-wq/fikri_retail.git |
| **GitHub User** | fikri-wq (email: tongwuan14@gmail.com) |
| **Vercel URL** | https://fikri-retail.vercel.app |
| **Supabase Project** | kboyrjpizxbdudglcwcd |
| **Supabase URL** | https://kboyrjpizxbdudglcwcd.supabase.co |
| **Flutter** | Dart SDK ^3.7.2 |

---

## ⚠️ PENTING: CARA DEPLOY KE VERCEL

Vercel **TIDAK bisa build Flutter** sendiri. Jadi setiap ada perubahan kode:

```bash
# 1. Build Flutter Web dulu (lokal)
flutter build web --release

# 2. Commit semua termasuk build/web
git add -A
git commit -m "pesan commit"
git push
```

Vercel otomatis deploy setelah push ke branch `main`.

---

## 🗄️ SUPABASE - SQL YANG WAJIB DIJALANKAN

Jika membuat database baru, jalankan semua SQL di file `supabase_schema.sql` ditambah SQL berikut:

### 1. Grant Permissions
```sql
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.products TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.categories TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.orders TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.carts TO authenticated;
GRANT SELECT ON public.products TO anon;
GRANT SELECT ON public.categories TO anon;
GRANT SELECT ON public.orders TO anon;
GRANT SELECT ON public.order_chats TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO anon;
```

### 2. Fix RLS Infinite Recursion
```sql
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  );
$$;
```

### 3. Policy untuk profiles (baca oleh semua authenticated)
```sql
CREATE POLICY "Authenticated can read profiles"
  ON public.profiles FOR SELECT
  USING (auth.role() = 'authenticated');
```

### 4. Fungsi Kurangi Stok (bypass RLS)
```sql
CREATE OR REPLACE FUNCTION public.decrement_product_stock(
  p_product_id UUID,
  p_quantity INT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.products
  SET stock = GREATEST(0, stock - p_quantity)
  WHERE id = p_product_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.decrement_product_stock TO authenticated;
```

### 5. Enable Realtime
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.order_chats;
```

### 6. Kategori Default
```sql
INSERT INTO public.categories (name) VALUES
  ('Sembako'), ('Minyak'), ('Mie Instan'), ('Bumbu'),
  ('Susu'), ('Snack'), ('Minuman'), ('Kebut. Rumah'),
  ('Produk Online'), ('Lainnya'), ('Air Mineral'),
  ('Detergen & Laundry'), ('Frozen Food'), ('Kopi'),
  ('Makanan Kaleng'), ('Minuman Serbuk'), ('Minuman Siap Minum'),
  ('Pasta Gigi & Sikat Gigi'), ('Produk Bayi'), ('Sabun & Personal Care'),
  ('Snack & Biskuit')
ON CONFLICT (name) DO NOTHING;
```

### 7. Buat Profile Admin Manual
```sql
-- Ganti UUID dengan ID user admin dari Authentication > Users
INSERT INTO public.profiles (id, full_name, role)
VALUES ('UUID-ADMIN-DISINI', 'TokoRetail', 'admin')
ON CONFLICT (id) DO UPDATE SET role = 'admin';
```

### 8. Supabase Storage Buckets
Buat manual di Dashboard > Storage:
- `product-images` (public)
- `receipts` (public)
- `avatars` (public)

---

## 📁 STRUKTUR FILE PENTING

```
fikriretailproject/
├── lib/
│   ├── main.dart                    ← Theme + AppColors + WaveBackground
│   ├── features/
│   │   ├── auth/
│   │   │   ├── auth_screen.dart     ← Login/Register
│   │   │   ├── auth_gate.dart       ← Routing by role
│   │   │   ├── forgot_password_screen.dart
│   │   │   └── verify_otp_screen.dart
│   │   ├── admin/
│   │   │   └── admin_dashboard.dart ← Kelola produk, pesanan, laporan
│   │   ├── shop/
│   │   │   ├── home_screen.dart     ← Beranda customer
│   │   │   ├── product_detail_screen.dart
│   │   │   ├── cart_screen.dart     ← Keranjang + AI rekomendasi
│   │   │   ├── main_screen.dart     ← Bottom nav + badge notif
│   │   │   ├── filter_provider.dart ← Search + kategori
│   │   │   └── product_provider.dart
│   │   ├── order/
│   │   │   ├── checkout_screen.dart ← Checkout + GPS + pembayaran
│   │   │   ├── customer_orders_screen.dart
│   │   │   ├── order_chat_screen.dart ← Chat realtime per pesanan
│   │   │   └── order_provider.dart  ← Realtime StreamProvider
│   │   └── profile/
│   │       └── profile_screen.dart
│   ├── models/
│   │   ├── product_model.dart
│   │   └── order_model.dart
│   ├── services/
│   │   ├── supabase_service.dart
│   │   ├── auth_service.dart
│   │   ├── storage_service.dart
│   │   └── location_service.dart
│   ├── seed_data.dart               ← 43 produk lama (dengan embedding)
│   └── seed_data_new.dart           ← 414 produk baru (tanpa embedding)
├── supabase/
│   └── functions/
│       └── generate-embedding/
│           └── index.ts             ← Edge Function AI embedding
├── assets/
│   ├── LOGO.png
│   ├── iklan*.jpg                   ← Banner promo
│   └── products/                   ← 414 gambar produk
├── build/web/                       ← Flutter Web build (yang di-deploy)
├── vercel.json                      ← Konfigurasi Vercel
├── supabase_schema.sql              ← Skema lengkap database
├── HANDBOOK_SIDANG.html             ← Panduan sidang visual
└── COSINE_SIMILARITY.html           ← Penjelasan algoritma AI
```

---

## 🎨 TEMA & WARNA (AppColors di main.dart)

```dart
// BY.U Style - Cyan/Blue
primary = Color(0xFF00B8E6)      // Cyan utama
primaryDark = Color(0xFF0288D1)  // Cyan gelap
primaryLight = Color(0xFF40C8E8) // Cyan muda
primaryPale = Color(0xFFE0F7FA)  // Background input
accent = Color(0xFFFFC107)       // Kuning
pink = Color(0xFFFF6B9D)         // Pink
background = Color(0xFFF0FAFE)   // Background app
```

Font: **Poppins** (Google Fonts)

---

## 🚀 FITUR YANG SUDAH ADA

### Customer Side
- [x] Login / Register
- [x] Lupa Password (OTP via email)
- [x] Beranda dengan banner auto-scroll
- [x] Pencarian produk (AI Cosine Similarity)
- [x] Filter kategori
- [x] Keranjang belanja (+ rekomendasi AI)
- [x] Checkout (GPS lokasi + nama tempat)
- [x] Upload bukti pembayaran
- [x] Status pesanan realtime (WebSocket)
- [x] Tab: Diproses / Dikirim / Selesai
- [x] Chat per pesanan (realtime)
- [x] Badge merah notifikasi chat
- [x] Profil user (edit nama, foto, dll)
- [x] Stok berkurang otomatis saat checkout

### Admin Side
- [x] Kelola produk (CRUD + AI embedding)
- [x] Auto-detect kategori dari nama produk
- [x] Upload gambar produk ke Supabase Storage
- [x] Seed database (43 + 414 produk)
- [x] Daftar pesanan realtime
- [x] Tab: Hari Ini & Aktif / Laporan Bulanan
- [x] Ubah status pesanan (Pending → Shipped → Delivered)
- [x] GPS tracking (Buka Maps)
- [x] Chat per pesanan dengan customer
- [x] Laporan bulanan (download CSV)
- [x] Pesanan selesai otomatis hilang dari tab aktif

---

## 🔧 YANG MASIH PERLU DICEK / TODO

- [ ] Nama customer masih "Unknown" di pesanan admin → **Solusi:** RLS policy profiles harus ada: `CREATE POLICY "Authenticated can read profiles" ON public.profiles FOR SELECT USING (auth.role() = 'authenticated');`
- [ ] Badge merah bottom nav pesanan → **Solusi:** SQL grant: `GRANT SELECT ON public.orders TO anon;`
- [ ] Stok tidak berkurang → **Solusi:** SQL function `decrement_product_stock` harus dibuat
- [ ] AI Search tidak bekerja → **Solusi:** Deploy edge function `generate-embedding` ke Supabase

---

## 📦 CARA SEED DATABASE

1. Login sebagai admin di app
2. Buka halaman **Kelola Produk**
3. Klik ikon ☁️ (cloud upload) di AppBar kanan atas
4. Tunggu proses (bisa 5-10 menit untuk 414 produk)

---

## 🤖 EDGE FUNCTION AI

File: `supabase/functions/generate-embedding/index.ts`

Deploy:
```bash
npx supabase login --token YOUR_TOKEN
npx supabase link --project-ref kboyrjpizxbdudglcwcd
npx supabase functions deploy generate-embedding --project-ref kboyrjpizxbdudglcwcd --no-verify-jwt
```

---

## 💡 CATATAN PENTING

1. **Vercel serve `build/web`** — selalu rebuild sebelum push jika ada perubahan UI
2. **Supabase Free plan** limit 2 email/jam — matikan "Confirm email" untuk dev
3. **Realtime WebSocket** kadang terputus saat tab lama tidak aktif → app auto-reconnect
4. **RLS harus diset** dengan benar agar query tidak di-block
5. **`is_admin()` function** dengan SECURITY DEFINER mencegah infinite recursion di RLS

---

*Dibuat: Juni 2026 | Commit terakhir: 511d6c9*
