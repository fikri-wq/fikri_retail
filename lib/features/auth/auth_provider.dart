import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Provider untuk memantau status sesi login user
final authStateProvider = StreamProvider<AuthState>((ref) {
  return AuthService.client.auth.onAuthStateChange;
});

// Provider untuk cek role user yang sedang login.
// Menggunakan userId sebagai key agar hanya re-fetch saat user berubah,
// bukan setiap kali auth stream emit event (mencegah infinite loading di web).
final userRoleProvider = FutureProvider<String?>((ref) async {
  final authAsync = ref.watch(authStateProvider);

  // Hanya proses jika data sudah tersedia (bukan loading/error)
  final session = authAsync.asData?.value.session;

  // Tidak ada session → tidak perlu cek role
  if (session == null) return null;

  final userId = session.user.id;

  // Gunakan userId sebagai cache key agar tidak re-fetch terus-menerus
  // saat stream auth emit event berulang (SIGTERM/reconnect di web)
  return ref.watch(_userRoleCacheProvider(userId).future);
});

// Provider internal yang di-cache per userId — hanya fetch 1x per user session
final _userRoleCacheProvider = FutureProvider.family<String?, String>((
  ref,
  userId,
) async {
  // Verifikasi user masih login sebelum fetch
  final currentUser = AuthService.client.auth.currentUser;
  if (currentUser == null || currentUser.id != userId) return null;

  return AuthService.getUserRole();
});
