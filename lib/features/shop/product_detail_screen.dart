import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/services.dart';
import '../../models/product_model.dart';
import 'product_provider.dart';
import 'cart_provider.dart';
import 'cart_screen.dart';
import '../order/checkout_screen.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

    final similarProductsAsync = ref.watch(similarProductsProvider(product.id));

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
                icon: const Icon(Icons.share, color: Colors.white, size: 20),
                onPressed: () {
                  final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
                  final text = '${product.name}\n${formatter.format(product.price)}\n\nBeli di Yeti Smart Retail!';
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link produk disalin ke clipboard!')),
                  );
                },
              ),
            ),
          ),
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
              child: (product.imageUrl != null && product.imageUrl!.startsWith('assets/'))
                  ? Image.asset(
                      product.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    )
                  : CachedNetworkImage(
                      imageUrl: product.imageUrl ?? 'https://via.placeholder.com/400',
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
            ),

            // Harga dan Nama (Header Info)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        currencyFormatter.format(product.price),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text('Garansi Harga Termurah', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 10)),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.name,
                    style: const TextStyle(fontSize: 16, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const Text(' 4.9', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 12, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text('10rb+ Terjual', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Deskripsi
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
                      const SizedBox(width: 100, child: Text('Stok', style: TextStyle(color: Colors.grey, fontSize: 13))),
                      Text('${product.stock}', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Deskripsi:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(product.description, style: const TextStyle(fontSize: 13, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // REKOMENDASI PRODUK (Cosine Similarity)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Pilihan Serupa',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: similarProductsAsync.when(
                      data: (similarList) {
                         if (similarList.isEmpty) {
                           return const Center(child: Text('Belum ada rekomendasi yang mirip.', style: TextStyle(fontSize: 12)));
                         }
                         return ListView.builder(
                           padding: const EdgeInsets.symmetric(horizontal: 16),
                           scrollDirection: Axis.horizontal,
                           itemCount: similarList.length,
                           itemBuilder: (context, index) {
                             return _buildSmallProductCard(context, similarList[index], currencyFormatter);
                           },
                         );
                      },
                      loading: () => Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
                      error: (err, stack) => const Center(child: Text('Gagal memuat rekomendasi', style: TextStyle(fontSize: 12))),
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
      bottomNavigationBar: _buildBottomAction(context, ref),
    );
  }

  Widget _buildSmallProductCard(BuildContext context, Product p, NumberFormat formatter) {
    return InkWell(
      onTap: () {
        Navigator.pop(context); // Optional: replace with push replacement or direct push
        Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailScreen(product: p)));
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              child: (p.imageUrl != null && p.imageUrl!.startsWith('assets/'))
                  ? Image.asset(
                      p.imageUrl!,
                      height: 120,
                      width: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (context, url, err) => const Icon(Icons.broken_image),
                    )
                  : CachedNetworkImage(
                      imageUrl: p.imageUrl ?? 'https://via.placeholder.com/150',
                      height: 120,
                      width: 140,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, err) => const Icon(Icons.broken_image),
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
                      fontSize: 13
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Container(
        height: 60,
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
        ),
        child: Row(
          children: [
            // Ikon Keranjang (tambah ke keranjang)
            Expanded(
              flex: 1,
              child: InkWell(
                onTap: () async {
                  await addToCart(product.id);
                  ref.invalidate(cartProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ditambahkan ke Keranjang', style: TextStyle(fontSize: 12))));
                  }
                },
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_shopping_cart_rounded, color: Colors.black54, size: 22),
                    SizedBox(height: 2),
                    Text('Keranjang', style: TextStyle(fontSize: 10, color: Colors.black54)),
                  ],
                ),
              ),
            ),
            // Tombol Beli
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CheckoutScreen(product: product),
                    ),
                  );
                },
                child: Container(
                  color: Theme.of(context).colorScheme.primary,
                  child: const Center(
                    child: Text('Beli Sekarang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
