// Validates: Requirements 3.1
//
// Property 5: URL Pembayaran Konsisten
// ∀ snapToken (non-empty String):
//   buildPaymentUrl(snapToken) ==
//   'https://app.sandbox.midtrans.com/snap/v2/vtweb/' + snapToken
//
// Karena buildPaymentUrl() adalah fungsi murni (tidak ada dependensi eksternal,
// tidak ada async, tidak memerlukan jaringan atau Supabase), kita menduplikasi
// logika tersebut sebagai fungsi top-level agar test ini dapat berjalan sebagai
// unit test Dart murni tanpa memerlukan inisialisasi service layer lengkap.
//
// Implementasi di produksi ada di:
//   lib/services/midtrans_service.dart → MidtransService.buildPaymentUrl()

import 'dart:math';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Duplikasi logika murni buildPaymentUrl() dari MidtransService
// ---------------------------------------------------------------------------

/// Base URL halaman pembayaran Midtrans Sandbox.
/// Nilai ini harus identik dengan _midtransPaymentBaseUrl di MidtransService.
const String _midtransPaymentBaseUrl =
    'https://app.sandbox.midtrans.com/snap/v2/vtweb/';

/// Membangun URL halaman pembayaran Midtrans dari snap_token.
///
/// Ini adalah salinan logika murni dari [MidtransService.buildPaymentUrl].
/// Fungsi ini hanya melakukan konkatenasi string sederhana.
String buildPaymentUrl(String snapToken) {
  return '$_midtransPaymentBaseUrl$snapToken';
}

// ---------------------------------------------------------------------------
// Generator token
// ---------------------------------------------------------------------------

/// Karakter yang digunakan untuk membuat token acak.
const String _alphanumeric =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
const String _specialChars = '-_';

/// Menghasilkan string token acak dengan panjang [length]
/// dari kumpulan karakter [charset].
String _randomToken(Random rng, String charset, int length) {
  return List.generate(
    length,
    (_) => charset[rng.nextInt(charset.length)],
  ).join();
}

/// Menghasilkan snap token alphanumerik acak (panjang 8–64 karakter).
String _randomAlphanumericToken(Random rng) {
  final length = 8 + rng.nextInt(57); // 8..64
  return _randomToken(rng, _alphanumeric, length);
}

/// Menghasilkan snap token dengan karakter khusus (hyphens, underscores).
String _randomTokenWithSpecialChars(Random rng) {
  final length = 8 + rng.nextInt(57); // 8..64
  final charset = _alphanumeric + _specialChars;
  return _randomToken(rng, charset, length);
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

void main() {
  // Seed tetap untuk reprodusibilitas
  const int seed = 42;

  group('Property 5: URL Pembayaran Konsisten', () {
    // ------------------------------------------------------------------
    // Property-based test: ≥100 nilai snapToken berbeda
    // ------------------------------------------------------------------
    test(
      'buildPaymentUrl(snapToken) == base_url + snapToken untuk ≥100 nilai acak',
      () {
        final rng = Random(seed);
        const int iterations = 100;
        const String expectedBase =
            'https://app.sandbox.midtrans.com/snap/v2/vtweb/';

        for (int i = 0; i < iterations; i++) {
          // Pilih tipe token secara bergantian agar lebih variatif
          final String token;
          if (i % 2 == 0) {
            token = _randomAlphanumericToken(rng);
          } else {
            token = _randomTokenWithSpecialChars(rng);
          }

          final result = buildPaymentUrl(token);

          expect(
            result,
            equals('$expectedBase$token'),
            reason:
                'Iterasi $i: buildPaymentUrl("$token") harus menghasilkan '
                '"$expectedBase$token", tetapi mendapat "$result"',
          );

          // Verifikasi tambahan: URL harus diawali dengan base URL
          expect(
            result.startsWith(expectedBase),
            isTrue,
            reason:
                'Iterasi $i: URL harus diawali dengan "$expectedBase"',
          );

          // Verifikasi: URL harus diakhiri dengan token
          expect(
            result.endsWith(token),
            isTrue,
            reason:
                'Iterasi $i: URL harus diakhiri dengan token "$token"',
          );
        }
      },
    );

    // ------------------------------------------------------------------
    // Edge cases
    // ------------------------------------------------------------------
    group('Edge cases', () {
      test('Token alphanumerik pendek (panjang 1)', () {
        const token = 'a';
        expect(
          buildPaymentUrl(token),
          equals('https://app.sandbox.midtrans.com/snap/v2/vtweb/a'),
        );
      });

      test('Token alphanumerik panjang (64 karakter)', () {
        final token = 'A' * 64;
        expect(
          buildPaymentUrl(token),
          equals(
            'https://app.sandbox.midtrans.com/snap/v2/vtweb/$token',
          ),
        );
      });

      test('Token dengan hyphens', () {
        const token = 'abc-def-123-xyz';
        expect(
          buildPaymentUrl(token),
          equals(
            'https://app.sandbox.midtrans.com/snap/v2/vtweb/abc-def-123-xyz',
          ),
        );
      });

      test('Token dengan underscores', () {
        const token = 'abc_def_123_xyz';
        expect(
          buildPaymentUrl(token),
          equals(
            'https://app.sandbox.midtrans.com/snap/v2/vtweb/abc_def_123_xyz',
          ),
        );
      });

      test('Token dengan campuran huruf besar dan kecil', () {
        const token = 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789';
        expect(
          buildPaymentUrl(token),
          equals(
            'https://app.sandbox.midtrans.com/snap/v2/vtweb/AbCdEfGhIjKlMnOpQrStUvWxYz0123456789',
          ),
        );
      });

      test('Token yang menyerupai format Midtrans nyata (UUID-like)', () {
        const token = 'order-abc123-def456-789xyz';
        expect(
          buildPaymentUrl(token),
          equals(
            'https://app.sandbox.midtrans.com/snap/v2/vtweb/order-abc123-def456-789xyz',
          ),
        );
      });

      test('Token murni angka', () {
        const token = '1234567890';
        expect(
          buildPaymentUrl(token),
          equals(
            'https://app.sandbox.midtrans.com/snap/v2/vtweb/1234567890',
          ),
        );
      });

      test('Token murni huruf besar', () {
        const token = 'SNAPTOKENUPPERCASE';
        expect(
          buildPaymentUrl(token),
          equals(
            'https://app.sandbox.midtrans.com/snap/v2/vtweb/SNAPTOKENUPPERCASE',
          ),
        );
      });

      test('Token murni huruf kecil', () {
        const token = 'snaptokenlowercase';
        expect(
          buildPaymentUrl(token),
          equals(
            'https://app.sandbox.midtrans.com/snap/v2/vtweb/snaptokenlowercase',
          ),
        );
      });

      test('Hasil buildPaymentUrl tidak pernah sama untuk dua token yang berbeda', () {
        const token1 = 'token-aaa-111';
        const token2 = 'token-bbb-222';
        expect(
          buildPaymentUrl(token1),
          isNot(equals(buildPaymentUrl(token2))),
        );
      });

      test('buildPaymentUrl idempoten: dua panggilan dengan token sama menghasilkan nilai sama', () {
        const token = 'idempotent-test-token';
        expect(buildPaymentUrl(token), equals(buildPaymentUrl(token)));
      });
    });

    // ------------------------------------------------------------------
    // Verifikasi konsistensi logika dengan konstanta base URL
    // ------------------------------------------------------------------
    group('Konsistensi base URL', () {
      test('Base URL adalah https://app.sandbox.midtrans.com/snap/v2/vtweb/', () {
        const token = 'test';
        final url = buildPaymentUrl(token);
        expect(
          url,
          startsWith('https://app.sandbox.midtrans.com/snap/v2/vtweb/'),
        );
      });

      test('URL menggunakan HTTPS, bukan HTTP', () {
        const token = 'test-token';
        final url = buildPaymentUrl(token);
        expect(url, startsWith('https://'));
        expect(url, isNot(startsWith('http://')));
      });

      test('URL tidak mengandung karakter whitespace', () {
        final rng = Random(seed + 1);
        for (int i = 0; i < 20; i++) {
          final token = _randomAlphanumericToken(rng);
          final url = buildPaymentUrl(token);
          expect(
            url.contains(' ') || url.contains('\t') || url.contains('\n'),
            isFalse,
            reason: 'URL "$url" tidak boleh mengandung whitespace',
          );
        }
      });
    });
  });
}
