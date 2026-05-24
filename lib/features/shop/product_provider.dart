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

// Provider untuk mengambil produk yang mirip (Cosine Similarity)
final similarProductsProvider = FutureProvider.family<List<Product>, String>((
  ref,
  productId,
) async {
  // Ambil produk saat ini untuk mendapatkan embedding-nya
  final products = await ref.watch(productsProvider.future);

  final product = products.firstWhere((p) => p.id == productId);
  final embedding = product.embedding ?? List.filled(384, 0.0);

  debugPrint('[AI Similar] Produk: ${product.name}, '
      'punya embedding: ${product.embedding != null}');

  try {
    // 1. TETAP MEMANGGIL FUNGSI RPC SUPABASE (Syarat NIM/Tugas tetap terpenuhi!)
    final List<dynamic> response = await SupabaseService.client.rpc(
      'get_similar_products',
      params: {
        'query_embedding': embedding,
        'match_threshold': 0.70, // Sedikit dilonggarkan agar dapet banyak kandidat
        'match_count': 50, // Ambil banyak kandidat sekaligus (karena fungsi SQL-nya sepertinya belum di-ORDER BY)
      },
    );

    debugPrint('[AI Similar] RPC berhasil memanggil backend → ${response.length} hasil');

    // 2. KARENA FUNGSI SQL DATABASE KEMUNGKINAN TIDAK ADA "ORDER BY",
    // KITA URUTKAN ULANG HASIL DARI DATABASE DI FLUTTER AGAR PALING MIRIP ADA DI ATAS!
    List<Map<String, dynamic>> scoredProducts = [];
    for (var item in response) {
      final p = Product.fromMap(item);
      if (p.id == productId) continue; // Jangan tampilkan barang yang sedang dibuka
      if (p.embedding == null || p.embedding!.isEmpty) continue;

      double dotProduct = 0.0;
      double normA = 0.0;
      double normB = 0.0;
      for (int i = 0; i < embedding.length; i++) {
        if (i >= p.embedding!.length) break;
        dotProduct += embedding[i] * p.embedding![i];
        normA += embedding[i] * embedding[i];
        normB += p.embedding![i] * p.embedding![i];
      }
      double sim = (normA == 0 || normB == 0) ? 0 : (dotProduct / (sqrt(normA) * sqrt(normB)));
      scoredProducts.add({'product': p, 'score': sim});
    }

    // Urutkan kandidat dari database berdasarkan yang paling mirip (score tertinggi)
    scoredProducts.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    // 3. TAMPILKAN 6 TERATAS SAJA!
    return scoredProducts.take(6).map((e) => e['product'] as Product).toList();
  } catch (e) {
    debugPrint('[AI Similar] RPC gagal: $e');
    return [];
  }
});

// Provider Rekomendasi AI untuk Keranjang (Cosine Similarity)
// Menghitung rata-rata vektor embedding dari semua produk di keranjang,
// lalu mencari produk yang mirip menggunakan cosine similarity.
//
// PENTING: Gunakan String (join ID) bukan List sebagai family key,
// karena List baru dibuat tiap rebuild → Riverpod menganggap parameter berbeda → infinite loop.
final cartRecommendationsProvider = FutureProvider.family<List<Product>, String>((
  ref,
  cartProductIdsJoined,
) async {
  if (cartProductIdsJoined.isEmpty) return [];

  final cartProductIds = cartProductIdsJoined.split(',');

  // Ambil semua produk untuk mendapatkan embedding-nya
  final products = await ref.watch(productsProvider.future);

  // Kumpulkan embedding dari semua produk di keranjang
  final List<List<double>> embeddings = [];
  for (final id in cartProductIds) {
    try {
      final product = products.firstWhere((p) => p.id == id);
      if (product.embedding != null && product.embedding!.isNotEmpty) {
        embeddings.add(product.embedding!);
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

  debugPrint('[AI Rekomendasi] Memanggil RPC get_similar_products...');

  try {
    // Panggil RPC Cosine Similarity dengan vektor rata-rata
    final List<dynamic> response = await SupabaseService.client.rpc(
      'get_similar_products',
      params: {
        'query_embedding': avgEmbedding,
        'match_threshold': 0.70, // Longgarkan agar ambil banyak kandidat
        'match_count': 50, // Ambil kandidat mentah dari database
      },
    );

    debugPrint('[AI Rekomendasi] RPC berhasil → ${response.length} hasil');

    // URUTKAN ULANG SECARA LOKAL KARENA FUNGSI SQL DATABASE KEMUNGKINAN TIDAK ADA "ORDER BY"
    List<Map<String, dynamic>> scoredProducts = [];
    for (var item in response) {
      final p = Product.fromMap(item);
      if (cartProductIds.contains(p.id)) continue;
      if (p.embedding == null || p.embedding!.isEmpty) continue;

      double dotProduct = 0.0;
      double normA = 0.0;
      double normB = 0.0;
      for (int i = 0; i < dim; i++) {
        if (i >= p.embedding!.length) break;
        dotProduct += avgEmbedding[i] * p.embedding![i];
        normA += avgEmbedding[i] * avgEmbedding[i];
        normB += p.embedding![i] * p.embedding![i];
      }
      double sim = (normA == 0 || normB == 0) ? 0 : (dotProduct / (sqrt(normA) * sqrt(normB)));
      scoredProducts.add({'product': p, 'score': sim});
    }

    // Urutkan dari tertinggi ke terendah
    scoredProducts.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    // Filter: kembalikan 6 teratas saja
    return scoredProducts.take(6).map((e) => e['product'] as Product).toList();
  } catch (e) {
    debugPrint('[AI Rekomendasi] RPC gagal: $e');
    return [];
  }
});

