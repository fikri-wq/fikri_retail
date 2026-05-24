import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'cart_provider.dart';
import 'product_provider.dart';
import '../../services/supabase_service.dart';
import 'package:intl/intl.dart';
import '../order/checkout_screen.dart';
import '../../models/product_model.dart';
import 'product_detail_screen.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('Keranjang Saya', style: TextStyle(color: Colors.black87, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: cartAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return _buildEmptyCart();
          }

          double total = 0;
          for (var item in items) {
            total += (item['products']['price'] * item['quantity']);
          }

          return Column(
            children: [
              Expanded(
                child: _buildCartListWithRecommendations(context, ref, items, formatter),
              ),
              // Bottom Action
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                           Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 20),
                           const SizedBox(width: 8),
                           const Text('Semua', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Text('Total: ', style: TextStyle(fontSize: 14)),
                                Text(
                                  formatter.format(total),
                                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                         if (items.isEmpty) return; // cannot checkout empty cart
                         Navigator.push(
                           context,
                           MaterialPageRoute(builder: (context) => CheckoutScreen(
                             cartItems: items,
                           )),
                         ).then((_) => ref.invalidate(cartProvider));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                        color: Theme.of(context).colorScheme.primary,
                        child: const Text('Checkout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.remove_shopping_cart_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Keranjang belanja Anda kosong', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCartListWithRecommendations(
    BuildContext context, WidgetRef ref, List<Map<String, dynamic>> items, NumberFormat formatter,
  ) {
    // Ambil product IDs dari keranjang untuk rekomendasi AI
    final cartProductIds = items
        .map((item) => item['product_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    // Join sebagai String agar Riverpod family key stabil (List baru tiap rebuild = infinite loop)
    final recommendationsAsync = ref.watch(cartRecommendationsProvider(cartProductIds.join(',')));

    return ListView(
      padding: const EdgeInsets.only(top: 8),
      children: [
        // === DAFTAR ITEM KERANJANG ===
        ...items.map((item) {
          final product = item['products'];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                (product['image_url'] != null && product['image_url'].toString().startsWith('assets/'))
                    ? Image.asset(
                        product['image_url'],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        product['image_url'] ?? 'https://via.placeholder.com/150',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product['name'], style: const TextStyle(fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Text(
                        formatter.format(product['price']),
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () async {
                        await SupabaseService.client.from('carts').delete().eq('id', item['id']);
                        ref.invalidate(cartProvider);
                      },
                    ),
                    Text('x${item['quantity']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                )
              ],
            ),
          );
        }),

        // === REKOMENDASI AI (COSINE SIMILARITY) ===
        Container(
          color: Colors.white,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Rekomendasi Untukmu',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).colorScheme.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: recommendationsAsync.when(
                  data: (recommendations) {
                    if (recommendations.isEmpty) {
                      return const Center(
                        child: Text('Belum ada rekomendasi yang cocok.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      );
                    }
                    final displayItems = recommendations.take(20).toList();
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: displayItems.length,
                      itemBuilder: (context, index) {
                        return _buildRecommendationCard(context, ref, displayItems[index], formatter);
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
    );
  }

  Widget _buildRecommendationCard(BuildContext context, WidgetRef ref, Product product, NumberFormat formatter) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProductDetailScreen(product: product)),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black12, width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: (product.imageUrl != null && product.imageUrl!.startsWith('assets/'))
                  ? Image.asset(
                      product.imageUrl!,
                      height: 110,
                      width: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (context, url, err) => const Icon(Icons.broken_image),
                    )
                  : CachedNetworkImage(
                      imageUrl: product.imageUrl ?? 'https://via.placeholder.com/150',
                      height: 110,
                      width: 140,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, err) => const Icon(Icons.broken_image),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatter.format(product.price),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 26,
                      child: ElevatedButton(
                        onPressed: () async {
                          await addToCart(product.id);
                          ref.invalidate(cartProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Ditambahkan ke keranjang'), duration: Duration(seconds: 1)),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('+ Keranjang', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
