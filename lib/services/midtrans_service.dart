import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/constants.dart';
import '../services/supabase_service.dart';

/// Hasil dari pemanggilan Edge Function create-midtrans-transaction.
class MidtransTokenResult {
  final String snapToken;
  final String redirectUrl;

  const MidtransTokenResult({
    required this.snapToken,
    required this.redirectUrl,
  });
}

/// Service layer untuk berkomunikasi dengan Edge Function Midtrans.
///
/// Tanggung jawab:
/// - Ambil JWT dari sesi Supabase yang aktif
/// - Kirim HTTP POST ke Edge Function create-midtrans-transaction
/// - Parse response dan lempar Exception dengan pesan yang dapat dibaca user
/// - Bangun URL halaman pembayaran Midtrans dari snap_token
///
/// CATATAN KEAMANAN (Requirement 8.1):
/// File ini TIDAK boleh mengandung Server_Key Midtrans dalam bentuk apapun.
/// Server_Key hanya disimpan di environment variable Edge Function.
class MidtransService {
  static const String _edgeFunctionPath = '/functions/v1/create-midtrans-transaction';
  static const String _midtransPaymentBaseUrl =
      'https://app.sandbox.midtrans.com/snap/v2/vtweb/';

  /// Memanggil Edge Function untuk membuat transaksi Midtrans dan
  /// mendapatkan snap_token beserta redirect_url.
  ///
  /// Throws [Exception] dengan pesan human-readable untuk setiap skenario error:
  /// - 401 → sesi login tidak valid
  /// - 403 → permintaan tidak diizinkan
  /// - 409 → pesanan sudah memiliki sesi pembayaran aktif
  /// - 504 → layanan tidak merespons
  /// - 5xx → layanan Midtrans sedang gangguan
  /// - lainnya → pesan dari body response jika tersedia
  Future<MidtransTokenResult> createTransaction({
    required String orderId,
    required String customerId,
    required String customerEmail,
    required String customerName,
    required String customerPhone,
    required int totalAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    // Ambil JWT dari sesi aktif
    final session = SupabaseService.client.auth.currentSession;
    if (session == null) {
      throw Exception('Sesi login tidak valid. Silakan login ulang.');
    }
    final accessToken = session.accessToken;

    // Bangun URL Edge Function
    final uri = Uri.parse('${AppConstants.supabaseUrl}$_edgeFunctionPath');

    // Bangun request body
    final body = jsonEncode({
      'order_id': orderId,
      'customer_id': customerId,
      'customer_email': customerEmail,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'total_amount': totalAmount,
      'items': items,
    });

    // Kirim HTTP POST ke Edge Function
    final http.Response response;
    try {
      response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: body,
      );
    } catch (e) {
      throw Exception('Gagal terhubung ke layanan pembayaran. Periksa koneksi internet.');
    }

    // Handle response berdasarkan status code
    if (response.statusCode == 200) {
      final Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw Exception('Respons dari layanan pembayaran tidak valid.');
      }

      final snapToken = data['snap_token'] as String?;
      final redirectUrl = data['redirect_url'] as String?;

      if (snapToken == null || snapToken.isEmpty) {
        throw Exception('Sesi pembayaran tidak valid. Silakan buat pesanan baru.');
      }
      if (redirectUrl == null || redirectUrl.isEmpty) {
        throw Exception('Sesi pembayaran tidak valid. Silakan buat pesanan baru.');
      }

      return MidtransTokenResult(
        snapToken: snapToken,
        redirectUrl: redirectUrl,
      );
    }

    // Error handling berdasarkan HTTP status code
    final String errorMessage = _extractErrorMessage(response);

    switch (response.statusCode) {
      case 401:
        throw Exception('Sesi login tidak valid. Silakan login ulang.');
      case 403:
        throw Exception('Permintaan tidak diizinkan.');
      case 409:
        throw Exception('Pesanan ini sudah memiliki sesi pembayaran aktif.');
      case 504:
        throw Exception('Layanan pembayaran tidak merespons. Coba lagi.');
      default:
        if (response.statusCode >= 500) {
          throw Exception('Layanan Midtrans sedang gangguan. Coba beberapa saat lagi.');
        }
        // Error 4xx lainnya: tampilkan pesan dari body response jika tersedia
        if (errorMessage.isNotEmpty) {
          throw Exception(errorMessage);
        }
        throw Exception(
          'Terjadi kesalahan (kode ${response.statusCode}). Silakan coba lagi.',
        );
    }
  }

  /// Membuka halaman pembayaran Midtrans di browser eksternal.
  ///
  /// Membangun URL `https://app.sandbox.midtrans.com/snap/v2/vtweb/{snapToken}`,
  /// lalu membukanya dengan `LaunchMode.externalApplication`.
  ///
  /// Throws [Exception] dengan pesan human-readable jika:
  /// - [snapToken] kosong → "Sesi pembayaran tidak valid. Silakan buat pesanan baru."
  /// - Browser tidak tersedia / `canLaunchUrl` false → "Tidak dapat membuka halaman
  ///   pembayaran. Pastikan browser tersedia."
  Future<void> openPaymentPage(String snapToken) async {
    if (snapToken.isEmpty) {
      throw Exception(
        'Sesi pembayaran tidak valid. Silakan buat pesanan baru.',
      );
    }
    final url = Uri.parse(buildPaymentUrl(snapToken));
    final canLaunch = await canLaunchUrl(url);
    if (!canLaunch) {
      throw Exception(
        'Tidak dapat membuka halaman pembayaran. Pastikan browser tersedia.',
      );
    }
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  /// Membangun URL halaman pembayaran Midtrans dari snap_token.
  ///
  /// Property 5 (Correctness):
  /// ∀ snapToken (non-empty String):
  ///   buildPaymentUrl(snapToken) ==
  ///   'https://app.sandbox.midtrans.com/snap/v2/vtweb/' + snapToken
  String buildPaymentUrl(String snapToken) {
    return '$_midtransPaymentBaseUrl$snapToken';
  }

  // ---------------------------------------------------------------------------
  // Helper privat
  // ---------------------------------------------------------------------------

  /// Mengekstrak pesan error dari body response JSON.
  /// Mengembalikan string kosong jika tidak ada pesan error.
  String _extractErrorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error'];
      if (error is String && error.isNotEmpty) {
        return error;
      }
    } catch (_) {
      // Body bukan JSON valid; abaikan
    }
    return '';
  }
}
