# 📘 HANDBOOK SIDANG - Yeti Smart Retail
## Panduan Lengkap Logika & Algoritma Sistem

---

## 1. ARSITEKTUR SISTEM

### 1.1 Tech Stack
| Layer | Teknologi |
|-------|-----------|
| Frontend | Flutter (Dart) - Cross-platform (Web, Android, iOS) |
| State Management | Riverpod (hooks_riverpod) |
| Backend | Supabase (PostgreSQL + Auth + Storage + Realtime + Edge Functions) |
| AI/ML | Supabase AI (model gte-small, 384 dimensi) |
| Hosting | Vercel (Flutter Web) |
| Maps | Google Maps Flutter + Geolocator + Geocoding |

### 1.2 Pola Arsitektur
```
┌─────────────────────────────────────────────┐
│              FLUTTER APP (Client)            │
│  ┌─────────┐  ┌──────────┐  ┌───────────┐  │
│  │   UI    │  │ Provider │  │  Service  │  │
│  │(Screens)│◄─┤(Riverpod)│◄─┤(Supabase) │  │
│  └─────────┘  └──────────┘  └───────────┘  │
└──────────────────────┬──────────────────────┘
                       │ HTTPS / WebSocket
┌──────────────────────▼──────────────────────┐
│              SUPABASE (Backend)              │
│  ┌──────┐ ┌────────┐ ┌────────┐ ┌───────┐  │
│  │ Auth │ │Database│ │Storage │ │Realtime│  │
│  └──────┘ └────────┘ └────────┘ └───────┘  │
│  ┌──────────────┐  ┌─────────────────────┐  │
│  │Edge Functions│  │ Row Level Security  │  │
│  └──────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────┘
```

---

## 2. DATABASE SCHEMA

### 2.1 Entity Relationship Diagram
```
auth.users (Supabase Auth)
    │
    ├── 1:1 ──► profiles (id = auth.users.id)
    │              - full_name, role, phone, address, avatar_url
    │
    ├── 1:N ──► orders (customer_id)
    │              - total_amount, status, lat/lng, items (JSONB)
    │              │
    │              └── 1:N ──► order_chats (order_id)
    │                            - message, is_admin, sender_id
    │
    └── 1:N ──► carts (user_id)
                   │
                   └── N:1 ──► products (product_id)
                                  - name, price, stock, embedding VECTOR(384)
                                  │
                                  └── N:1 ──► categories (category_id)
```

### 2.2 Tabel Utama

| Tabel | Fungsi | Kolom Penting |
|-------|--------|---------------|
| profiles | Data user | id, full_name, role ('admin'/'customer') |
| products | Katalog produk | name, price, stock, category_id, embedding |
| categories | Kategori produk | name |
| orders | Pesanan | customer_id, status, items (JSON), lat/lng |
| carts | Keranjang | user_id, product_id, quantity |
| order_chats | Chat pesanan | order_id, sender_id, message, is_admin |

---

## 3. ALGORITMA & LOGIKA UTAMA

### 3.1 AI Product Search (Cosine Similarity)

**Konsep:** Setiap produk memiliki vektor embedding 384 dimensi yang merepresentasikan makna semantik dari nama + deskripsi produk.

**Proses:**
1. Saat produk ditambahkan → nama + deskripsi dikirim ke Edge Function `generate-embedding`
2. Edge Function menggunakan model AI `gte-small` untuk menghasilkan vektor 384 dimensi
3. Vektor disimpan di kolom `embedding` (tipe VECTOR)
4. Saat user mencari → query diubah jadi vektor → dicari produk dengan cosine similarity tertinggi

**Rumus Cosine Similarity:**
```
similarity = 1 - (embedding <=> query_embedding)

dimana <=> adalah operator jarak cosine di pgvector
```

**SQL Function:**
```sql
CREATE FUNCTION get_similar_products(
  query_embedding VECTOR(384),
  match_threshold FLOAT DEFAULT 0.70,
  match_count INT DEFAULT 50
) RETURNS SETOF products AS $$
  SELECT * FROM products
  WHERE embedding IS NOT NULL
    AND 1 - (embedding <=> query_embedding) >= match_threshold
  ORDER BY embedding <=> query_embedding
  LIMIT match_count;
$$;
```

**Keunggulan vs keyword search:**
- "mie goreng" bisa menemukan "Indomie", "Sarimi", "Pop Mie" (semantik)
- Typo-tolerant: "indomi" tetap menemukan "Indomie"
- Cross-language: bisa cari dengan sinonim

### 3.2 Rekomendasi Produk (Cart-based Similarity)

**Algoritma:**
1. Ambil semua produk di keranjang user
2. Hitung rata-rata embedding dari produk-produk tersebut (centroid)
3. Cari produk lain yang paling mirip dengan centroid menggunakan cosine similarity
4. Tampilkan top-20 produk terdekat (exclude yang sudah di keranjang)

**Pseudocode:**
```
centroid = average(embeddings of cart items)
recommendations = get_similar_products(centroid, threshold=0.70, limit=20)
recommendations = filter out products already in cart
```

### 3.3 Auto-Detect Kategori Produk

**Algoritma:** Rule-based keyword matching saat admin menambah produk.

```dart
String? detectCategory(String productName) {
  final name = productName.toLowerCase();
  if (name.contains('bimoli') || name.contains('minyak')) return 'Minyak';
  if (name.contains('indomie') || name.contains('sarimi')) return 'Mie Instan';
  if (name.contains('susu') || name.contains('dancow')) return 'Susu';
  // ... dst
  return null;
}
```

**Cara kerja di UI:**
- Admin ketik nama produk → `onChanged` trigger deteksi
- Dropdown kategori otomatis terisi
- Admin masih bisa override manual

### 3.4 Realtime Order Status (WebSocket)

**Teknologi:** Supabase Realtime (PostgreSQL LISTEN/NOTIFY via WebSocket)

**Alur:**
```
Admin ubah status ──► UPDATE orders SET status='shipped'
                              │
                              ▼
              PostgreSQL trigger NOTIFY
                              │
                              ▼
              Supabase Realtime broadcast via WebSocket
                              │
                              ▼
              Customer app StreamProvider menerima update
                              │
                              ▼
              UI otomatis rebuild (pesanan pindah tab)
```

**Implementasi (Riverpod StreamProvider):**
```dart
final customerOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  return SupabaseService.client
      .from('orders')
      .stream(primaryKey: ['id'])
      .eq('customer_id', user.id)
      .order('created_at', ascending: false)
      .map((data) => data.map((e) => OrderModel.fromMap(e)).toList());
});
```

### 3.5 Realtime Chat (WebSocket)

**Alur:**
1. User kirim pesan → INSERT ke `order_chats`
2. Supabase Realtime broadcast ke semua subscriber
3. Pihak lain (admin/customer) langsung melihat pesan baru
4. Badge merah muncul otomatis

**Stream per order:**
```dart
_chatStream = SupabaseService.client
    .from('order_chats')
    .stream(primaryKey: ['id'])
    .eq('order_id', orderId)
    .order('created_at', ascending: true);
```

### 3.6 Row Level Security (RLS)

**Konsep:** Setiap query ke database difilter berdasarkan siapa yang meminta.

**Contoh Policy:**
```sql
-- Customer hanya bisa lihat pesanan sendiri
CREATE POLICY "Customers can view own orders"
  ON orders FOR SELECT
  USING (auth.uid() = customer_id);

-- Admin bisa lihat semua (pakai SECURITY DEFINER function)
CREATE POLICY "Admin can view all orders"
  ON orders FOR SELECT
  USING (public.is_admin());
```

**Function is_admin() (menghindari infinite recursion):**
```sql
CREATE FUNCTION is_admin() RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
  );
$$;
```

### 3.7 GPS Location + Reverse Geocoding

**Alur checkout delivery:**
1. User klik "Titik Jemput" → `geolocator` ambil koordinat GPS
2. Koordinat dikirim ke **Nominatim API** (OpenStreetMap)
3. API mengembalikan nama tempat terdekat (POI)
4. Tampilkan nama tempat (bukan koordinat) di UI
5. Koordinat tetap disimpan di database untuk navigasi admin

**Prioritas hasil geocoding:**
```
1. Nama POI (Kosan Pak Agus, Warung Bu Tini)
2. Alamat jalan (Jl. Cibiru No. 5)
3. Fallback: koordinat GPS
```

### 3.8 Keranjang Belanja (Cart Logic)

**Algoritma add to cart:**
```dart
Future<void> addToCart(String productId) async {
  // Cek apakah produk sudah ada di keranjang
  final existing = await supabase
      .from('carts')
      .select()
      .eq('user_id', userId)
      .eq('product_id', productId)
      .maybeSingle();

  if (existing != null) {
    // Sudah ada → increment quantity
    await supabase.from('carts')
        .update({'quantity': existing['quantity'] + 1})
        .eq('id', existing['id']);
  } else {
    // Belum ada → insert baru
    await supabase.from('carts').insert({
      'user_id': userId,
      'product_id': productId,
      'quantity': 1,
    });
  }
}
```

### 3.9 Authentication Flow

**Sign Up:**
```
User input (nama, email, password)
    → Supabase Auth signUp()
    → Trigger handle_new_user() di PostgreSQL
    → Auto-create row di profiles (role = 'customer')
    → User bisa login
```

**Login:**
```
User input (email, password)
    → Supabase Auth signIn()
    → Ambil role dari profiles
    → role == 'admin' → AdminDashboard
    → role == 'customer' → MainScreen (Home)
```

**Reset Password:**
```
User input email → resetPasswordForEmail()
    → Supabase kirim OTP ke email
    → User input OTP + password baru
    → verifyOTP(type: recovery) → updateUser(password)
    → signOut() → kembali ke login
```

---

## 4. STATE MANAGEMENT (Riverpod)

### 4.1 Provider Types yang Digunakan

| Provider | Kegunaan | Contoh |
|----------|----------|--------|
| FutureProvider | Data sekali fetch | productsProvider |
| StreamProvider | Data realtime | customerOrdersProvider, adminOrdersProvider |
| StateProvider | State sederhana | searchQueryProvider, selectedCategoryProvider |
| Provider | Computed/derived | filteredProductsProvider |

### 4.2 Data Flow
```
UI (Widget)
    │ ref.watch(provider)
    ▼
Provider (Riverpod)
    │ fetch/stream dari Supabase
    ▼
Service Layer (SupabaseService)
    │ HTTP/WebSocket
    ▼
Supabase Backend
```

---

## 5. FITUR-FITUR UTAMA

| No | Fitur | Teknologi |
|----|-------|-----------|
| 1 | Login/Register | Supabase Auth |
| 2 | Reset Password (OTP) | Supabase Auth + Email |
| 3 | Katalog Produk | PostgreSQL + Flutter Grid |
| 4 | Pencarian AI | pgvector + Cosine Similarity |
| 5 | Rekomendasi Produk | Embedding centroid + similarity |
| 6 | Keranjang Belanja | CRUD carts table |
| 7 | Checkout + GPS | Geolocator + Nominatim |
| 8 | Pembayaran (upload bukti) | Supabase Storage |
| 9 | Status Pesanan Realtime | Supabase Realtime (WebSocket) |
| 10 | Chat Pesanan Realtime | Supabase Realtime + StreamBuilder |
| 11 | Notifikasi Badge | Stream + unread detection |
| 12 | Admin: Kelola Produk | CRUD + AI Embedding |
| 13 | Admin: Kelola Pesanan | Update status + GPS tracking |
| 14 | Auto-detect Kategori | Rule-based keyword matching |
| 15 | Profil User | Auth metadata + profiles table |

---

## 6. KEAMANAN

| Aspek | Implementasi |
|-------|-------------|
| Authentication | Supabase Auth (JWT token) |
| Authorization | Row Level Security (RLS) per tabel |
| Admin check | SECURITY DEFINER function (is_admin) |
| Data isolation | Customer hanya akses data sendiri |
| Password | Hashed by Supabase (bcrypt) |
| API Key | Anon key (public, safe for client) |

---

## 7. DEPLOYMENT

### 7.1 Flutter Web → Vercel
```
flutter build web --release
    → Output: build/web/
    → Push ke GitHub
    → Vercel auto-deploy dari GitHub
```

### 7.2 Supabase Edge Function
```
npx supabase functions deploy generate-embedding
    → Deno runtime
    → Model AI: gte-small (384 dimensi)
    → Endpoint: /functions/v1/generate-embedding
```

---

## 8. PERTANYAAN SIDANG YANG MUNGKIN DITANYAKAN

### Q: Apa itu Cosine Similarity dan kenapa dipakai?
**A:** Cosine Similarity mengukur kesamaan arah antara dua vektor, menghasilkan nilai 0-1. Dipakai karena:
- Tidak terpengaruh panjang teks (normalized)
- Cocok untuk high-dimensional data (384 dimensi)
- Lebih akurat dari keyword matching untuk pencarian semantik

### Q: Kenapa pakai Supabase, bukan Firebase?
**A:** 
- Supabase berbasis PostgreSQL (relational, SQL, JOIN)
- Built-in pgvector untuk AI/ML
- Row Level Security lebih granular
- Realtime native
- Open source

### Q: Bagaimana Realtime bekerja?
**A:** Supabase menggunakan PostgreSQL LISTEN/NOTIFY + WebSocket. Saat ada INSERT/UPDATE/DELETE, PostgreSQL mengirim notifikasi ke Supabase Realtime server, yang kemudian broadcast ke semua client yang subscribe via WebSocket.

### Q: Apa perbedaan FutureProvider dan StreamProvider?
**A:**
- FutureProvider: fetch data sekali, perlu manual refresh (invalidate)
- StreamProvider: listen terus-menerus, auto-update saat data berubah

### Q: Bagaimana RLS mencegah akses tidak sah?
**A:** Setiap query yang masuk ke PostgreSQL otomatis difilter oleh policy. Contoh: customer A tidak bisa melihat pesanan customer B karena policy `USING (auth.uid() = customer_id)` memastikan hanya row milik user yang login yang dikembalikan.

### Q: Kenapa embedding 384 dimensi?
**A:** Model gte-small menghasilkan vektor 384 dimensi. Ini balance antara akurasi dan performa — cukup detail untuk menangkap makna semantik teks pendek (nama produk), tapi tidak terlalu besar sehingga query tetap cepat.

### Q: Bagaimana auto-scroll banner bekerja?
**A:** Menggunakan `PageController` + recursive `Future.delayed` setiap 3 detik yang memanggil `animateToPage()`. Saat mencapai halaman terakhir, reset ke halaman pertama.

---

## 9. DIAGRAM ALUR (FLOWCHART)

### 9.1 Alur Pemesanan
```
Customer buka app
    → Login
    → Browse produk / Search (AI)
    → Tambah ke keranjang
    → Checkout
    → Pilih metode (Delivery/Pick Up)
    → Jika Delivery: ambil GPS → reverse geocoding
    → Pilih pembayaran
    → Upload bukti transfer
    → Buat pesanan (INSERT orders)
    → Status: PENDING
    
Admin terima pesanan (realtime)
    → Proses pesanan → status: SHIPPED
    → Customer otomatis lihat update (realtime)
    → Admin kirim → status: DELIVERED
    → Selesai
```

### 9.2 Alur Chat
```
Customer/Admin buka chat pesanan
    → Stream order_chats WHERE order_id = X
    → Ketik pesan → INSERT order_chats
    → Supabase broadcast via WebSocket
    → Pihak lain langsung lihat pesan baru
    → Badge merah muncul di tombol chat + bottom nav
```

---

*Dokumen ini dibuat sebagai panduan persiapan sidang skripsi untuk project Yeti Smart Retail.*
*Terakhir diperbarui: 24 Mei 2026*
