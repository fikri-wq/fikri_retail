import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../services/supabase_service.dart';
import '../../models/order_model.dart';
import 'package:url_launcher/url_launcher.dart';

// Helper: Ambil nama user berdasarkan user_id dari tabel profiles
Future<Map<String, String>> _fetchUserNames(List<String> userIds) async {
  if (userIds.isEmpty) return {};
  
  try {
    final response = await SupabaseService.client
        .from('profiles')
        .select('id, full_name')
        .inFilter('id', userIds);
    
    final Map<String, String> names = {};
    for (var profile in response) {
      names[profile['id']] = profile['full_name'] ?? 'Unknown';
    }
    return names;
  } catch (_) {
    return {};
  }
}

// Mengambil seluruh riwayat pesanan khusus untuk Admin (REALTIME + nama customer)
final adminOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  return SupabaseService.client
      .from('orders')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .asyncMap((data) async {
        // Ambil nama customer dari profiles
        final userIds = data
            .map((e) => e['customer_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
        final names = await _fetchUserNames(userIds);
        
        return data.map((e) {
          e['_customer_name'] = names[e['customer_id']] ?? 'Unknown';
          return OrderModel.fromMap(e);
        }).toList();
      });
});

// Mengambil pesanan khusus untuk Customer yang sedang login (REALTIME)
// Status pesanan otomatis update tanpa perlu refresh
final customerOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  final user = SupabaseService.client.auth.currentUser;
  if (user == null) return Stream.value([]);

  // Supabase Realtime: listen perubahan pada tabel orders milik customer ini
  return SupabaseService.client
      .from('orders')
      .stream(primaryKey: ['id'])
      .eq('customer_id', user.id)
      .order('created_at', ascending: false)
      .map((data) => data.map((e) => OrderModel.fromMap(e)).toList());
});

// Fungsi untuk ubah status dari Pending -> Diantar -> Selesai
Future<void> updateOrderStatus(String orderId, String newStatus) async {
  await SupabaseService.client.from('orders').update({'status': newStatus}).eq('id', orderId);
}

// Fitur canggih: Beralih ke Navigasi Google Maps untuk Kurir
Future<void> openMap(double lat, double lng) async {
  final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  if (await canLaunchUrl(Uri.parse(url))) {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

// Fitur: Batalkan pesanan (hanya ubah status ke cancelled tanpa kembalikan stok demi keprofesionalan flow customer)
Future<void> cancelOrder(OrderModel order) async {
  print('[CancelOrder] Mulai membatalkan pesanan ID: ${order.id}');
  
  // 1. Ubah status pesanan menjadi 'cancelled'
  try {
    print('[CancelOrder] Melakukan update status pesanan...');
    final response = await SupabaseService.client
        .from('orders')
        .update({'status': 'cancelled'})
        .eq('id', order.id)
        .select();
        
    print('[CancelOrder] Respon dari update: $response');
    
    if ((response as List).isEmpty) {
      throw Exception('RLS_UPDATE_DENIED');
    }
    
    print('[CancelOrder] Status pesanan berhasil diupdate.');
  } catch (e) {
    print('[CancelOrder] Gagal update status pesanan: $e');
    rethrow;
  }
  print('[CancelOrder] Selesai membatalkan pesanan.');
}

