import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'cart_provider.dart';
import 'product_provider.dart';
import '../../services/supabase_service.dart';
import '../../main.dart' show AppColors;
import 'package:intl/intl.dart';
import '../order/checkout_screen.dart';
import '../../models/product_model.dart';
import 'product_detail_screen.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  // Set berisi cart item ID yang sedang dipilih
  final Set<String> _selectedIds = {};

  final formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  bool _initialized = false;

  // Inisialisasi seleksi HANYA sekali saat data pertama kali dimuat
  void _initSelection(List<Map<String, dynamic>> items) {
    if (!_initialized && items.isNotEmpty) {
      for (var item in items) {
        _selectedIds.add(item['id'].toString());
      }
      _initialized = true;
    }
  }

  void _toggleItem(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<Map<String, dynamic>> items) {
    setState(() {
      if (_selectedIds.length == items.length) {
        // Semua terpilih → deselect semua
        _selectedIds.clear();
      } else {
        // Pilih semua
        for (var item in items) {
          _selectedIds.add(item['id'].toString());
        }
      }
    });
  }

  double _calculateTotal(List<Map<String, dynamic>> items) {
    double total = 0;
    for (var item in items) {
      if (_selectedIds.contains(item['id'].toString())) {
        total += (item['products']['price'] * item['quantity']);
      }
    }
    return total;
  }

  List<Map<String, dynamic>> _getSelectedItems(List<Map<String, dynamic>> items) {
    return items.where((item) => _selectedIds.contains(item['id'].toString())).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('Keranjang Saya',
            style: TextStyle(color: Colors.black87, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: cartAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return _buildEmptyCart();
          }

          // Inisialisasi semua item terpilih saat pertama load
          _initSelection(items);

          final selectedItems = _getSelectedItems(items);
          final total = _calculateTotal(items);
          final isAllSelected = _selectedIds.length == items.length;

          return Column(
            children: [
              Expanded(
                child: _buildCartListWithRecommendations(context, items),
              ),
              // Bottom Action Bar
              Container(
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
                    // Tombol "Semua" dengan centang interaktif
                    InkWell(
                      onTap: () => _toggleSelectAll(items),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              isAllSelected
                                  ? Icons.check_circle
                                  : Icons.check_circle_outline,
                              color: isAllSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            const Text('Semua',
                                style: TextStyle(fontSize: 12)),
                          ],
                        ),
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
                                const Text('Total: ',
                                    style: TextStyle(fontSize: 14)),
                                Text(
                                  formatter.format(total),
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Tombol Checkout
                    InkWell(
                      onTap: selectedItems.isEmpty
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Pilih minimal 1 produk untuk checkout')),
                              );
                            }
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CheckoutScreen(
                                    cartItems: selectedItems,
                                  ),
                                ),
                              ).then((_) => ref.invalidate(cartProvider));
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 18),
                        color: selectedItems.isEmpty
                            ? Colors.grey
                            : Theme.of(context).colorScheme.primary,
                        child: Text(
                          selectedItems.isEmpty
                              ? 'Checkout'
                              : 'Checkout (${selectedItems.length})',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => Center(
            child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary)),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.remove_shopping_cart_outlined,
              size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Keranjang belanja Anda kosong',
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCartListWithRecommendations(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    final cartProductIds = items
        .map((item) => item['product_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    final useAI = ref.watch(useAIRecommendationProvider);

    // Pilih provider sesuai mode
    final recommendationsAsync = useAI
        ? ref.watch(cartRecommendationsProvider(cartProductIds.join(',')))
        : ref.watch(cartRecommendationsNonAIProvider(cartProductIds.join(',')));

    return ListView(
      padding: const EdgeInsets.only(top: 8),
      children: [
        // === DAFTAR ITEM KERANJANG ===
        ...items.map((item) {
          final product = item['products'];
          final itemId = item['id'].toString();
          final isSelected = _selectedIds.contains(itemId);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Centang interaktif per item
                GestureDetector(
                  onTap: () => _toggleItem(itemId),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, right: 12),
                    child: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      size: 22,
                    ),
                  ),
                ),
                // Gambar produk (klik → buka detail)
                GestureDetector(
                  onTap: () {
                    final productModel = Product.fromMap({
                      'id': item['product_id'],
                      ...Map<String, dynamic>.from(product),
                    });
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProductDetailScreen(product: productModel),
                      ),
                    );
                  },
                  child: (product['image_url'] != null &&
                          product['image_url'].toString().startsWith('assets/'))
                      ? Image.asset(
                          product['image_url'],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          product['image_url'] ??
                              'https://via.placeholder.com/150',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product['name'],
                          style: const TextStyle(fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Text(
                        formatter.format(product['price']),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () async {
                        await SupabaseService.client
                            .from('carts')
                            .delete()
                            .eq('id', item['id']);
                        // Hapus dari seleksi juga
                        setState(() => _selectedIds.remove(itemId));
                        ref.invalidate(cartProvider);
                      },
                    ),
                    Text('x${item['quantity']}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Rekomendasi Untukmu',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Toggle mode AI / Non-AI
                    _buildToggle(context),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: recommendationsAsync.when(
                  data: (recommendations) {
                    if (recommendations.isEmpty) {
                      return Center(
                        child: Text(
                          useAI
                              ? 'Belum ada rekomendasi AI yang cocok.'
                              : 'Tidak ada produk lain di kategori yang sama.',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      );
                    }
                    final displayItems = recommendations.take(20).toList();
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: displayItems.length,
                      itemBuilder: (context, index) {
                        return _buildRecommendationCard(
                            context, displayItems[index]);
                      },
                    );
                  },
                  loading: () => Center(
                      child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary)),
                  error: (err, stack) => const Center(
                      child: Text('Gagal memuat rekomendasi',
                          style: TextStyle(fontSize: 12))),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggle(BuildContext context) {
    final useAI = ref.watch(useAIRecommendationProvider);
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () =>
                ref.read(useAIRecommendationProvider.notifier).state = false,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
          GestureDetector(
            onTap: () =>
                ref.read(useAIRecommendationProvider.notifier).state = true,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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

  Widget _buildRecommendationCard(BuildContext context, Product product) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ProductDetailScreen(product: product)),
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              child: (product.imageUrl != null &&
                      product.imageUrl!.startsWith('assets/'))
                  ? Image.asset(
                      product.imageUrl!,
                      height: 110,
                      width: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (context, url, err) =>
                          const Icon(Icons.broken_image),
                    )
                  : CachedNetworkImage(
                      imageUrl: product.imageUrl ??
                          'https://via.placeholder.com/150',
                      height: 110,
                      width: 140,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, err) =>
                          const Icon(Icons.broken_image),
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
                              const SnackBar(
                                  content: Text('Ditambahkan ke keranjang'),
                                  duration: Duration(seconds: 1)),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('+ Keranjang',
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold)),
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
