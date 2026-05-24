import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Provider untuk memantau status sesi login user
final authStateProvider = StreamProvider<AuthState>((ref) {
  return AuthService.client.auth.onAuthStateChange;
});

// Provider untuk cek role user yang sedang login
final userRoleProvider = FutureProvider<String?>((ref) async {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (state) => AuthService.getUserRole(),
    loading: () => null,
    error: (_, _) => null,
  );
});
