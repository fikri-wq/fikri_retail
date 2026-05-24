import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AuthService {
  static final client = SupabaseService.client;

  // Login dengan Email
  static Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(email: email, password: password);
  }

  // Daftar Akun Baru
  static Future<AuthResponse> signUp(String email, String password, String fullName) async {
    return await client.auth.signUp(
      email: email, 
      password: password,
      data: {'full_name': fullName},
    );
  }

  // Logout
  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // Ambil Role User Saat Ini
  static Future<String?> getUserRole() async {
    final user = client.auth.currentUser;
    if (user == null) return null;

    final response = await client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();
    
    return response['role'];
  }
}
