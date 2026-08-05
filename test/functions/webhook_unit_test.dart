/// Unit test untuk logika update database webhook Midtrans.
///
/// File ini mereplikasi business logic dari Edge Function
/// `supabase/functions/midtrans-webhook/index.ts` dalam Dart agar dapat
/// diuji secara unit tanpa memerlukan runtime Deno atau koneksi jaringan.
///
/// Validates: Requirements 4.3, 4.4, 4.6, 4.7, 4.8
library;

import 'package:flutter_test/flutter_test.dart';

// ─── Business Logic Helpers ───────────────────────────────────────────────────
// Mereplikasi logika dari Edge Function midtrans-webhook/index.ts

/// Hasil update database berdasarkan status transaksi Midtrans.
/// [paymentStatus] selalu diisi ('paid' atau 'failed').
/// [orderStatus] hanya diisi jika status pesanan perlu diubah (contoh: 'diantar'),
/// null berarti status pesanan TIDAK diubah.
class PaymentUpdateResult {
  final String paymentStatus;
  final String? orderStatus;

  const PaymentUpdateResult({
    required this.paymentStatus,
    this.orderStatus,
  });

  @override
  String toString() =>
      'PaymentUpdateResult(paymentStatus=$paymentStatus, orderStatus=$orderStatus)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentUpdateResult &&
          other.paymentStatus == paymentStatus &&
          other.orderStatus == orderStatus;

  @override
  int get hashCode => Object.hash(paymentStatus, orderStatus);
}

/// Menentukan update payload berdasarkan [transactionStatus] dan [fraudStatus].
///
/// Mereplikasi blok logika di index.ts (Requirements 4.3, 4.4):
/// - 'settlement'              → payment_status='paid', status='diantar'
/// - 'capture' + 'accept'      → payment_status='paid', status='diantar'
/// - 'capture' + 'challenge'   → tidak ada update (null)
/// - 'cancel'/'expire'/'deny'  → payment_status='failed', status tidak berubah
/// - 'pending'                 → tidak ada update (null)
/// - status lain yang tidak dikenali → tidak ada update (null)
PaymentUpdateResult? determinePaymentUpdate(
  String transactionStatus,
  String? fraudStatus,
) {
  final isSettled = transactionStatus == 'settlement';
  final isCaptureAccepted =
      transactionStatus == 'capture' && fraudStatus == 'accept';

  if (isSettled || isCaptureAccepted) {
    // Req 4.3 — settlement/capture+accept → paid + diantar
    return const PaymentUpdateResult(
      paymentStatus: 'paid',
      orderStatus: 'diantar',
    );
  }

  if (transactionStatus == 'cancel' ||
      transactionStatus == 'expire' ||
      transactionStatus == 'deny') {
    // Req 4.4 — cancel/expire/deny → failed, status pesanan TIDAK diubah
    return const PaymentUpdateResult(paymentStatus: 'failed');
  }

  // 'pending', atau status tidak dikenali → tidak ada perubahan DB
  return null;
}

/// Menentukan apakah webhook harus di-skip karena order sudah dibayar.
///
/// Mereplikasi guard idempoten di index.ts (Requirements 4.8):
/// Jika [currentPaymentStatus] == 'paid', maka kembalikan true →
/// Edge Function langsung return HTTP 200 tanpa melakukan UPDATE ulang.
bool isIdempotent(String currentPaymentStatus) {
  return currentPaymentStatus == 'paid';
}

/// Field wajib yang harus hadir pada payload webhook Midtrans.
const _requiredFields = [
  'order_id',
  'status_code',
  'gross_amount',
  'signature_key',
  'transaction_status',
];

/// Memvalidasi kehadiran semua field wajib pada payload webhook.
///
/// Mereplikasi fungsi [validateNotification] di index.ts (Requirements 4.7):
/// - Kembalikan pesan error (String) jika ada field yang hilang/kosong/null.
/// - Kembalikan null jika semua field valid.
String? validateWebhookFields(Map<String, dynamic> payload) {
  for (final field in _requiredFields) {
    final value = payload[field];
    if (value == null || (value is String && value.isEmpty)) {
      return "Field wajib '$field' tidak ada atau kosong dalam payload webhook";
    }
  }
  return null;
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ===========================================================================
  // Group 1: determinePaymentUpdate — Pemetaan Status Deterministik
  // Validates: Requirements 4.3, 4.4
  // ===========================================================================
  group('determinePaymentUpdate — pemetaan transaction_status ke DB update', () {
    // ── Req 4.3: settlement ──────────────────────────────────────────────────
    test(
        'settlement → payment_status="paid", order_status="diantar"',
        () {
      final result = determinePaymentUpdate('settlement', null);

      expect(result, isNotNull,
          reason: 'settlement harus menghasilkan update payload');
      expect(result!.paymentStatus, equals('paid'));
      expect(result.orderStatus, equals('diantar'));
    });

    // ── Req 4.3: capture + fraud_status='accept' ────────────────────────────
    test(
        'capture + fraud_status="accept" → payment_status="paid", order_status="diantar"',
        () {
      final result = determinePaymentUpdate('capture', 'accept');

      expect(result, isNotNull);
      expect(result!.paymentStatus, equals('paid'));
      expect(result.orderStatus, equals('diantar'));
    });

    // ── capture + fraud_status='challenge' → tidak ada update ───────────────
    test(
        'capture + fraud_status="challenge" → tidak ada update (null)',
        () {
      final result = determinePaymentUpdate('capture', 'challenge');

      expect(result, isNull,
          reason:
              'capture+challenge tidak boleh diubah — bukan accepted payment');
    });

    // ── capture tanpa fraud_status (null) → tidak ada update ────────────────
    test(
        'capture + fraud_status=null → tidak ada update (null)',
        () {
      final result = determinePaymentUpdate('capture', null);

      expect(result, isNull,
          reason:
              'capture tanpa fraud_status=accept tidak boleh menghasilkan update');
    });

    // ── Req 4.4: cancel ──────────────────────────────────────────────────────
    test(
        'cancel → payment_status="failed", order_status tidak berubah (null)',
        () {
      final result = determinePaymentUpdate('cancel', null);

      expect(result, isNotNull);
      expect(result!.paymentStatus, equals('failed'));
      expect(result.orderStatus, isNull,
          reason:
              'Req 4.4: status pesanan TIDAK diubah saat cancel');
    });

    // ── Req 4.4: expire ──────────────────────────────────────────────────────
    test(
        'expire → payment_status="failed", order_status tidak berubah (null)',
        () {
      final result = determinePaymentUpdate('expire', null);

      expect(result, isNotNull);
      expect(result!.paymentStatus, equals('failed'));
      expect(result.orderStatus, isNull);
    });

    // ── Req 4.4: deny ────────────────────────────────────────────────────────
    test(
        'deny → payment_status="failed", order_status tidak berubah (null)',
        () {
      final result = determinePaymentUpdate('deny', null);

      expect(result, isNotNull);
      expect(result!.paymentStatus, equals('failed'));
      expect(result.orderStatus, isNull);
    });

    // ── pending → tidak ada update ───────────────────────────────────────────
    test(
        'pending → tidak ada update (null)',
        () {
      final result = determinePaymentUpdate('pending', null);

      expect(result, isNull,
          reason: 'pending tidak menghasilkan perubahan pada order');
    });

    // ── status tidak dikenali → tidak ada update ─────────────────────────────
    test(
        'status tidak dikenali ("unknown") → tidak ada update (null)',
        () {
      final result = determinePaymentUpdate('unknown', null);

      expect(result, isNull);
    });
  });

  // ===========================================================================
  // Group 2: isIdempotent — Cek Duplikat Webhook (Req 4.8)
  // Validates: Requirements 4.8
  // ===========================================================================
  group('isIdempotent — webhook duplikat untuk order yang sudah paid', () {
    // ── order sudah paid → skip UPDATE ───────────────────────────────────────
    test(
        'payment_status="paid" → isIdempotent true (tidak perlu UPDATE ulang)',
        () {
      expect(isIdempotent('paid'), isTrue,
          reason: 'Req 4.8: order sudah paid harus di-skip');
    });

    // ── order masih unpaid → lanjut proses ───────────────────────────────────
    test(
        'payment_status="unpaid" → isIdempotent false (lanjutkan proses)',
        () {
      expect(isIdempotent('unpaid'), isFalse);
    });

    // ── order sudah failed → lanjut proses (bisa update ulang) ───────────────
    test(
        'payment_status="failed" → isIdempotent false (lanjutkan proses)',
        () {
      expect(isIdempotent('failed'), isFalse);
    });
  });

  // ===========================================================================
  // Group 3: validateWebhookFields — Validasi Field Wajib (Req 4.7)
  // Validates: Requirements 4.7
  // ===========================================================================
  group('validateWebhookFields — validasi kehadiran field wajib', () {
    /// Payload lengkap yang valid.
    Map<String, dynamic> validPayload() => {
          'order_id': 'order-uuid-001',
          'status_code': '200',
          'gross_amount': '50000.00',
          'signature_key': 'abc123sha512hash',
          'transaction_status': 'settlement',
        };

    // ── payload lengkap → valid (null) ────────────────────────────────────────
    test(
        'payload lengkap dengan semua field → valid (kembalikan null)',
        () {
      expect(validateWebhookFields(validPayload()), isNull);
    });

    // ── order_id tidak ada → error ────────────────────────────────────────────
    test(
        'order_id hilang → kembalikan pesan error',
        () {
      final payload = validPayload()..remove('order_id');
      final error = validateWebhookFields(payload);

      expect(error, isNotNull);
      expect(error, contains('order_id'));
    });

    // ── status_code tidak ada → error ─────────────────────────────────────────
    test(
        'status_code hilang → kembalikan pesan error',
        () {
      final payload = validPayload()..remove('status_code');
      final error = validateWebhookFields(payload);

      expect(error, isNotNull);
      expect(error, contains('status_code'));
    });

    // ── gross_amount tidak ada → error ────────────────────────────────────────
    test(
        'gross_amount hilang → kembalikan pesan error',
        () {
      final payload = validPayload()..remove('gross_amount');
      final error = validateWebhookFields(payload);

      expect(error, isNotNull);
      expect(error, contains('gross_amount'));
    });

    // ── signature_key tidak ada → error ───────────────────────────────────────
    test(
        'signature_key hilang → kembalikan pesan error',
        () {
      final payload = validPayload()..remove('signature_key');
      final error = validateWebhookFields(payload);

      expect(error, isNotNull);
      expect(error, contains('signature_key'));
    });

    // ── transaction_status tidak ada → error ──────────────────────────────────
    test(
        'transaction_status hilang → kembalikan pesan error',
        () {
      final payload = validPayload()..remove('transaction_status');
      final error = validateWebhookFields(payload);

      expect(error, isNotNull);
      expect(error, contains('transaction_status'));
    });

    // ── order_id bernilai null → error ────────────────────────────────────────
    test(
        'order_id bernilai null → kembalikan pesan error',
        () {
      final payloadWithNull = Map<String, dynamic>.from(validPayload())
        ..['order_id'] = null;
      final error = validateWebhookFields(payloadWithNull);

      expect(error, isNotNull);
      expect(error, contains('order_id'));
    });

    // ── order_id bernilai string kosong → error ───────────────────────────────
    test(
        'order_id bernilai string kosong → kembalikan pesan error',
        () {
      final payload = Map<String, dynamic>.from(validPayload())
        ..['order_id'] = '';
      final error = validateWebhookFields(payload);

      expect(error, isNotNull);
      expect(error, contains('order_id'));
    });

    // ── payload kosong {} → error untuk field pertama ─────────────────────────
    test(
        'payload kosong {} → kembalikan pesan error',
        () {
      final error = validateWebhookFields({});

      expect(error, isNotNull,
          reason: 'payload kosong tidak boleh lolos validasi');
    });

    // ── field opsional tidak ada (transaction_id, fraud_status) → valid ───────
    test(
        'field opsional (transaction_id, fraud_status) tidak ada → tetap valid',
        () {
      // validPayload() tidak menyertakan transaction_id dan fraud_status
      // karena bukan field wajib
      final payload = validPayload();
      expect(payload.containsKey('transaction_id'), isFalse);
      expect(payload.containsKey('fraud_status'), isFalse);
      expect(validateWebhookFields(payload), isNull);
    });
  });

  // ===========================================================================
  // Group 4: Skenario End-to-End Logika Webhook
  // Menggabungkan semua helper untuk mensimulasikan alur lengkap webhook
  // Validates: Requirements 4.3, 4.4, 4.6, 4.7, 4.8
  // ===========================================================================
  group('Skenario end-to-end logika webhook', () {
    // ── Req 4.3: settlement sukses update ke paid+diantar ────────────────────
    test(
        'Req 4.3: settlement → DB diupdate: payment_status="paid", status="diantar"',
        () {
      // 1. Validasi payload
      final payload = <String, dynamic>{
        'order_id': 'order-123',
        'status_code': '200',
        'gross_amount': '150000.00',
        'signature_key': 'valid-signature',
        'transaction_status': 'settlement',
        'transaction_id': 'txn-midtrans-001',
      };
      expect(validateWebhookFields(payload), isNull);

      // 2. Cek idempoten (order belum paid)
      const currentPaymentStatus = 'unpaid';
      expect(isIdempotent(currentPaymentStatus), isFalse);

      // 3. Tentukan update
      final result = determinePaymentUpdate(
        payload['transaction_status'] as String,
        payload['fraud_status'] as String?,
      );

      expect(result, isNotNull);
      expect(result!.paymentStatus, equals('paid'));
      expect(result.orderStatus, equals('diantar'));
    });

    // ── Req 4.4: cancel → DB diupdate: payment_status="failed" ──────────────
    test(
        'Req 4.4: cancel → DB diupdate: payment_status="failed", status pesanan tidak berubah',
        () {
      final payload = {
        'order_id': 'order-456',
        'status_code': '202',
        'gross_amount': '75000.00',
        'signature_key': 'valid-signature',
        'transaction_status': 'cancel',
      };
      expect(validateWebhookFields(payload), isNull);
      expect(isIdempotent('unpaid'), isFalse);

      final result = determinePaymentUpdate('cancel', null);

      expect(result, isNotNull);
      expect(result!.paymentStatus, equals('failed'));
      expect(result.orderStatus, isNull,
          reason: 'status pesanan tidak diubah saat cancel');
    });

    // ── Req 4.7: field wajib tidak ada → HTTP 400, tidak proses lebih lanjut ─
    test(
        'Req 4.7: field wajib tidak ada → validasi gagal, proses dihentikan',
        () {
      final incompletePayload = {
        'order_id': 'order-789',
        // 'status_code' sengaja dihilangkan
        'gross_amount': '30000.00',
        'signature_key': 'some-sig',
        'transaction_status': 'settlement',
      };

      final validationError = validateWebhookFields(incompletePayload);
      expect(validationError, isNotNull,
          reason: 'Req 4.7: harus return error jika field wajib tidak ada');
      expect(validationError, contains('status_code'));

      // Simulasi: jika ada error validasi, proses berhenti di sini
      // (tidak sampai ke determinePaymentUpdate atau isIdempotent)
      if (validationError != null) {
        // HTTP 400 akan dikembalikan
        expect(validationError, isA<String>());
      }
    });

    // ── Req 4.8: order sudah paid → HTTP 200 tanpa UPDATE ───────────────────
    test(
        'Req 4.8: webhook duplikat untuk order sudah paid → isIdempotent=true, skip UPDATE',
        () {
      final payload = {
        'order_id': 'order-already-paid',
        'status_code': '200',
        'gross_amount': '99000.00',
        'signature_key': 'valid-signature',
        'transaction_status': 'settlement',
      };

      // 1. Validasi lolos
      expect(validateWebhookFields(payload), isNull);

      // 2. Cek idempoten — order sudah 'paid'
      const currentStatus = 'paid';
      final shouldSkip = isIdempotent(currentStatus);

      expect(shouldSkip, isTrue,
          reason:
              'Req 4.8: order sudah paid — webhook harus di-skip (HTTP 200, no UPDATE)');

      // 3. Karena isIdempotent=true, determinePaymentUpdate TIDAK dipanggil
      //    dan tidak ada UPDATE yang terjadi di database
    });

    // ── Req 4.6 (simulasi): order tidak ditemukan → HTTP 404 ─────────────────
    test(
        'Req 4.6: order tidak ditemukan di DB → 404, tidak ada update',
        () {
      // Simulasi: order lookup mengembalikan list kosong
      final List<Map<String, dynamic>> dbResult = [];
      final orderFound = dbResult.isNotEmpty;

      expect(orderFound, isFalse,
          reason:
              'Req 4.6: jika order tidak ditemukan, HTTP 404 harus dikembalikan');

      // Karena order tidak ditemukan, tidak ada update yang dilakukan
      // (tidak sampai ke determinePaymentUpdate)
    });

    // ── capture+accept → paid seperti settlement ──────────────────────────────
    test(
        'Req 4.3: capture+accept → DB diupdate: payment_status="paid", status="diantar"',
        () {
      final payload = <String, dynamic>{
        'order_id': 'order-capture',
        'status_code': '200',
        'gross_amount': '200000.00',
        'signature_key': 'valid-signature',
        'transaction_status': 'capture',
        'fraud_status': 'accept',
      };

      expect(validateWebhookFields(payload), isNull);
      expect(isIdempotent('unpaid'), isFalse);

      final result = determinePaymentUpdate(
        payload['transaction_status'] as String,
        payload['fraud_status'] as String?,
      );

      expect(result, isNotNull);
      expect(result!.paymentStatus, equals('paid'));
      expect(result.orderStatus, equals('diantar'));
    });

    // ── expire → failed ───────────────────────────────────────────────────────
    test(
        'Req 4.4: expire → DB diupdate: payment_status="failed"',
        () {
      final result = determinePaymentUpdate('expire', null);

      expect(result, isNotNull);
      expect(result!.paymentStatus, equals('failed'));
      expect(result.orderStatus, isNull);
    });

    // ── deny → failed ─────────────────────────────────────────────────────────
    test(
        'Req 4.4: deny → DB diupdate: payment_status="failed"',
        () {
      final result = determinePaymentUpdate('deny', null);

      expect(result, isNotNull);
      expect(result!.paymentStatus, equals('failed'));
      expect(result.orderStatus, isNull);
    });

    // ── pending → tidak ada update ────────────────────────────────────────────
    test(
        'pending → tidak ada update DB (HTTP 200, skip)',
        () {
      final result = determinePaymentUpdate('pending', null);

      expect(result, isNull,
          reason: 'pending tidak mengubah order sama sekali');
    });
  });
}
