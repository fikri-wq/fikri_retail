import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../models/product_model.dart';
import '../../services/supabase_service.dart';
import '../../main.dart' show AppColors;
import 'product_provider.dart';
import 'cart_provider.dart';
import 'cart_screen.dart';
import '../order/checkout_screen.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Stream provider untuk satu produk — stok update realtime
final singleProductProvider = StreamProvider.family<Product, String>((ref, productId) {
  return SupabaseService.client
      .from('products')
      .stream(primaryKey: ['id'])
      .eq('id', productId)
      .map((data) {
        if (data.isEmpty) throw Exception('Produk tidak ditemukan');
        return Product.fromMap(data.first);
      });
});

class ProductDetailScreen extends ConsumerWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );

    // Watch realtime data produk — stok dan harga selalu terbaru
    final liveProductAsync = ref.watch(singleProductProvider(product.id));
    final liveProduct = liveProductAsync.when(
      data: (p) => p,
      loading: () => product,
      error: (_, __) => product,
    );

    // Toggle mode AI / Non-AI
    final useAI = ref.watch(useAIRecommendationProvider);

    // Watch provider sesuai mode
    final recommendationsAsync = useAI
        ? ref.watch(similarProductsProvider(product.id))
        : ref.watch(similarProductsNonAIProvider(product.id));

    return Scaffold(
      backgroundColor: Colors.grey[200],
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black38,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.black38,
              child: IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 20),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CartScreen()),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gambar Produk
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: (liveProduct.imageUrl != null && liveProduct.imageUrl!.startsWith('assets/'))
                      ? Image.asset(
                          liveProduct.imageUrl!,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        )
                      : CachedNetworkImage(
                          imageUrl: liveProduct.imageUrl ?? 'https://via.placeholder.com/400',
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                ),

                // Harga dan Nama
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currencyFormatter.format(liveProduct.price),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        liveProduct.name,
                        style: const TextStyle(fontSize: 16, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Rincian Produk
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16.0),
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rincian Produk',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const SizedBox(
                              width: 100,
                              child: Text('Stok',
                                  style: TextStyle(color: Colors.grey, fontSize: 13))),
                          liveProductAsync.when(
                            data: (p) => Text('${p.stock}',
                                style: const TextStyle(fontSize: 13)),
                            loading: () => Text('${product.stock}',
                                style: const TextStyle(fontSize: 13)),
                            error: (_, __) => Text('${product.stock}',
                                style: const TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Deskripsi:',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(liveProduct.description,
                          style: const TextStyle(fontSize: 13, height: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ── SEKSI REKOMENDASI dengan TOGGLE ──────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.only(top: 16, bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header + Toggle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pilihan Serupa',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 10),
                            // Toggle switch mode
                            _buildToggle(context, ref, useAI),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Daftar produk rekomendasi
                      SizedBox(
                        height: 200,
                        child: recommendationsAsync.when(
                          data: (list) {
                            if (list.isEmpty) {
                              return Center(
                                child: Text(
                                  useAI
                                      ? 'Belum ada rekomendasi AI yang mirip.'
                                      : 'Tidak ada produk lain di kategori yang sama.',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              );
                            }
                            return ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemCount: list.length,
                              itemBuilder: (context, index) {
                                return _buildSmallProductCard(
                                    context, list[index], currencyFormatter);
                              },
                            );
                          },
                          loading: () => Center(
                              child: CircularProgressIndicator(
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                          error: (err, stack) => const Center(
                              child: Text('Gagal memuat rekomendasi',
                                  style: TextStyle(fontSize: 12))),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomAction(context, ref, liveProduct),
    );
  }

  // ── Toggle Widget ─────────────────────────────────────────────────────────
  Widget _buildToggle(BuildContext context, WidgetRef ref, bool useAI) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tombol Non-AI
          GestureDetector(
            onTap: () => ref
                .read(useAIRecommendationProvider.notifier)
                .state = false,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: !useAI ? Colors.orange.shade600 : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.category_outlined,
                      size: 14,
                      color: !useAI ? Colors.white : Colors.grey.shade600),
                  const SizedBox(width: 5),
                  Text(
                    'Tanpa AI',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: !useAI ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Tombol AI
          GestureDetector(
            onTap: () => ref
                .read(useAIRecommendationProvider.notifier)
                .state = true,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: useAI ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome,
                      size: 14,
                      color: useAI ? Colors.white : Colors.grey.shade600),
                  const SizedBox(width: 5),
                  Text(
                    'Cosine Similarity',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: useAI ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallProductCard(
      BuildContext context, Product p, NumberFormat formatter) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ProductDetailScreen(product: p)));
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12, width: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
              child: (p.imageUrl != null && p.imageUrl!.startsWith('assets/'))
                  ? Image.asset(
                      p.imageUrl!,
                      height: 120,
                      width: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (context, url, err) =>
                          const Icon(Icons.broken_image),
                    )
                  : CachedNetworkImage(
                      imageUrl:
                          p.imageUrl ?? 'https://via.placeholder.com/150',
                      height: 120,
                      width: 140,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, err) =>
                          const Icon(Icons.broken_image),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatter.format(p.price),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction(
      BuildContext context, WidgetRef ref, Product liveProduct) {
    return SafeArea(
      child: Container(
        height: 60,
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, -2))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: InkWell(
                onTap: () async {
                  await addToCart(liveProduct.id);
                  ref.invalidate(cartProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Ditambahkan ke Keranjang',
                            style: TextStyle(fontSize: 12))));
                  }
                },
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_shopping_cart_rounded,
                        color: Colors.black54, size: 22),
                    SizedBox(height: 2),
                    Text('Keranjang',
                        style:
                            TextStyle(fontSize: 10, color: Colors.black54)),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CheckoutScreen(product: liveProduct),
                    ),
                  );
                },
                child: Container(
                  color: Theme.of(context).colorScheme.primary,
                  child: const Center(
                    child: Text('Beli Sekarang',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
