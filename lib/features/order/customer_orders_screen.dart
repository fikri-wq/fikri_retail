import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'order_provider.dart';
import 'order_chat_screen.dart';
import '../../models/order_model.dart';
import '../../services/supabase_service.dart';

class CustomerOrdersScreen extends ConsumerWidget {
  const CustomerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(customerOrdersProvider);
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesanan Saya', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.normal)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      backgroundColor: Colors.grey[100],
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: TabBar(
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).colorScheme.primary,
                labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                unselectedLabelStyle: TextStyle(fontSize: 12),
                tabs: [
                  Tab(icon: Icon(Icons.timer), text: 'Diproses'),
                  Tab(icon: Icon(Icons.local_shipping_outlined), text: 'Dikirim/Siap'),
                  Tab(icon: Icon(Icons.star_border), text: 'Selesai/Batal'),
                ],
              ),
            ),
            Expanded(
              child: ordersAsync.when(
                data: (orders) {
                  final pending = orders.where((o) => o.status == 'pending' || o.status == 'processing').toList();
                  final diantar = orders.where((o) => o.status == 'shipped').toList();
                  final selesai = orders.where((o) => o.status == 'delivered' || o.status == 'cancelled').toList();

                  return TabBarView(
                    children: [
                      pending.isEmpty ? _buildEmptyState(ref, 'Tidak ada pesanan yang sedang diproses') : _buildOrderList(context, ref, pending, currencyFormatter),
                      diantar.isEmpty ? _buildEmptyState(ref, 'Belum ada pesanan yang dikirim/siap diambil') : _buildOrderList(context, ref, diantar, currencyFormatter),
                      selesai.isEmpty ? _buildEmptyState(ref, 'Belum ada riwayat pesanan selesai/batal') : _buildOrderList(context, ref, selesai, currencyFormatter),
                    ],
                  );
                },
                loading: () => Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
                error: (err, stack) => const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Menghubungkan ulang...', style: TextStyle(color: Colors.grey))])),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[100],
        child: const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
      );
    }
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey[100],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey[100],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }

  Widget _buildOrderList(BuildContext context, WidgetRef ref, List orders, NumberFormat formatter) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(customerOrdersProvider);
        // Add a slight delay to show the refresh animation
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final isPending = order.status == 'pending';
        final isProcessing = order.status == 'processing';
        final isShipped = order.status == 'shipped';
        final isCancelled = order.status == 'cancelled';
        
        Color statusColor = (isPending || isProcessing) ? Colors.orange 
            : (isShipped ? Theme.of(context).colorScheme.secondary 
            : (isCancelled ? Colors.red : Colors.green));
        Color statusBgColor = statusColor.withOpacity(0.1);
        final isDelivery = order.address?.toLowerCase().contains('delivery') ?? true;
        
        String statusText = isPending ? 'Menunggu' 
            : (isProcessing ? 'Diproses Admin' 
            : (isShipped ? (isDelivery ? 'Kurir Menuju Lokasi' : 'Barang Siap Diambil')
            : (isCancelled ? 'Dibatalkan' : 'Selesai')));

        final hasItems = order.items != null && order.items!.isNotEmpty;
        final firstItem = hasItems ? order.items!.first : null;
        final extraItemsCount = hasItems ? order.items!.length - 1 : 0;

        return Card(
          elevation: 0,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200)
          ),
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Tanggal & Badge Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('dd MMM yyyy').format(order.createdAt),
                          style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, thickness: 0.5),
                
                // Body: Info Pesanan & Gambar Produk
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kotak Gambar Produk
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: hasItems 
                            ? _buildProductImage(firstItem!['image_url'])
                            : Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.primary, size: 32),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Detail Produk
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasItems) ...[
                            Text(
                              firstItem!['name'] ?? 'Produk',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${firstItem['quantity']} barang x ${formatter.format(firstItem['price'])}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            if (extraItemsCount > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                '+ $extraItemsCount produk lainnya',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
                              ),
                            ],
                          ] else ...[
                            const Text('ID Pesanan', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(order.id.toString().substring(0, 8).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                          const SizedBox(height: 6),
                          if (order.address != null && order.address!.isNotEmpty)
                            Text(
                              order.address!,
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Footer: Total & Tombol Aksi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Belanja', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(formatter.format(order.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                        const SizedBox(height: 2),
                        Text('ID: ${order.id.toString().substring(0, 8).toUpperCase()}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                    Row(
                      children: [
                        if (isPending) ...[
                          SizedBox(
                            height: 36,
                            child: OutlinedButton(
                              onPressed: () => _showCancelDialog(context, ref, order),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: BorderSide(color: Colors.red.shade200),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              child: const Text('Batalkan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                        if (!isCancelled) ...[
                          const SizedBox(width: 8),
                          _ChatButtonWithBadge(orderId: order.id),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref, OrderModel order) {
    showDialog(
      context: context,
      builder: (confirmCtx) => AlertDialog(
        title: const Text('Batalkan Pesanan?'),
        content: const Text('Apakah Anda yakin ingin membatalkan pesanan ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmCtx),
            child: const Text('Tidak', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(confirmCtx); // Tutup dialog konfirmasi
              
              // Tampilkan loading overlay dengan context tersendiri
              BuildContext? dialogCtx;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingCtx) {
                  dialogCtx = loadingCtx;
                  return Center(
                    child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                  );
                },
              );

              try {
                // Timeout 10 detik agar loading tidak menggantung selamanya jika ada kendala koneksi
                await cancelOrder(order).timeout(const Duration(seconds: 10));
                
                if (dialogCtx != null && Navigator.canPop(dialogCtx!)) {
                  Navigator.pop(dialogCtx!); // Tutup loading secara aman
                }
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Pesanan berhasil dibatalkan!')),
                  );
                  ref.invalidate(customerOrdersProvider); // Refresh list pesanan
                }
              } catch (e) {
                if (dialogCtx != null && Navigator.canPop(dialogCtx!)) {
                  Navigator.pop(dialogCtx!); // Tutup loading secara aman
                }
                
                if (context.mounted) {
                  final errorMsg = e.toString();
                  if (errorMsg.contains('RLS_UPDATE_DENIED')) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(child: Text('RLS Update Belum Aktif')),
                          ],
                        ),
                        content: const Text(
                          'Pembatalan gagal karena database Supabase belum mengizinkan aksi UPDATE bagi Customer.\n\n'
                          'Silakan jalankan SQL ini di SQL Editor Supabase Anda:\n\n'
                          'CREATE POLICY "Allow update for owners" ON public.orders FOR UPDATE TO authenticated USING (auth.uid() = customer_id);'
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Mengerti'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ Gagal membatalkan pesanan: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(WidgetRef ref, String message) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(customerOrdersProvider);
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(message, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                  const SizedBox(height: 32), // push slightly above center
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// Chat button with realtime unread badge
class _ChatButtonWithBadge extends StatelessWidget {
  final String orderId;
  const _ChatButtonWithBadge({required this.orderId});

  @override
  Widget build(BuildContext context) {
    final currentUserId = SupabaseService.client.auth.currentUser?.id;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.client
          .from('order_chats')
          .stream(primaryKey: ['id'])
          .eq('order_id', orderId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        // Count unread: messages from admin (is_admin = true) that are not from current user
        int unreadCount = 0;
        // Badge merah hanya kalau pesan TERBARU adalah dari admin (bukan customer sendiri)
        if (snapshot.hasData && currentUserId != null && snapshot.data!.isNotEmpty) {
          final latestMsg = snapshot.data!.last; // pesan terakhir (urutan ascending)
          // Badge hanya muncul kalau pengirim terakhir adalah admin, bukan customer
          if (latestMsg['sender_id'] != currentUserId && latestMsg['is_admin'] == true) {
            unreadCount = 1;
          } else {
            unreadCount = 0;
          }
        }

        return SizedBox(
          height: 36,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderChatScreen(orderId: orderId),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_rounded, size: 16),
                label: const Text('Chat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
