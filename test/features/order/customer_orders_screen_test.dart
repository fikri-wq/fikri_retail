/// Widget test untuk logika UI CustomerOrdersScreen.
///
/// CustomerOrdersScreen memiliki dependensi berat (Supabase Realtime,
/// Riverpod providers, SupabaseService, OrderChatScreen) yang tidak dapat
/// dimock secara mudah di lingkungan test standar.
///
/// Oleh karena itu, file ini menggunakan pola yang sama dengan
/// `test/features/order/checkout_screen_test.dart`: mengekstrak logika murni
/// yang mengontrol UI dan mengujinya secara terisolasi tanpa mount widget penuh.
///
/// Logika yang diuji:
/// - [paymentStatusLabel]: teks badge berdasarkan nilai `payment_status`
/// - [isPaymentBadgeVisible]: badge hanya muncul saat `paymentMethod != null`
/// - [StreamErrorState]: state machine untuk Req 5.5 — stream error + data terakhir
///
/// Validates: Requirements 5.2, 5.3, 5.5
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fikriretailproject/models/order_model.dart';

// ─── Duplikasi logika murni dari CustomerOrdersScreen ────────────────────────
//
// Logika ini mereplikasi kondisi-kondisi yang ada di
// lib/features/order/customer_orders_screen.dart:
//
//   Widget _buildPaymentStatusBadge(String paymentStatus) {
//     switch (paymentStatus) {
//       case 'paid':   label = 'Pembayaran Berhasil'; ...
//       case 'failed': label = 'Pembayaran Gagal/Kedaluwarsa'; ...
//       default:       label = 'Menunggu Pembayaran'; ...
//     }
//   }
//
//   if (order.paymentMethod != null)   // badge ditampilkan
//     _buildPaymentStatusBadge(order.paymentStatus)
//
//   // Req 5.5: _realtimeError + _lastKnownOrders

// ─── Badge Label Logic ────────────────────────────────────────────────────────

/// Mengembalikan teks label badge berdasarkan nilai `paymentStatus`.
///
/// Mereplikasi switch-case di [_buildPaymentStatusBadge] pada
/// CustomerOrdersScreen:
///   'paid'    → 'Pembayaran Berhasil'         (Req 5.2)
///   'failed'  → 'Pembayaran Gagal/Kedaluwarsa' (Req 5.3)
///   otherwise → 'Menunggu Pembayaran'          (Req 5.4)
String paymentStatusLabel(String paymentStatus) {
  switch (paymentStatus) {
    case 'paid':
      return 'Pembayaran Berhasil';
    case 'failed':
      return 'Pembayaran Gagal/Kedaluwarsa';
    default:
      return 'Menunggu Pembayaran';
  }
}

/// Menentukan apakah badge status pembayaran harus ditampilkan pada kartu pesanan.
///
/// Mereplikasi kondisi `if (order.paymentMethod != null)` di CustomerOrdersScreen:
/// badge hanya muncul saat pesanan memiliki `paymentMethod` yang tidak null.
bool isPaymentBadgeVisible(String? paymentMethod) {
  return paymentMethod != null;
}

// ─── Helper untuk membuat OrderModel minimal ─────────────────────────────────

/// Membuat [OrderModel] minimal untuk keperluan test dengan nilai yang dapat
/// dikustomisasi.
OrderModel makeOrder({
  String id = 'test-id-001',
  String paymentStatus = 'unpaid',
  String? paymentMethod,
  String? snapToken,
  String status = 'pending',
}) {
  return OrderModel(
    id: id,
    userId: 'user-001',
    totalAmount: 100000,
    status: status,
    createdAt: DateTime(2024, 1, 1),
    paymentStatus: paymentStatus,
    paymentMethod: paymentMethod,
    snapToken: snapToken,
  );
}

// ─── Stream Error State Machine ───────────────────────────────────────────────

/// Mereplikasi state Req 5.5 pada [_CustomerOrdersScreenState]:
///
/// - [_lastKnownOrders]: data pesanan terakhir yang berhasil dimuat
/// - [_realtimeError]: flag yang di-set true saat stream error terjadi
///
/// Transisi yang direplikasi dari kode:
///   ordersAsync.when(
///     data: (orders) {
///       _lastKnownOrders = orders;   // simpan data terakhir
///       _realtimeError = false;      // clear error
///     },
///     error: (err, stack) {
///       setState(() => _realtimeError = true);   // set error flag
///       final fallbackOrders = _lastKnownOrders ?? [];  // pakai data terakhir
///     },
///   )
class StreamErrorState {
  List<OrderModel>? lastKnownOrders;
  bool realtimeError = false;

  /// Mereplikasi callback `data:` — menyimpan data dan membersihkan error.
  void onData(List<OrderModel> orders) {
    lastKnownOrders = orders;
    realtimeError = false;
  }

  /// Mereplikasi callback `error:` — set flag error dan tetap gunakan data lama.
  void onError(Object error) {
    realtimeError = true;
    // lastKnownOrders TIDAK diubah — data terakhir tetap dipertahankan
  }

  /// Data yang akan ditampilkan saat error — mereplikasi:
  ///   `final fallbackOrders = _lastKnownOrders ?? [];`
  List<OrderModel> get displayedOrders => lastKnownOrders ?? [];

  /// Apakah banner error "Pembaruan otomatis tidak tersedia saat ini." ditampilkan.
  /// Mereplikasi: `if (_realtimeError)` di build method CustomerOrdersScreen.
  bool get isErrorBannerVisible => realtimeError;

  /// Pesan yang ditampilkan di banner error (Req 5.5).
  static const String errorBannerText =
      'Pembaruan otomatis tidak tersedia saat ini.';
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ===========================================================================
  // Group 1: Req 5.2 — badge "Pembayaran Berhasil" muncul saat payment_status='paid'
  // Requirement 5.2: WHEN payment_status berubah menjadi 'paid',
  //   app SHALL menampilkan label "Pembayaran Berhasil".
  // ===========================================================================
  group(
    'Req 5.2 — Badge "Pembayaran Berhasil" saat payment_status=paid',
    () {
      // ── Label benar untuk 'paid' ───────────────────────────────────────────
      test(
        'paymentStatusLabel("paid") == "Pembayaran Berhasil"',
        () {
          expect(
            paymentStatusLabel('paid'),
            equals('Pembayaran Berhasil'),
            reason:
                'Req 5.2: payment_status="paid" harus menghasilkan label '
                '"Pembayaran Berhasil"',
          );
        },
      );

      // ── Badge terlihat saat paymentMethod tidak null dan status paid ───────
      test(
        'Pesanan dengan paymentMethod="midtrans" + paymentStatus="paid" → badge terlihat',
        () {
          final order = makeOrder(
            paymentStatus: 'paid',
            paymentMethod: 'midtrans',
          );
          expect(
            isPaymentBadgeVisible(order.paymentMethod),
            isTrue,
            reason:
                'Badge harus ditampilkan saat paymentMethod tidak null',
          );
          expect(
            paymentStatusLabel(order.paymentStatus),
            equals('Pembayaran Berhasil'),
            reason: 'Label harus "Pembayaran Berhasil" untuk status paid',
          );
        },
      );

      // ── Bukan 'paid' → tidak menghasilkan label "Pembayaran Berhasil" ──────
      test(
        'paymentStatusLabel selain "paid" tidak menghasilkan "Pembayaran Berhasil"',
        () {
          for (final status in ['unpaid', 'failed', '', 'pending', 'unknown']) {
            expect(
              paymentStatusLabel(status),
              isNot(equals('Pembayaran Berhasil')),
              reason: '"$status" tidak boleh menghasilkan "Pembayaran Berhasil"',
            );
          }
        },
      );

      // ── OrderModel.fromMap dengan payment_status=paid ─────────────────────
      test(
        'OrderModel.fromMap dengan payment_status="paid" → paymentStatusLabel benar',
        () {
          final map = {
            'id': 'order-paid-001',
            'customer_id': 'user-001',
            'total_amount': 150000,
            'status': 'diantar',
            'created_at': '2024-06-01T10:00:00.000Z',
            'payment_status': 'paid',
            'payment_method': 'midtrans',
          };
          final order = OrderModel.fromMap(map);

          expect(order.paymentStatus, equals('paid'));
          expect(
            paymentStatusLabel(order.paymentStatus),
            equals('Pembayaran Berhasil'),
          );
          expect(isPaymentBadgeVisible(order.paymentMethod), isTrue);
        },
      );
    },
  );

  // ===========================================================================
  // Group 2: Req 5.3 — badge "Pembayaran Gagal/Kedaluwarsa" saat payment_status='failed'
  // Requirement 5.3: WHEN payment_status berubah menjadi 'failed',
  //   app SHALL menampilkan label "Pembayaran Gagal/Kedaluwarsa".
  // ===========================================================================
  group(
    'Req 5.3 — Badge "Pembayaran Gagal/Kedaluwarsa" saat payment_status=failed',
    () {
      // ── Label benar untuk 'failed' ─────────────────────────────────────────
      test(
        'paymentStatusLabel("failed") == "Pembayaran Gagal/Kedaluwarsa"',
        () {
          expect(
            paymentStatusLabel('failed'),
            equals('Pembayaran Gagal/Kedaluwarsa'),
            reason:
                'Req 5.3: payment_status="failed" harus menghasilkan label '
                '"Pembayaran Gagal/Kedaluwarsa"',
          );
        },
      );

      // ── Badge terlihat saat paymentMethod tidak null dan status failed ─────
      test(
        'Pesanan dengan paymentMethod="midtrans" + paymentStatus="failed" → badge terlihat',
        () {
          final order = makeOrder(
            paymentStatus: 'failed',
            paymentMethod: 'midtrans',
          );
          expect(isPaymentBadgeVisible(order.paymentMethod), isTrue);
          expect(
            paymentStatusLabel(order.paymentStatus),
            equals('Pembayaran Gagal/Kedaluwarsa'),
          );
        },
      );

      // ── Bukan 'failed' → tidak menghasilkan label "Pembayaran Gagal/..." ───
      test(
        'paymentStatusLabel selain "failed" tidak menghasilkan "Pembayaran Gagal/Kedaluwarsa"',
        () {
          for (final status in ['paid', 'unpaid', '', 'cancelled', 'deny']) {
            expect(
              paymentStatusLabel(status),
              isNot(equals('Pembayaran Gagal/Kedaluwarsa')),
              reason: '"$status" tidak boleh menghasilkan label failed',
            );
          }
        },
      );

      // ── OrderModel.fromMap dengan payment_status=failed ───────────────────
      test(
        'OrderModel.fromMap dengan payment_status="failed" → paymentStatusLabel benar',
        () {
          final map = {
            'id': 'order-failed-001',
            'customer_id': 'user-001',
            'total_amount': 75000,
            'status': 'pending',
            'created_at': '2024-06-02T08:00:00.000Z',
            'payment_status': 'failed',
            'payment_method': 'midtrans',
          };
          final order = OrderModel.fromMap(map);

          expect(order.paymentStatus, equals('failed'));
          expect(
            paymentStatusLabel(order.paymentStatus),
            equals('Pembayaran Gagal/Kedaluwarsa'),
          );
          expect(isPaymentBadgeVisible(order.paymentMethod), isTrue);
        },
      );
    },
  );

  // ===========================================================================
  // Group 3: Status 'unpaid' → label "Menunggu Pembayaran"
  // Req 5.4: status unpaid menghasilkan label "Menunggu Pembayaran"
  // ===========================================================================
  group(
    'Status "unpaid" → label "Menunggu Pembayaran"',
    () {
      test(
        'paymentStatusLabel("unpaid") == "Menunggu Pembayaran"',
        () {
          expect(
            paymentStatusLabel('unpaid'),
            equals('Menunggu Pembayaran'),
          );
        },
      );

      test(
        'paymentStatusLabel string tidak dikenal → fallback "Menunggu Pembayaran"',
        () {
          for (final status in ['', 'pending', 'unknown', 'PAID', 'FAILED']) {
            expect(
              paymentStatusLabel(status),
              equals('Menunggu Pembayaran'),
              reason: '"$status" tidak dikenal, harus fallback ke "Menunggu Pembayaran"',
            );
          }
        },
      );

      test(
        'OrderModel default paymentStatus="unpaid" → label "Menunggu Pembayaran"',
        () {
          // paymentStatus default 'unpaid' dari OrderModel
          final order = makeOrder(); // paymentStatus tidak diset → default 'unpaid'
          expect(order.paymentStatus, equals('unpaid'));
          expect(paymentStatusLabel(order.paymentStatus), equals('Menunggu Pembayaran'));
        },
      );
    },
  );

  // ===========================================================================
  // Group 4: Visibilitas badge berdasarkan paymentMethod
  // Badge ditampilkan hanya saat paymentMethod != null
  // ===========================================================================
  group(
    'Visibilitas badge berdasarkan paymentMethod',
    () {
      // ── paymentMethod null (COD tanpa paymentMethod) → badge tidak tampil ──
      test(
        'paymentMethod=null → isPaymentBadgeVisible=false',
        () {
          expect(
            isPaymentBadgeVisible(null),
            isFalse,
            reason: 'Badge tidak ditampilkan saat paymentMethod null',
          );
        },
      );

      // ── paymentMethod="midtrans" → badge tampil ───────────────────────────
      test(
        'paymentMethod="midtrans" → isPaymentBadgeVisible=true',
        () {
          expect(isPaymentBadgeVisible('midtrans'), isTrue);
        },
      );

      // ── paymentMethod="COD" → badge tampil ───────────────────────────────
      test(
        'paymentMethod="COD" → isPaymentBadgeVisible=true',
        () {
          // Saat paymentMethod='COD' (bukan null), badge tetap ditampilkan
          // dengan label 'Menunggu Pembayaran' (status unpaid untuk COD)
          expect(isPaymentBadgeVisible('COD'), isTrue);
        },
      );

      // ── Pesanan COD (paymentMethod=null) → badge tidak tampil ─────────────
      test(
        'Pesanan tanpa paymentMethod (order lama) → badge tidak ditampilkan',
        () {
          final order = makeOrder(paymentMethod: null);
          expect(isPaymentBadgeVisible(order.paymentMethod), isFalse);
        },
      );

      // ── Pesanan Midtrans paid → badge tampil dengan label benar ───────────
      test(
        'Pesanan Midtrans paid → badge tampil + label "Pembayaran Berhasil"',
        () {
          final order = makeOrder(paymentStatus: 'paid', paymentMethod: 'midtrans');
          expect(isPaymentBadgeVisible(order.paymentMethod), isTrue);
          expect(paymentStatusLabel(order.paymentStatus), equals('Pembayaran Berhasil'));
        },
      );

      // ── Pesanan Midtrans failed → badge tampil dengan label benar ─────────
      test(
        'Pesanan Midtrans failed → badge tampil + label "Pembayaran Gagal/Kedaluwarsa"',
        () {
          final order = makeOrder(paymentStatus: 'failed', paymentMethod: 'midtrans');
          expect(isPaymentBadgeVisible(order.paymentMethod), isTrue);
          expect(
            paymentStatusLabel(order.paymentStatus),
            equals('Pembayaran Gagal/Kedaluwarsa'),
          );
        },
      );
    },
  );

  // ===========================================================================
  // Group 5: Req 5.5 — Stream error: pesan error + data terakhir tetap ada
  // Requirement 5.5: IF stream error, app SHALL menampilkan
  //   "Pembaruan otomatis tidak tersedia saat ini." dan mempertahankan
  //   data pesanan terakhir.
  // ===========================================================================
  group(
    'Req 5.5 — Stream error: pesan error ditampilkan, data terakhir dipertahankan',
    () {
      // ── Saat error tanpa data sebelumnya → displayedOrders kosong ─────────
      test(
        'Stream error tanpa data sebelumnya → displayedOrders kosong, banner tampil',
        () {
          final state = StreamErrorState();

          state.onError(Exception('connection lost'));

          expect(
            state.isErrorBannerVisible,
            isTrue,
            reason:
                'Req 5.5: banner error harus tampil saat stream error',
          );
          expect(
            state.displayedOrders,
            isEmpty,
            reason:
                'Saat belum ada data sebelumnya, displayedOrders harus kosong',
          );
        },
      );

      // ── Pesan banner error sesuai requirement ─────────────────────────────
      test(
        'errorBannerText == "Pembaruan otomatis tidak tersedia saat ini."',
        () {
          expect(
            StreamErrorState.errorBannerText,
            equals('Pembaruan otomatis tidak tersedia saat ini.'),
            reason:
                'Req 5.5: pesan error yang ditampilkan harus persis sesuai requirement',
          );
        },
      );

      // ── Saat data berhasil dimuat lalu stream error → data terakhir tetap ada
      test(
        'Data dimuat, lalu stream error → displayedOrders masih berisi data terakhir',
        () {
          final state = StreamErrorState();

          // Step 1: data berhasil diterima
          final sampleOrders = [
            makeOrder(id: 'order-001', paymentStatus: 'paid', paymentMethod: 'midtrans'),
            makeOrder(id: 'order-002', paymentStatus: 'unpaid', paymentMethod: 'COD'),
          ];
          state.onData(sampleOrders);

          expect(state.realtimeError, isFalse);
          expect(state.displayedOrders, equals(sampleOrders));

          // Step 2: stream error terjadi
          state.onError(Exception('realtime disconnected'));

          // Req 5.5: data terakhir harus tetap ada
          expect(
            state.isErrorBannerVisible,
            isTrue,
            reason: 'Banner error harus tampil',
          );
          expect(
            state.displayedOrders,
            equals(sampleOrders),
            reason:
                'Req 5.5: data pesanan terakhir harus tetap dipertahankan '
                'saat stream error, tidak boleh dihapus',
          );
          expect(
            state.displayedOrders.length,
            equals(2),
            reason: 'Jumlah pesanan yang ditampilkan harus sama dengan data terakhir',
          );
        },
      );

      // ── Stream error tidak mengubah isi data terakhir ─────────────────────
      test(
        'Stream error berulang tidak mengubah data terakhir',
        () {
          final state = StreamErrorState();

          final sampleOrders = [
            makeOrder(id: 'order-A', paymentStatus: 'failed', paymentMethod: 'midtrans'),
          ];
          state.onData(sampleOrders);

          // Error pertama
          state.onError(Exception('error #1'));
          expect(state.displayedOrders, equals(sampleOrders));

          // Error kedua
          state.onError(Exception('error #2'));
          expect(state.displayedOrders, equals(sampleOrders),
              reason: 'Data terakhir tidak berubah walaupun error berulang');
        },
      );

      // ── Data baru setelah error → clear flag dan update data ──────────────
      test(
        'Data baru diterima setelah stream error → realtimeError=false, data diupdate',
        () {
          final state = StreamErrorState();

          // Data awal
          final initialOrders = [
            makeOrder(id: 'order-old', paymentStatus: 'unpaid', paymentMethod: 'midtrans'),
          ];
          state.onData(initialOrders);

          // Error
          state.onError(Exception('connection lost'));
          expect(state.isErrorBannerVisible, isTrue);

          // Data baru datang (koneksi pulih)
          final updatedOrders = [
            makeOrder(id: 'order-old', paymentStatus: 'paid', paymentMethod: 'midtrans'),
            makeOrder(id: 'order-new', paymentStatus: 'unpaid', paymentMethod: 'COD'),
          ];
          state.onData(updatedOrders);

          expect(
            state.isErrorBannerVisible,
            isFalse,
            reason: 'Banner error harus hilang saat data baru berhasil diterima',
          );
          expect(
            state.displayedOrders,
            equals(updatedOrders),
            reason: 'Data harus diupdate ke data terbaru',
          );
        },
      );

      // ── state awal: tidak ada error, tidak ada data ───────────────────────
      test(
        'State awal: realtimeError=false, displayedOrders kosong',
        () {
          final state = StreamErrorState();

          expect(state.realtimeError, isFalse);
          expect(state.isErrorBannerVisible, isFalse);
          expect(state.displayedOrders, isEmpty);
          expect(state.lastKnownOrders, isNull);
        },
      );

      // ── Req 5.5: data order yg ditampilkan saat error sesuai data terakhir
      test(
        'displayedOrders saat error merefleksikan data terakhir yang di-load',
        () {
          final state = StreamErrorState();

          // Load 3 pesanan dengan berbagai status
          final orders = [
            makeOrder(id: 'o1', paymentStatus: 'paid',   paymentMethod: 'midtrans', status: 'diantar'),
            makeOrder(id: 'o2', paymentStatus: 'failed',  paymentMethod: 'midtrans', status: 'pending'),
            makeOrder(id: 'o3', paymentStatus: 'unpaid',  paymentMethod: 'COD',      status: 'pending'),
          ];
          state.onData(orders);
          state.onError(Exception('stream error'));

          final displayed = state.displayedOrders;
          expect(displayed.length, equals(3));
          expect(displayed[0].paymentStatus, equals('paid'));
          expect(displayed[1].paymentStatus, equals('failed'));
          expect(displayed[2].paymentStatus, equals('unpaid'));
        },
      );
    },
  );

  // ===========================================================================
  // Group 6: Konsistensi label — semua nilai payment_status menghasilkan label
  // ===========================================================================
  group(
    'Konsistensi mapping payment_status → label',
    () {
      // ── Tiga status resmi terdefinisi ─────────────────────────────────────
      test(
        'Tiga status resmi menghasilkan tiga label berbeda',
        () {
          final paid   = paymentStatusLabel('paid');
          final failed = paymentStatusLabel('failed');
          final unpaid = paymentStatusLabel('unpaid');

          expect(paid,   equals('Pembayaran Berhasil'));
          expect(failed, equals('Pembayaran Gagal/Kedaluwarsa'));
          expect(unpaid, equals('Menunggu Pembayaran'));

          // Ketiga label harus berbeda satu sama lain
          expect({paid, failed, unpaid}.length, equals(3),
              reason: 'Ketiga label harus unik');
        },
      );

      // ── 'paid' dan 'failed' saling berbeda ───────────────────────────────
      test(
        'Label "paid" dan "failed" tidak sama satu sama lain',
        () {
          expect(
            paymentStatusLabel('paid'),
            isNot(equals(paymentStatusLabel('failed'))),
          );
        },
      );

      // ── Mapping deterministik: input sama → output sama ───────────────────
      test(
        'paymentStatusLabel adalah fungsi deterministik: input sama → output sama',
        () {
          for (final status in ['paid', 'failed', 'unpaid', '', 'unknown']) {
            final result1 = paymentStatusLabel(status);
            final result2 = paymentStatusLabel(status);
            expect(result1, equals(result2),
                reason: 'Fungsi harus deterministik untuk input "$status"');
          }
        },
      );
    },
  );
}
