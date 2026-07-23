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
// Semakin dekat harganya, semakin mendekati 1.0
double _priceSimilarity(double priceA, double priceB) {
  if (priceA <= 0 || priceB <= 0) return 0.5; // neutral jika harga tidak valid
  final diff = (priceA - priceB).abs();
  final maxPrice = max(priceA, priceB);
  return 1.0 - (diff / maxPrice);
}

// ─── Helper: Combined Score (Semantic 70% + Price 30%) ──────────────────────
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

// Provider untuk mengambil produk yang mirip (Cosine Similarity + Price Similarity)
final similarProductsProvider = FutureProvider.family<List<Product>, String>((
  ref,
  productId,
) async {
  // Ambil produk saat ini untuk mendapatkan embedding dan harganya
  final products = await ref.watch(productsProvider.future);

  final product = products.firstWhere((p) => p.id == productId);
  final embedding = product.embedding ?? List.filled(384, 0.0);
  final price = product.price;

  debugPrint('[AI Similar] Produk: ${product.name}, harga: ${product.price}, '
      'punya embedding: ${product.embedding != null}');

  try {
    // Panggil RPC Supabase untuk mendapatkan kandidat awal berdasarkan semantic similarity
    final List<dynamic> response = await SupabaseService.client.rpc(
      'get_similar_products',
      params: {
        'query_embedding': embedding,
        'match_threshold': 0.70,
        'match_count': 50,
      },
    );

    debugPrint('[AI Similar] RPC berhasil → ${response.length} kandidat');

    // Hitung combined score (semantic + price) untuk setiap kandidat
    List<Map<String, dynamic>> scoredProducts = [];
    for (var item in response) {
      final p = Product.fromMap(item);
      if (p.id == productId) continue;
      if (p.embedding == null || p.embedding!.isEmpty) continue;

      final score = _combinedScore(embedding, p.embedding!, price, p.price);
      scoredProducts.add({'product': p, 'score': score});

      debugPrint('[AI Similar] ${p.name} | harga: ${p.price} | combined score: ${score.toStringAsFixed(4)}');
    }

    // Urutkan dari score tertinggi ke terendah
    scoredProducts.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    // Ambil 6 teratas
    return scoredProducts.take(6).map((e) => e['product'] as Product).toList();
  } catch (e) {
    debugPrint('[AI Similar] RPC gagal: $e');
    return [];
  }
});

// Provider Rekomendasi AI untuk Keranjang (Cosine Similarity + Price Similarity)
// Menghitung rata-rata vektor embedding dan rata-rata harga dari semua produk di keranjang,
// lalu mencari produk yang mirip secara semantik DAN harga.
//
// PENTING: Gunakan String (join ID) bukan List sebagai family key,
// karena List baru dibuat tiap rebuild → Riverpod menganggap parameter berbeda → infinite loop.
final cartRecommendationsProvider = FutureProvider.family<List<Product>, String>((
  ref,
  cartProductIdsJoined,
) async {
  if (cartProductIdsJoined.isEmpty) return [];

  final cartProductIds = cartProductIdsJoined.split(',');

  // Ambil semua produk untuk mendapatkan embedding dan harganya
  final products = await ref.watch(productsProvider.future);

  // Kumpulkan embedding dan harga dari semua produk di keranjang
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

  // Hitung rata-rata vektor embedding (Average Pooling)
  final int dim = embeddings.first.length; // 384 dimensi
  final List<double> avgEmbedding = List.filled(dim, 0.0);
  for (final emb in embeddings) {
    for (int i = 0; i < dim; i++) {
      avgEmbedding[i] += emb[i];
    }
  }
  for (int i = 0; i < dim; i++) {
    avgEmbedding[i] /= embeddings.length;
  }

  // Hitung rata-rata harga dari produk di keranjang
  final double avgPrice = prices.reduce((a, b) => a + b) / prices.length;

  debugPrint('[AI Rekomendasi] Rata-rata harga keranjang: $avgPrice');
  debugPrint('[AI Rekomendasi] Memanggil RPC get_similar_products...');

  try {
    // Panggil RPC dengan embedding rata-rata
    final List<dynamic> response = await SupabaseService.client.rpc(
      'get_similar_products',
      params: {
        'query_embedding': avgEmbedding,
        'match_threshold': 0.70,
        'match_count': 50,
      },
    );

    debugPrint('[AI Rekomendasi] RPC berhasil → ${response.length} kandidat');

    // Hitung combined score (semantic + price) untuk setiap kandidat
    List<Map<String, dynamic>> scoredProducts = [];
    for (var item in response) {
      final p = Product.fromMap(item);
      if (cartProductIds.contains(p.id)) continue;
      if (p.embedding == null || p.embedding!.isEmpty) continue;

      final score = _combinedScore(avgEmbedding, p.embedding!, avgPrice, p.price);
      scoredProducts.add({'product': p, 'score': score});
    }

    // Urutkan dari score tertinggi ke terendah
    scoredProducts.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    // Kembalikan 6 teratas
    return scoredProducts.take(6).map((e) => e['product'] as Product).toList();
  } catch (e) {
    debugPrint('[AI Rekomendasi] RPC gagal: $e');
    return [];
  }
});

