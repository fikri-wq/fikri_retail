import 'package:flutter_test/flutter_test.dart';
import 'package:fikriretailproject/models/order_model.dart';

/// Helper: base map dengan semua field wajib yang valid.
Map<String, dynamic> baseMap({
  String id = 'order-001',
  String customerId = 'user-abc',
  double totalAmount = 50000,
  String status = 'pending',
  String createdAt = '2024-01-01T00:00:00.000Z',
}) {
  return {
    'id': id,
    'customer_id': customerId,
    'total_amount': totalAmount,
    'status': status,
    'created_at': createdAt,
  };
}

void main() {
  // -------------------------------------------------------------------------
  // Property 6: OrderModel Parsing Simetri
  // Validates: Requirements 7.1, 7.2, 7.3, 7.4
  // -------------------------------------------------------------------------
  group('Property 6 — OrderModel.fromMap() parsing simetri', () {
    // Daftar nilai snap_token yang bervariasi
    final snapTokenValues = [
      null,
      '',
      'tok-abc123',
      'tok-xyz-999',
      'a' * 64, // token panjang
      'UPPERCASE-TOKEN',
      'tok with spaces',
      'tok/slash/token',
    ];

    // Daftar nilai payment_status
    final paymentStatusValues = [
      null,
      'unpaid',
      'paid',
      'failed',
    ];

    // Daftar nilai payment_method
    final paymentMethodValues = [
      null,
      'midtrans',
      'COD',
    ];

    // Daftar nilai midtrans_transaction_id
    final txIdValues = [
      null,
      'txn-001',
      'txn-abc-xyz-999',
      '0' * 32,
    ];

    // Bangun ~100+ kombinasi dan verifikasi invariant parsing
    int testCount = 0;
    for (final snapToken in snapTokenValues) {
      for (final paymentStatus in paymentStatusValues) {
        for (final paymentMethod in paymentMethodValues) {
          for (final txId in txIdValues) {
            testCount++;
            final index = testCount;

            test('kombinasi #$index: snapToken=$snapToken, paymentStatus=$paymentStatus, '
                'paymentMethod=$paymentMethod, txId=$txId', () {
              final map = baseMap()
                ..['snap_token'] = snapToken
                ..['payment_status'] = paymentStatus
                ..['payment_method'] = paymentMethod
                ..['midtrans_transaction_id'] = txId;

              final model = OrderModel.fromMap(map);

              // P6-a: snapToken dipertahankan
              expect(model.snapToken, equals(map['snap_token']),
                  reason: 'snapToken harus sama dengan map["snap_token"]');

              // P6-b: paymentStatus menggunakan fallback 'unpaid' jika null
              expect(model.paymentStatus, equals(map['payment_status'] ?? 'unpaid'),
                  reason: 'paymentStatus harus sama dengan map["payment_status"] ?? "unpaid"');

              // P6-c: paymentMethod dipertahankan
              expect(model.paymentMethod, equals(map['payment_method']),
                  reason: 'paymentMethod harus sama dengan map["payment_method"]');

              // P6-d: midtransTransactionId dipertahankan
              expect(model.midtransTransactionId, equals(map['midtrans_transaction_id']),
                  reason: 'midtransTransactionId harus sama dengan map["midtrans_transaction_id"]');
            });
          }
        }
      }
    }
  });

  // -------------------------------------------------------------------------
  // Task 1.4 — Unit test kasus edge untuk OrderModel.fromMap()
  // Validates: Requirements 7.1, 7.3
  // -------------------------------------------------------------------------
  group('edge cases — OrderModel.fromMap()', () {
    // 1. payment_status null di dalam map → default 'unpaid'
    test('payment_status null di map → paymentStatus default ke "unpaid"', () {
      final map = baseMap()..['payment_status'] = null;
      final model = OrderModel.fromMap(map);
      expect(model.paymentStatus, equals('unpaid'));
    });

    // 2. payment_status key tidak ada sama sekali → default 'unpaid'
    test('payment_status key tidak ada di map → paymentStatus default ke "unpaid"', () {
      final map = baseMap(); // tidak ada key 'payment_status'
      expect(map.containsKey('payment_status'), isFalse,
          reason: 'setup: key tidak boleh ada');
      final model = OrderModel.fromMap(map);
      expect(model.paymentStatus, equals('unpaid'));
    });

    // 3. snap_token null → snapToken is null (order COD)
    test('snap_token null (order COD) → model.snapToken adalah null', () {
      final map = baseMap()
        ..['snap_token'] = null
        ..['payment_method'] = 'COD';
      final model = OrderModel.fromMap(map);
      expect(model.snapToken, isNull);
    });

    // 4. Semua field Midtrans hadir → ter-parse dengan benar
    test('semua field Midtrans hadir → semua ter-parse dengan benar', () {
      final map = baseMap()
        ..['snap_token'] = 'snap-abc-12345'
        ..['payment_method'] = 'midtrans'
        ..['payment_status'] = 'unpaid'
        ..['midtrans_transaction_id'] = 'txn-xyz-67890';
      final model = OrderModel.fromMap(map);

      expect(model.snapToken, equals('snap-abc-12345'));
      expect(model.paymentMethod, equals('midtrans'));
      expect(model.paymentStatus, equals('unpaid'));
      expect(model.midtransTransactionId, equals('txn-xyz-67890'));
    });

    // 5. payment_status 'paid' → ter-parse sebagai 'paid'
    test('payment_status "paid" → diparse sebagai "paid"', () {
      final map = baseMap()..['payment_status'] = 'paid';
      final model = OrderModel.fromMap(map);
      expect(model.paymentStatus, equals('paid'));
    });

    // 6. payment_status 'failed' → ter-parse sebagai 'failed'
    test('payment_status "failed" → diparse sebagai "failed"', () {
      final map = baseMap()..['payment_status'] = 'failed';
      final model = OrderModel.fromMap(map);
      expect(model.paymentStatus, equals('failed'));
    });

    // 7. midtrans_transaction_id non-null → ter-parse dengan benar
    test('midtrans_transaction_id non-null → diparse dengan benar', () {
      final map = baseMap()
        ..['midtrans_transaction_id'] = 'txn-settlement-001';
      final model = OrderModel.fromMap(map);
      expect(model.midtransTransactionId, equals('txn-settlement-001'));
    });

    // --- Kasus tambahan untuk kelengkapan ---

    // snap_token key tidak ada → snapToken is null
    test('snap_token key tidak ada di map → model.snapToken adalah null', () {
      final map = baseMap();
      final model = OrderModel.fromMap(map);
      expect(model.snapToken, isNull);
    });

    // midtrans_transaction_id null → midtransTransactionId is null
    test('midtrans_transaction_id null → model.midtransTransactionId adalah null', () {
      final map = baseMap()..['midtrans_transaction_id'] = null;
      final model = OrderModel.fromMap(map);
      expect(model.midtransTransactionId, isNull);
    });

    // payment_method null → paymentMethod is null
    test('payment_method null → model.paymentMethod adalah null', () {
      final map = baseMap()..['payment_method'] = null;
      final model = OrderModel.fromMap(map);
      expect(model.paymentMethod, isNull);
    });

    // payment_method 'COD' → ter-parse dengan benar
    test('payment_method "COD" → diparse sebagai "COD"', () {
      final map = baseMap()..['payment_method'] = 'COD';
      final model = OrderModel.fromMap(map);
      expect(model.paymentMethod, equals('COD'));
    });

    // payment_method 'midtrans' → ter-parse dengan benar
    test('payment_method "midtrans" → diparse sebagai "midtrans"', () {
      final map = baseMap()..['payment_method'] = 'midtrans';
      final model = OrderModel.fromMap(map);
      expect(model.paymentMethod, equals('midtrans'));
    });
  });
}
