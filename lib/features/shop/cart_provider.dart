import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../services/supabase_service.dart';

final cartProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = SupabaseService.client.auth.currentUser;
  if (user == null) return [];

  final response = await SupabaseService.client
      .from('carts')
      .select('*, products(*)')
      .eq('user_id', user.id);

  return List<Map<String, dynamic>>.from(response);
});

// Helper untuk tambah ke keranjang
Future<void> addToCart(String productId) async {
  final user = SupabaseService.client.auth.currentUser;
  if (user == null) return;

  // Cek apakah produk sudah ada di keranjang
  final existingCart = await SupabaseService.client
      .from('carts')
      .select('id, quantity')
      .eq('user_id', user.id)
      .eq('product_id', productId)
      .maybeSingle();

  if (existingCart != null) {
    // Jika sudah ada, tambahkan quantity + 1
    await SupabaseService.client
        .from('carts')
        .update({'quantity': (existingCart['quantity'] as int) + 1})
        .eq('id', existingCart['id']);
  } else {
    // Jika belum ada, masukkan baru dengan quantity 1
    await SupabaseService.client.from('carts').insert({
      'user_id': user.id,
      'product_id': productId,
      'quantity': 1,
    });
  }
}
