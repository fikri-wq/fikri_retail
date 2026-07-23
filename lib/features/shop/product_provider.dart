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

// ─── Provider Non-AI: Category-based + Price Proximity ──────────────────────
// Algoritma konvensional tanpa AI:
//   1. Filter produk dengan category_id yang sama
//   2. Urutkan berdasarkan selisih harga terkecil (terdekat harganya)
//   3. Ambil 6 teratas
final similarProductsNonAIProvider = FutureProvider.family<List<Product>, String>((
  ref,
  productId,
) async {
  final products = await ref.watch(productsProvider.future);
  final product = products.firstWhere((p) => p.id == productId);

  debugPrint('[Non-AI Similar] Produk: ${product.name}, categoryId: ${product.categoryId}');

  // Filter: sama kategori, bukan produk itu sendiri
  final candidates = products.where((p) {
    if (p.id == productId) return false;
    if (product.categoryId == null) return false;
    return p.categoryId == product.categoryId;
  }).toList();

  // Urutkan berdasarkan selisih harga terkecil (price proximity)
  candidates.sort((a, b) {
    final diffA = (a.price - product.price).abs();
    final diffB = (b.price - product.price).abs();
    return diffA.compareTo(diffB);
  });

  debugPrint('[Non-AI Similar] ${candidates.length} kandidat dari kategori yang sama');
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
      if (p.categoryId != null) cartCategories.add(p.categoryId!);
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
    if (p.categoryId == null) return false;
    return cartCategories.contains(p.categoryId);
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

