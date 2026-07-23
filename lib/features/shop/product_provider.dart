import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../../models/product_model.dart';
import '../../services/supabase_service.dart';

final productsProvider = FutureProvider<List<Product>>((ref) async {
  final response = await SupabaseService.client
      .from('products')
      .select()
      .order('created_at', ascending: false);

  return (response as List).map((e) => Product.fromMap(e)).toList();
});

// ─── Toggle: true = Cosine Similarity, false = Non-AI (Category + Price) ────
// State ini global — mengubah mode di satu tempat berlaku untuk semua layar
final useAIRecommendationProvider = StateProvider<bool>((ref) => true);

// ─── Helper: Hitung Cosine Similarity antara dua vektor ─────────────────────
double _cosineSimilarity(List<double> a, List<double> b) {
  double dotProduct = 0.0;
  double normA = 0.0;
  double normB = 0.0;
  final len = min(a.length, b.length);
  for (int i = 0; i < len; i++) {
    dotProduct += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA == 0 || normB == 0) return 0.0;
  return dotProduct / (sqrt(normA) * sqrt(normB));
}

// ─── Helper: Hitung Price Similarity (0.0 – 1.0) ────────────────────────────
// Rumus: 1 - (|harga_A - harga_B| / max(harga_A, harga_B))
double _priceSimilarity(double priceA, double priceB) {
  if (priceA <= 0 || priceB <= 0) return 0.5;
  final diff = (priceA - priceB).abs();
  final maxPrice = max(priceA, priceB);
  return 1.0 - (diff / maxPrice);
}

// ─── Helper: Combined Score AI (Semantic 70% + Price 30%) ───────────────────
double _combinedScore(
  List<double> embeddingA,
  List<double> embeddingB,
  double priceA,
  double priceB,
) {
  const double weightSemantic = 0.70;
  const double weightPrice = 0.30;
  final semanticScore = _cosineSimilarity(embeddingA, embeddingB);
  final priceScore = _priceSimilarity(priceA, priceB);
  return (semanticScore * weightSemantic) + (priceScore * weightPrice);
}

// ─── Provider AI: Cosine Similarity + Price Similarity ──────────────────────
final similarProductsProvider = FutureProvider.family<List<Product>, String>((
  ref,
  productId,
) async {
  final products = await ref.watch(productsProvider.future);
  final product = products.firstWhere((p) => p.id == productId);
  final embedding = product.embedding ?? List.filled(384, 0.0);
  final price = product.price;

  debugPrint('[AI Similar] Produk: ${product.name}, harga: ${product.price}, '
      'punya embedding: ${product.embedding != null}');

  try {
    final List<dynamic> response = await SupabaseService.client.rpc(
      'get_similar_products',
      params: {
        'query_embedding': embedding,
        'match_threshold': 0.70,
        'match_count': 50,
      },
    );

    debugPrint('[AI Similar] RPC berhasil → ${response.length} kandidat');

    List<Map<String, dynamic>> scoredProducts = [];
    for (var item in response) {
      final p = Product.fromMap(item);
      if (p.id == productId) continue;
      if (p.embedding == null || p.embedding!.isEmpty) continue;

      final score = _combinedScore(embedding, p.embedding!, price, p.price);
      scoredProducts.add({'product': p, 'score': score});
    }

    scoredProducts.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return scoredProducts.take(6).map((e) => e['product'] as Product).toList();
  } catch (e) {
    debugPrint('[AI Similar] RPC gagal: $e');
    return [];
  }
});

// ─── Helper: Deteksi kategori produk dari nama (untuk Non-AI fallback) ────────
// Digunakan saat category_id di DB adalah null (produk dari seed_data_new)
String _detectCategoryFromName(String name) {
  final n = name.toLowerCase();
  if (n.contains('aqua') || n.contains('cleo') || n.contains('club') || n.contains('le minerale') ||
      n.contains('vit') || n.contains('air mineral')) return 'Air Mineral';
  if (n.contains('indomie') || n.contains('mie sedap') || n.contains('sarimi') ||
      n.contains('supermi') || n.contains('pop mie') || n.contains('mie gaga')) return 'Mie Instan';
  if (n.contains('ultramil') || n.contains('indomilk') || n.contains('frisian') ||
      n.contains('dancow') || n.contains('sgm') || n.contains('milo') ||
      n.contains('bear brand') || n.contains('susu')) return 'Susu';
  if (n.contains('rinso') || n.contains('daia') || n.contains('attack') ||
      n.contains('so klin') || n.contains('downy') || n.contains('molto') ||
      n.contains('detergen') || n.contains('softener')) return 'Detergen & Laundry';
  if (n.contains('chitato') || n.contains('piattos') || n.contains('taro') ||
      n.contains('qtela') || n.contains('oreo') || n.contains('roma') ||
      n.contains('nabati') || n.contains('khong guan') || n.contains('snack') ||
      n.contains('biskuit') || n.contains('wafer')) return 'Snack & Biskuit';
  if (n.contains('coca') || n.contains('fanta') || n.contains('sprite') ||
      n.contains('pocari') || n.contains('mizone') || n.contains('teh botol') ||
      n.contains('teh pucuk') || n.contains('frestea') || n.contains('you c1000') ||
      n.contains('kratingdaeng')) return 'Minuman Siap Minum';
  if (n.contains('kapal api') || n.contains('nescafe') || n.contains('good day') ||
      n.contains('torabika') || n.contains('luwak') || n.contains('abc kopi')) return 'Kopi';
  if (n.contains('nutrisari') || n.contains('marimas') || n.contains('jasjus') ||
      n.contains('chocolatos') || n.contains('beng beng drink') || n.contains('minuman serbuk')) return 'Minuman Serbuk';
  if (n.contains('fiesta') || n.contains('so good') || n.contains('champ') ||
      n.contains('kanzler') || n.contains('bernardi') || n.contains('belfoods') ||
      n.contains('nugget') || n.contains('sosis') || n.contains('frozen')) return 'Frozen Food';
  if (n.contains('masako') || n.contains('royco') || n.contains('sajiku') ||
      n.contains('kobe') || n.contains('racik') || n.contains('bango') ||
      n.contains('abc') || n.contains('indofood') || n.contains('bumbu')) return 'Bumbu';
  if (n.contains('beras') || n.contains('gula') || n.contains('tepung') ||
      n.contains('garam') || n.contains('minyak') || n.contains('margarin')) return 'Sembako';
  if (n.contains('pepsodent') || n.contains('close up') || n.contains('formula') ||
      n.contains('sensodyne') || n.contains('oral-b') || n.contains('ciptadent') ||
      n.contains('pasta gigi') || n.contains('sikat gigi')) return 'Pasta Gigi & Sikat Gigi';
  if (n.contains('lifebuoy') || n.contains('dettol') || n.contains('dove') ||
      n.contains('lux') || n.contains('sunsilk') || n.contains('pantene') ||
      n.contains('clear') || n.contains('sabun') || n.contains('shampoo')) return 'Sabun & Personal Care';
  if (n.contains('mamypoko') || n.contains('merries') || n.contains('sweety') ||
      n.contains('johnsons') || n.contains('zwitsal') || n.contains('milna') ||
      n.contains('promina') || n.contains('bayi')) return 'Produk Bayi';
  if (n.contains('botan') || n.contains('pronas') || n.contains('quaker') ||
      n.contains('super bubur') || n.contains('kaleng')) return 'Makanan Kaleng';
  return 'Lainnya';
}

// ─── Provider Non-AI: Category-based + Price Proximity ──────────────────────
// Algoritma konvensional tanpa AI:
//   1. Tentukan kategori produk (dari categoryId DB, atau deteksi dari nama jika null)
//   2. Filter produk dengan kategori yang sama
//   3. Urutkan berdasarkan selisih harga terkecil (terdekat harganya)
//   4. Ambil 6 teratas
final similarProductsNonAIProvider = FutureProvider.family<List<Product>, String>((
  ref,
  productId,
) async {
  final products = await ref.watch(productsProvider.future);
  final product = products.firstWhere((p) => p.id == productId);

  // Tentukan kategori produk — pakai categoryId jika ada, fallback ke keyword detection
  final targetCategory = product.categoryId ?? _detectCategoryFromName(product.name);

  debugPrint('[Non-AI Similar] Produk: ${product.name}, kategori: $targetCategory');

  // Filter: kategori sama, bukan produk itu sendiri
  final candidates = products.where((p) {
    if (p.id == productId) return false;
    // Cek kecocokan kategori: via categoryId atau via keyword detection
    final pCategory = p.categoryId ?? _detectCategoryFromName(p.name);
    return pCategory == targetCategory;
  }).toList();

  // Urutkan berdasarkan selisih harga terkecil (price proximity)
  candidates.sort((a, b) {
    final diffA = (a.price - product.price).abs();
    final diffB = (b.price - product.price).abs();
    return diffA.compareTo(diffB);
  });

  debugPrint('[Non-AI Similar] ${candidates.length} kandidat dari kategori "$targetCategory"');
  return candidates.take(6).toList();
});

// ─── Provider AI: Rekomendasi Keranjang (Cosine Similarity + Price) ──────────
final cartRecommendationsProvider = FutureProvider.family<List<Product>, String>((
  ref,
  cartProductIdsJoined,
) async {
  if (cartProductIdsJoined.isEmpty) return [];

  final cartProductIds = cartProductIdsJoined.split(',');
  final products = await ref.watch(productsProvider.future);

  final List<List<double>> embeddings = [];
  final List<double> prices = [];

  for (final id in cartProductIds) {
    try {
      final product = products.firstWhere((p) => p.id == id);
      if (product.embedding != null && product.embedding!.isNotEmpty) {
        embeddings.add(product.embedding!);
        prices.add(product.price);
      }
    } catch (_) {
      continue;
    }
  }

  debugPrint('[AI Rekomendasi] Produk di keranjang: ${cartProductIds.length}, '
      'yang punya embedding: ${embeddings.length}');

  if (embeddings.isEmpty) {
    debugPrint('[AI Rekomendasi] Tidak ada embedding → skip RPC call');
    return [];
  }

  final int dim = embeddings.first.length;
  final List<double> avgEmbedding = List.filled(dim, 0.0);
  for (final emb in embeddings) {
    for (int i = 0; i < dim; i++) {
      avgEmbedding[i] += emb[i];
    }
  }
  for (int i = 0; i < dim; i++) {
    avgEmbedding[i] /= embeddings.length;
  }

  final double avgPrice = prices.reduce((a, b) => a + b) / prices.length;

  debugPrint('[AI Rekomendasi] Rata-rata harga keranjang: $avgPrice');

  try {
    final List<dynamic> response = await SupabaseService.client.rpc(
      'get_similar_products',
      params: {
        'query_embedding': avgEmbedding,
        'match_threshold': 0.70,
        'match_count': 50,
      },
    );

    debugPrint('[AI Rekomendasi] RPC berhasil → ${response.length} kandidat');

    List<Map<String, dynamic>> scoredProducts = [];
    for (var item in response) {
      final p = Product.fromMap(item);
      if (cartProductIds.contains(p.id)) continue;
      if (p.embedding == null || p.embedding!.isEmpty) continue;

      final score = _combinedScore(avgEmbedding, p.embedding!, avgPrice, p.price);
      scoredProducts.add({'product': p, 'score': score});
    }

    scoredProducts.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return scoredProducts.take(6).map((e) => e['product'] as Product).toList();
  } catch (e) {
    debugPrint('[AI Rekomendasi] RPC gagal: $e');
    return [];
  }
});

// ─── Provider Non-AI: Rekomendasi Keranjang (Category + Price Proximity) ─────
// Ambil semua kategori dari produk di keranjang,
// lalu tampilkan produk dari kategori-kategori tersebut yang harganya paling dekat
// dengan rata-rata harga keranjang.
final cartRecommendationsNonAIProvider = FutureProvider.family<List<Product>, String>((
  ref,
  cartProductIdsJoined,
) async {
  if (cartProductIdsJoined.isEmpty) return [];

  final cartProductIds = cartProductIdsJoined.split(',');
  final products = await ref.watch(productsProvider.future);

  // Kumpulkan kategori dan harga dari produk di keranjang
  final Set<String> cartCategories = {};
  final List<double> cartPrices = [];

  for (final id in cartProductIds) {
    try {
      final p = products.firstWhere((p) => p.id == id);
      // Pakai categoryId jika ada, fallback ke keyword detection
      final cat = p.categoryId ?? _detectCategoryFromName(p.name);
      cartCategories.add(cat);
      cartPrices.add(p.price);
    } catch (_) {
      continue;
    }
  }

  if (cartCategories.isEmpty) return [];

  final double avgPrice = cartPrices.isEmpty
      ? 0
      : cartPrices.reduce((a, b) => a + b) / cartPrices.length;

  debugPrint('[Non-AI Keranjang] Kategori: $cartCategories, rata harga: $avgPrice');

  // Filter: produk dari kategori yang ada di keranjang, tapi bukan produk itu sendiri
  final candidates = products.where((p) {
    if (cartProductIds.contains(p.id)) return false;
    // Pakai categoryId jika ada, fallback ke keyword detection
    final pCat = p.categoryId ?? _detectCategoryFromName(p.name);
    return cartCategories.contains(pCat);
  }).toList();

  // Urutkan berdasarkan selisih harga dengan rata-rata harga keranjang
  candidates.sort((a, b) {
    final diffA = (a.price - avgPrice).abs();
    final diffB = (b.price - avgPrice).abs();
    return diffA.compareTo(diffB);
  });

  debugPrint('[Non-AI Keranjang] ${candidates.length} kandidat');
  return candidates.take(6).toList();
});

