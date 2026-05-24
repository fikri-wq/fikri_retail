import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'auth_provider.dart';
import 'auth_screen.dart';
import '../shop/main_screen.dart';
import '../admin/admin_dashboard.dart';
import '../../services/auth_service.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userRole = ref.watch(userRoleProvider);

    return authState.when(
      data: (session) {
        if (session.session == null) {
          return const AuthScreen();
        }
        
        // Cek Role setelah login
        return userRole.when(
          data: (role) {
            if (role == 'admin') {
              return const AdminDashboard();
            }
            return const MainScreen();
          },
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, stack) => Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Gagal memuat Role: $err'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => AuthService.signOut(), 
                    child: const Text('Logout & Coba Lagi')
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Auth Error: $err'))),
    );
  }
}
