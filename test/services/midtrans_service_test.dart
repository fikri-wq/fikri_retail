/// Unit test untuk MidtransService.
///
/// Karena MidtransService bergantung pada SupabaseService (untuk JWT) dan
/// url_launcher (untuk membuka browser), test ini menggunakan dua pendekatan:
///
/// 1. Pure-logic extraction: Menduplikasi logika murni (buildPaymentUrl,
///    _extractErrorMessage, error-mapping) agar dapat diuji tanpa dependensi
///    eksternal — pola yang sama seperti test lain di proyek ini.
///
/// 2. MockClient dari package:http/testing.dart: Menguji alur createTransaction()
///    dengan response HTTP yang dikontrol tanpa membuat request nyata ke jaringan.
///
/// Validates: Requirements 3.5, 3.6, 1.5
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

// ─── Duplikasi logika murni dari MidtransService ─────────────────────────────

/// Base URL halaman pembayaran Midtrans Sandbox.
/// Harus identik dengan _midtransPaymentBaseUrl di MidtransService.
const String _midtransPaymentBaseUrl =
    'https://app.sandbox.midtrans.com/snap/v2/vtweb/';

/// Duplikasi [MidtransService.buildPaymentUrl].
String buildPaymentUrl(String snapToken) {
  return '$_midtransPaymentBaseUrl$snapToken';
}

/// Duplikasi logika validasi snapToken dari [MidtransService.openPaymentPage].
///
/// Melempar [Exception] jika [snapToken] kosong — identik dengan
/// kondisi guard di implementasi produksi.
void validateSnapTokenForPayment(String snapToken) {
  if (snapToken.isEmpty) {
    throw Exception(
      'Sesi pembayaran tidak valid. Silakan buat pesanan baru.',
    );
  }
}

/// Duplikasi [MidtransService._extractErrorMessage].
String extractErrorMessage(http.Response response) {
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

/// Duplikasi logika pemetaan error HTTP dari [MidtransService.createTransaction].
///
/// Melempar Exception dengan pesan human-readable untuk setiap status code.
/// Pada implementasi asli, ini adalah switch-case setelah memeriksa statusCode.
void throwForStatusCode(int statusCode, http.Response response) {
  final errorMessage = extractErrorMessage(response);

  switch (statusCode) {
    case 401:
      throw Exception('Sesi login tidak valid. Silakan login ulang.');
    case 403:
      throw Exception('Permintaan tidak diizinkan.');
    case 409:
      throw Exception('Pesanan ini sudah memiliki sesi pembayaran aktif.');
    case 504:
      throw Exception('Layanan pembayaran tidak merespons. Coba lagi.');
    default:
      if (statusCode >= 500) {
        throw Exception('Layanan Midtrans sedang gangguan. Coba beberapa saat lagi.');
      }
      if (errorMessage.isNotEmpty) {
        throw Exception(errorMessage);
      }
      throw Exception(
        'Terjadi kesalahan (kode $statusCode). Silakan coba lagi.',
      );
  }
}

// ─── Helper: membuat MockClient yang mengembalikan response tertentu ──────────

/// Membuat [MockClient] yang selalu mengembalikan response statis
/// dengan [statusCode] dan JSON body [body].
MockClient mockClientWithResponse(int statusCode, Map<String, dynamic> body) {
  return MockClient((request) async {
    return http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  });
}

/// Memanggil endpoint Edge Function menggunakan [client] yang diberikan
/// dan melempar Exception sesuai dengan status code respons.
///
/// Ini mereplikasi alur inti [MidtransService.createTransaction] tanpa
/// bergantung pada SupabaseService atau url_launcher.
Future<Map<String, dynamic>> callEdgeFunction({
  required http.Client client,
  required String supabaseUrl,
  required String accessToken,
  required Map<String, dynamic> requestBody,
}) async {
  final uri = Uri.parse(
      '$supabaseUrl/functions/v1/create-midtrans-transaction');

  final http.Response response;
  try {
    response = await client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(requestBody),
    );
  } catch (e) {
    throw Exception(
        'Gagal terhubung ke layanan pembayaran. Periksa koneksi internet.');
  }

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
      throw Exception(
          'Sesi pembayaran tidak valid. Silakan buat pesanan baru.');
    }
    if (redirectUrl == null || redirectUrl.isEmpty) {
      throw Exception(
          'Sesi pembayaran tidak valid. Silakan buat pesanan baru.');
    }

    return data;
  }

  // Error handling berdasarkan HTTP status code
  throwForStatusCode(response.statusCode, response);
  // unreachable, hanya untuk satisfying return type
  throw Exception('Unknown error');
}

// ─── Test minimal request body ────────────────────────────────────────────────

Map<String, dynamic> _sampleRequestBody() => {
      'order_id': 'order-uuid-001',
      'customer_id': 'user-uuid-001',
      'customer_email': 'test@example.com',
      'customer_name': 'Test Customer',
      'customer_phone': '081234567890',
      'total_amount': 100000,
      'items': [
        {
          'product_id': 'prod-001',
          'name': 'Indomie Goreng',
          'price': 3500,
          'quantity': 2,
        }
      ],
    };

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ===========================================================================
  // Group 1: openPaymentPage — validasi snapToken kosong
  // Validates: Requirements 3.5
  // ===========================================================================
  group('openPaymentPage — validasi snapToken', () {
    // Task 6.4: Test openPaymentPage() dengan snapToken kosong → throw exception
    test(
      'snapToken kosong ("") → melempar Exception dengan pesan yang tepat',
      () {
        expect(
          () => validateSnapTokenForPayment(''),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Sesi pembayaran tidak valid. Silakan buat pesanan baru.'),
            ),
          ),
          reason:
              'Req 3.5: snap_token kosong harus melempar Exception dengan '
              'pesan "Sesi pembayaran tidak valid. Silakan buat pesanan baru."',
        );
      },
    );

    test(
      'snapToken kosong ("") → Exception mengandung kata "Sesi pembayaran"',
      () {
        try {
          validateSnapTokenForPayment('');
          fail('Harus melempar Exception');
        } on Exception catch (e) {
          expect(e.toString(), contains('Sesi pembayaran'));
        }
      },
    );

    test(
      'snapToken kosong ("") → Exception mengandung kata "pesanan baru"',
      () {
        try {
          validateSnapTokenForPayment('');
          fail('Harus melempar Exception');
        } on Exception catch (e) {
          expect(e.toString(), contains('pesanan baru'));
        }
      },
    );

    // Verifikasi bahwa token non-kosong tidak melempar Exception
    test(
      'snapToken non-kosong ("valid-token") → tidak melempar Exception',
      () {
        expect(
          () => validateSnapTokenForPayment('valid-token'),
          returnsNormally,
          reason: 'Token valid tidak boleh melempar Exception',
        );
      },
    );

    test(
      'snapToken satu karakter ("a") → tidak melempar Exception',
      () {
        expect(
          () => validateSnapTokenForPayment('a'),
          returnsNormally,
        );
      },
    );

    test(
      'snapToken berisi spasi (" ") → tidak melempar Exception (bukan empty)',
      () {
        // " " bukan empty string, sehingga tidak boleh throw
        expect(
          () => validateSnapTokenForPayment(' '),
          returnsNormally,
        );
      },
    );
  });

  // ===========================================================================
  // Group 2: buildPaymentUrl — berbagai snapToken
  // Validates: Requirements 3.1
  // ===========================================================================
  group('buildPaymentUrl — konstruksi URL pembayaran', () {
    const expectedBase = 'https://app.sandbox.midtrans.com/snap/v2/vtweb/';

    // Task 6.4: Test buildPaymentUrl() dengan berbagai snapToken
    test(
      'buildPaymentUrl("abc123") → URL mengandung snapToken yang benar',
      () {
        expect(
          buildPaymentUrl('abc123'),
          equals('$expectedBase' 'abc123'),
        );
      },
    );

    test(
      'buildPaymentUrl dengan token panjang (64 karakter) → URL terbentuk benar',
      () {
        final token = 'x' * 64;
        expect(buildPaymentUrl(token), equals('$expectedBase$token'));
      },
    );

    test(
      'buildPaymentUrl dengan token mengandung hyphens → URL terbentuk benar',
      () {
        const token = 'order-abc123-def456';
        expect(buildPaymentUrl(token), equals('${expectedBase}order-abc123-def456'));
      },
    );

    test(
      'buildPaymentUrl dengan token mengandung underscores → URL terbentuk benar',
      () {
        const token = 'snap_token_test_123';
        expect(
          buildPaymentUrl(token),
          equals('${expectedBase}snap_token_test_123'),
        );
      },
    );

    test(
      'buildPaymentUrl selalu diawali dengan HTTPS base URL',
      () {
        expect(buildPaymentUrl('any-token'), startsWith('https://'));
        expect(buildPaymentUrl('any-token'), startsWith(expectedBase));
      },
    );

    test(
      'buildPaymentUrl menghasilkan nilai berbeda untuk dua token berbeda',
      () {
        expect(
          buildPaymentUrl('token-aaa'),
          isNot(equals(buildPaymentUrl('token-bbb'))),
        );
      },
    );

    test(
      'buildPaymentUrl idempoten: panggilan berulang menghasilkan nilai sama',
      () {
        const token = 'idempotent-token';
        expect(buildPaymentUrl(token), equals(buildPaymentUrl(token)));
      },
    );

    test(
      'buildPaymentUrl dengan token UUID-like → URL terbentuk benar',
      () {
        const token = '550e8400-e29b-41d4-a716-446655440000';
        expect(
          buildPaymentUrl(token),
          equals('${expectedBase}550e8400-e29b-41d4-a716-446655440000'),
        );
      },
    );

    test(
      'buildPaymentUrl dengan token huruf besar → URL case-sensitive',
      () {
        const token = 'UPPERCASE-TOKEN-ABC';
        expect(
          buildPaymentUrl(token),
          equals('${expectedBase}UPPERCASE-TOKEN-ABC'),
        );
      },
    );

    test(
      'buildPaymentUrl dengan angka saja → URL terbentuk benar',
      () {
        const token = '1234567890';
        expect(
          buildPaymentUrl(token),
          equals('${expectedBase}1234567890'),
        );
      },
    );
  });

  // ===========================================================================
  // Group 3: createTransaction — mock HTTP 401 → pesan "Sesi login tidak valid."
  // Validates: Requirements 1.5
  // ===========================================================================
  group('createTransaction — mock response error 401', () {
    const supabaseUrl = 'https://kboyrjpizxbdudglcwcd.supabase.co';
    const fakeAccessToken = 'fake-jwt-token';

    // Task 6.4: Test createTransaction() dengan mock response error 401
    test(
      'response 401 → melempar Exception "Sesi login tidak valid."',
      () async {
        final client = mockClientWithResponse(
          401,
          {'error': 'Unauthorized'},
        );

        await expectLater(
          callEdgeFunction(
            client: client,
            supabaseUrl: supabaseUrl,
            accessToken: fakeAccessToken,
            requestBody: _sampleRequestBody(),
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Sesi login tidak valid.'),
            ),
          ),
        );
      },
    );

    test(
      'response 401 → Exception mengandung "Silakan login ulang"',
      () async {
        final client = mockClientWithResponse(401, {'error': 'Unauthorized'});

        await expectLater(
          callEdgeFunction(
            client: client,
            supabaseUrl: supabaseUrl,
            accessToken: fakeAccessToken,
            requestBody: _sampleRequestBody(),
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Silakan login ulang'),
            ),
          ),
        );
      },
    );

    test(
      'response 401 dengan body berbeda → tetap melempar pesan standar "Sesi login tidak valid."',
      () async {
        // Pesan dari body DIABAIKAN untuk 401 — selalu gunakan pesan standar
        final client = mockClientWithResponse(
          401,
          {'error': 'Token expired or invalid'},
        );

        await expectLater(
          callEdgeFunction(
            client: client,
            supabaseUrl: supabaseUrl,
            accessToken: fakeAccessToken,
            requestBody: _sampleRequestBody(),
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Sesi login tidak valid.'),
            ),
          ),
        );
      },
    );

    test(
      'response 401 → tidak mengembalikan snap_token (harus throw)',
      () async {
        final client = mockClientWithResponse(
          401,
          {'error': 'Unauthorized'},
        );

        await expectLater(
          callEdgeFunction(
            client: client,
            supabaseUrl: supabaseUrl,
            accessToken: fakeAccessToken,
            requestBody: _sampleRequestBody(),
          ),
          throwsException,
        );
      },
    );
  });

  // ===========================================================================
  // Group 4: createTransaction — mock HTTP 504 → pesan "Layanan pembayaran tidak merespons."
  // Validates: Requirements 1.5
  // ===========================================================================
  group('createTransaction — mock response error 504', () {
    const supabaseUrl = 'https://kboyrjpizxbdudglcwcd.supabase.co';
    const fakeAccessToken = 'fake-jwt-token';

    // Task 6.4: Test createTransaction() dengan mock response error 504
    test(
      'response 504 → melempar Exception "Layanan pembayaran tidak merespons."',
      () async {
        final client = mockClientWithResponse(
          504,
          {'error': 'Gateway Timeout'},
        );

        await expectLater(
          callEdgeFunction(
            client: client,
            supabaseUrl: supabaseUrl,
            accessToken: fakeAccessToken,
            requestBody: _sampleRequestBody(),
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Layanan pembayaran tidak merespons.'),
            ),
          ),
        );
      },
    );

    test(
      'response 504 → Exception mengandung "Coba lagi"',
      () async {
        final client = mockClientWithResponse(504, {'error': 'Timeout'});

        await expectLater(
          callEdgeFunction(
            client: client,
            supabaseUrl: supabaseUrl,
            accessToken: fakeAccessToken,
            requestBody: _sampleRequestBody(),
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Coba lagi'),
            ),
          ),
        );
      },
    );

    test(
      'response 504 dengan body berbeda → tetap melempar pesan standar timeout',
      () async {
        final client = mockClientWithResponse(
          504,
          {'error': 'Midtrans API did not respond in time'},
        );

        await expectLater(
          callEdgeFunction(
            client: client,
            supabaseUrl: supabaseUrl,
            accessToken: fakeAccessToken,
            requestBody: _sampleRequestBody(),
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Layanan pembayaran tidak merespons.'),
            ),
          ),
        );
      },
    );
  });

  // ===========================================================================
  // Group 5: createTransaction — skenario error lainnya
  // Validates: Requirements 1.5
  // ===========================================================================
  group('createTransaction — skenario error HTTP lain', () {
    const supabaseUrl = 'https://kboyrjpizxbdudglcwcd.supabase.co';
    const fakeAccessToken = 'fake-jwt-token';

    test(
      'response 403 → melempar Exception "Permintaan tidak diizinkan."',
      () async {
        final client = mockClientWithResponse(403, {'error': 'Forbidden'});

        await expectLater(
          callEdgeFunction(
            client: client,
            supabaseUrl: supabaseUrl,
            accessToken: fakeAccessToken,
            requestBody: _sampleRequestBody(),
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Permintaan tidak diizinkan.'),
            ),
          ),
        );
      },
    );

    test(
      'response 409 → melempar Exception "sudah memiliki sesi pembayaran aktif"',
      () async {
        final client = mockClientWithResponse(
          409,
          {'error': 'snap_token already exists'},
        );

        await expectLater(
          callEdgeFunction(
            client: client,
            supabaseUrl: supabaseUrl,
            accessToken: fakeAccessToken,
            requestBody: _sampleRequestBody(),
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('sudah memiliki sesi pembayaran aktif'),
            ),
          ),
        );
      },
    );

    test(
      'response 500 → melempar Exception "Layanan Midtrans sedang gangguan"',
      () async {
        final client = mockClientWithResponse(
          500,
          {'error': 'Internal Server Error'},
        );

        await expectLater(
          callEdgeFunction(
            client: client,
            supabaseUrl: supabaseUrl,
            accessToken: fakeAccessToken,
            requestBody: _sampleRequestBody(),
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Layanan Midtrans sedang gangguan'),
            ),
          ),
        );
      },
    );

    test(
      'response 200 dengan snap_token dan redirect_url valid → mengembalikan data',
      () async {
        final client = mockClientWithResponse(200, {
          'snap_token': 'valid-snap-token-abc123',
          'redirect_url': 'https://app.sandbox.midtrans.com/snap/v2/vtweb/valid-snap-token-abc123',
        });

        final result = await callEdgeFunction(
          client: client,
          supabaseUrl: supabaseUrl,
          accessToken: fakeAccessToken,
          requestBody: _sampleRequestBody(),
        );

        expect(result['snap_token'], equals('valid-snap-token-abc123'));
        expect(result['redirect_url'], isNotEmpty);
      },
    );

    test(
      'response 200 dengan snap_token kosong → melempar Exception "Sesi pembayaran tidak valid"',
      () async {
        final client = mockClientWithResponse(200, {
          'snap_token': '',
          'redirect_url': 'https://app.sandbox.midtrans.com/...',
        });

        await expectLater(
          callEdgeFunction(
            client: client,
            supabaseUrl: supabaseUrl,
            accessToken: fakeAccessToken,
            requestBody: _sampleRequestBody(),
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Sesi pembayaran tidak valid'),
            ),
          ),
        );
      },
    );
  });

  // ===========================================================================
  // Group 6: extractErrorMessage — helper
  // ===========================================================================
  group('_extractErrorMessage — mengekstrak pesan error dari response body', () {
    test(
      'body JSON dengan field "error" → mengembalikan pesan error',
      () {
        final response = http.Response(
          jsonEncode({'error': 'Something went wrong'}),
          400,
        );
        expect(extractErrorMessage(response), equals('Something went wrong'));
      },
    );

    test(
      'body JSON tanpa field "error" → mengembalikan string kosong',
      () {
        final response = http.Response(
          jsonEncode({'message': 'ok'}),
          400,
        );
        expect(extractErrorMessage(response), equals(''));
      },
    );

    test(
      'body bukan JSON valid → mengembalikan string kosong (tidak throw)',
      () {
        final response = http.Response('not-json-at-all', 400);
        expect(extractErrorMessage(response), equals(''));
      },
    );

    test(
      'body kosong → mengembalikan string kosong (tidak throw)',
      () {
        final response = http.Response('', 400);
        expect(extractErrorMessage(response), equals(''));
      },
    );

    test(
      'field "error" adalah string kosong → mengembalikan string kosong',
      () {
        final response = http.Response(
          jsonEncode({'error': ''}),
          400,
        );
        expect(extractErrorMessage(response), equals(''));
      },
    );
  });
}
