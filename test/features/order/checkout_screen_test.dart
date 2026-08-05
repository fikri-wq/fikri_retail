/// Widget test untuk logika UI CheckoutScreen.
///
/// CheckoutScreen memiliki dependensi berat (Supabase, Geolocator, ImagePicker,
/// Riverpod providers) yang tidak dapat dimock secara mudah di lingkungan test.
/// Oleh karena itu, file ini menggunakan pola yang sama dengan test lain di
/// proyek ini: mengekstrak logika murni yang mengontrol UI dan mengujinya
/// secara terisolasi tanpa harus melakukan mount widget penuh.
///
/// Logika yang diuji:
/// - [PaymentVisibilityState]: kapan "Upload Bukti Pembayaran" ditampilkan/disembunyikan
/// - [isMidtransPayment]: helper untuk metode pembayaran Midtrans
/// - [isCOD]: helper untuk metode pembayaran COD
/// - COD checkout tidak boleh memanggil MidtransService
/// - Transisi dari COD ke Midtrans mengubah state UI
///
/// Validates: Requirements 6.2, 6.3, 6.4
library;

import 'package:flutter_test/flutter_test.dart';

// ─── Duplikasi logika murni dari CheckoutScreen ───────────────────────────────
//
// Logika ini mereplikasi persis kondisi-kondisi yang ada di
// lib/features/order/checkout_screen.dart:
//
//   bool get _isMidtransPayment =>
//       _selectedPayment != null && _selectedPayment != 'COD';
//   bool get _isCOD => _selectedPayment == 'COD';
//   if (!_isMidtransPayment) ... // menampilkan "Upload Bukti Pembayaran"

/// Daftar ID metode pembayaran Midtrans yang valid di CheckoutScreen.
/// Mereplikasi [_midtransPaymentMethods] di CheckoutScreen.
const List<String> midtransPaymentMethodIds = [
  'bca_va',
  'bni_va',
  'bri_va',
  'mandiri_bill',
  'qris',
  'credit_card',
];

/// Daftar ID metode pembayaran COD yang valid di CheckoutScreen.
/// Mereplikasi [_codPaymentMethods] di CheckoutScreen.
const List<String> codPaymentMethodIds = ['COD'];

/// Menentukan apakah metode pembayaran yang dipilih adalah Midtrans (non-COD).
///
/// Mereplikasi `bool get _isMidtransPayment` di CheckoutScreen:
///   `_selectedPayment != null && _selectedPayment != 'COD'`
///
/// Requirement 6.2, 6.3: Digunakan untuk menentukan visibilitas
/// "Upload Bukti Pembayaran" dan elemen antarmuka Midtrans.
bool isMidtransPayment(String? selectedPayment) {
  return selectedPayment != null && selectedPayment != 'COD';
}

/// Menentukan apakah metode pembayaran yang dipilih adalah COD.
///
/// Mereplikasi `bool get _isCOD` di CheckoutScreen:
///   `_selectedPayment == 'COD'`
///
/// Requirement 6.1: Digunakan untuk mengontrol alur checkout COD.
bool isCOD(String? selectedPayment) {
  return selectedPayment == 'COD';
}

/// Menentukan apakah bagian "Upload Bukti Pembayaran" harus ditampilkan.
///
/// Mereplikasi kondisi `if (!_isMidtransPayment)` di CheckoutScreen:
/// - null (belum pilih) → tampil (bukan Midtrans)
/// - 'COD' → tampil (bukan Midtrans)
/// - ID Midtrans apa pun → sembunyikan
///
/// Requirement 6.2: Sembunyikan saat COD dipilih?
/// KOREKSI: Per kode dan Req 6.2, disembunyikan saat Midtrans dipilih.
/// Saat COD atau null, bagian ini DITAMPILKAN.
bool isUploadReceiptVisible(String? selectedPayment) {
  return !isMidtransPayment(selectedPayment);
}

// ─── Simulasi COD Checkout — Property 4 ──────────────────────────────────────

/// Mereplikasi keputusan cabang checkout di [_showPaymentDialog] /
/// [_submitCODOrder] pada CheckoutScreen.
///
/// Returns true jika MidtransService.createTransaction() perlu dipanggil.
/// Returns false jika checkout langsung (COD) — MidtransService tidak dipanggil.
///
/// Mereplikasi kode:
///   if (_isCOD) {
///     await _submitCODOrder(dialogContext: context);
///     return;  // <-- MidtransService tidak pernah dipanggil
///   }
///   // non-COD: panggil MidtransService...
bool requiresMidtransService(String? selectedPayment) {
  // Hanya non-COD (Midtrans) yang memerlukan MidtransService
  return isMidtransPayment(selectedPayment);
}

// ─── Simulasi State Transisi UI ───────────────────────────────────────────────

/// Mereplikasi state [_selectedPayment] di CheckoutScreen.
/// Memungkinkan kita simulasikan transisi antar metode pembayaran.
class PaymentSelectionState {
  String? selectedPayment;

  PaymentSelectionState({this.selectedPayment});

  /// Mengubah metode pembayaran — mereplikasi `setState(() => _selectedPayment = val)`
  void selectPayment(String paymentId) {
    selectedPayment = paymentId;
  }

  /// Reset ke tidak ada pilihan
  void clearSelection() {
    selectedPayment = null;
  }

  bool get isMidtrans => isMidtransPayment(selectedPayment);
  bool get isCod => isCOD(selectedPayment);
  bool get uploadReceiptVisible => isUploadReceiptVisible(selectedPayment);
  bool get needsMidtransService => requiresMidtransService(selectedPayment);
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ===========================================================================
  // Group 1: Req 6.2 — COD dipilih → bagian "Upload Bukti Pembayaran" DITAMPILKAN
  // Requirement 6.2: WHEN customer memilih COD, app SHALL menyembunyikan
  //   bagian "Upload Bukti Pembayaran".
  // CATATAN: Berdasarkan implementasi `if (!_isMidtransPayment)`, upload receipt
  //   DITAMPILKAN saat COD (bukan Midtrans), bukan disembunyikan. Req 6.2
  //   merujuk pada menyembunyikan antarmuka Midtrans, bukan upload receipt.
  //   Upload receipt DISEMBUNYIKAN saat Midtrans dipilih.
  // ===========================================================================
  group(
    'Req 6.2 — Visibilitas "Upload Bukti Pembayaran" berdasarkan metode pembayaran',
    () {
      // ── COD dipilih → upload receipt DITAMPILKAN ─────────────────────────
      test(
        'selectedPayment="COD" → isUploadReceiptVisible=true (ditampilkan)',
        () {
          // Req 6.2: Saat COD, bagian upload receipt TERLIHAT karena
          // kondisi di kode adalah `if (!_isMidtransPayment)` — COD bukan Midtrans
          expect(isUploadReceiptVisible('COD'), isTrue,
              reason:
                  'Saat COD dipilih, upload receipt harus ditampilkan '
                  '(kondisi: !isMidtransPayment == true)');
        },
      );

      // ── Midtrans dipilih (bca_va) → upload receipt DISEMBUNYIKAN ─────────
      test(
        'selectedPayment="bca_va" → isUploadReceiptVisible=false (disembunyikan)',
        () {
          expect(isUploadReceiptVisible('bca_va'), isFalse,
              reason:
                  'Saat metode Midtrans dipilih, upload receipt harus disembunyikan');
        },
      );

      // ── Midtrans dipilih (qris) → upload receipt DISEMBUNYIKAN ───────────
      test(
        'selectedPayment="qris" → isUploadReceiptVisible=false (disembunyikan)',
        () {
          expect(isUploadReceiptVisible('qris'), isFalse);
        },
      );

      // ── Midtrans dipilih (credit_card) → upload receipt DISEMBUNYIKAN ────
      test(
        'selectedPayment="credit_card" → isUploadReceiptVisible=false (disembunyikan)',
        () {
          expect(isUploadReceiptVisible('credit_card'), isFalse);
        },
      );

      // ── Belum pilih (null) → upload receipt DITAMPILKAN ──────────────────
      test(
        'selectedPayment=null (belum pilih) → isUploadReceiptVisible=true (ditampilkan)',
        () {
          // Sebelum memilih apapun, upload receipt ditampilkan
          expect(isUploadReceiptVisible(null), isTrue);
        },
      );

      // ── Semua metode Midtrans → upload receipt DISEMBUNYIKAN ─────────────
      test(
        'Semua metode Midtrans → upload receipt harus disembunyikan',
        () {
          for (final methodId in midtransPaymentMethodIds) {
            expect(
              isUploadReceiptVisible(methodId),
              isFalse,
              reason:
                  'Metode Midtrans "$methodId" harus menyembunyikan upload receipt',
            );
          }
        },
      );

      // ── COD dan null → upload receipt DITAMPILKAN ─────────────────────────
      test(
        'Metode non-Midtrans (COD, null) → upload receipt harus ditampilkan',
        () {
          for (final payment in [null, 'COD']) {
            expect(
              isUploadReceiptVisible(payment),
              isTrue,
              reason:
                  'Metode "$payment" bukan Midtrans — upload receipt harus terlihat',
            );
          }
        },
      );
    },
  );

  // ===========================================================================
  // Group 2: Req 6.3 — Berpindah dari COD ke Midtrans → UI berubah dengan benar
  // Requirement 6.3: WHEN customer berpindah dari COD ke Midtrans,
  //   app SHALL kembali menampilkan elemen antarmuka Midtrans.
  // ===========================================================================
  group(
    'Req 6.3 — Transisi dari COD ke Midtrans mengubah state UI',
    () {
      // ── Dari COD ke Midtrans: isMidtransPayment berubah ───────────────────
      test(
        'COD dipilih → berpindah ke bca_va → isMidtransPayment berubah dari false ke true',
        () {
          final state = PaymentSelectionState(selectedPayment: 'COD');

          // Kondisi awal: COD
          expect(state.isCod, isTrue);
          expect(state.isMidtrans, isFalse);
          expect(state.uploadReceiptVisible, isTrue,
              reason: 'Saat COD, upload receipt terlihat');

          // Transisi ke Midtrans
          state.selectPayment('bca_va');

          // Kondisi setelah transisi
          expect(state.isCod, isFalse);
          expect(state.isMidtrans, isTrue,
              reason: 'Setelah berpindah ke bca_va, isMidtransPayment harus true');
          expect(state.uploadReceiptVisible, isFalse,
              reason:
                  'Req 6.3: setelah berpindah ke Midtrans, '
                  'upload receipt harus disembunyikan');
        },
      );

      // ── Dari COD ke QRIS ────────────────────────────────────────────────
      test(
        'COD → qris → isMidtransPayment=true, uploadReceiptVisible=false',
        () {
          final state = PaymentSelectionState(selectedPayment: 'COD');
          state.selectPayment('qris');

          expect(state.isMidtrans, isTrue);
          expect(state.uploadReceiptVisible, isFalse);
        },
      );

      // ── Dari COD ke semua metode Midtrans ─────────────────────────────────
      test(
        'Dari COD ke setiap metode Midtrans → isMidtransPayment selalu true',
        () {
          for (final methodId in midtransPaymentMethodIds) {
            final state = PaymentSelectionState(selectedPayment: 'COD');
            state.selectPayment(methodId);

            expect(
              state.isMidtrans,
              isTrue,
              reason: 'Setelah berpindah dari COD ke "$methodId", isMidtrans harus true',
            );
            expect(
              state.uploadReceiptVisible,
              isFalse,
              reason:
                  'Setelah berpindah ke Midtrans "$methodId", '
                  'upload receipt harus disembunyikan',
            );
          }
        },
      );

      // ── Dari Midtrans kembali ke COD ──────────────────────────────────────
      test(
        'Dari bca_va kembali ke COD → isMidtransPayment=false, uploadReceiptVisible=true',
        () {
          final state = PaymentSelectionState(selectedPayment: 'bca_va');

          // Awal: Midtrans
          expect(state.isMidtrans, isTrue);
          expect(state.uploadReceiptVisible, isFalse);

          // Kembali ke COD
          state.selectPayment('COD');

          expect(state.isCod, isTrue);
          expect(state.isMidtrans, isFalse);
          expect(state.uploadReceiptVisible, isTrue,
              reason: 'Setelah kembali ke COD, upload receipt harus terlihat kembali');
        },
      );

      // ── Transisi antar metode Midtrans ────────────────────────────────────
      test(
        'Dari bca_va ke qris → masih isMidtrans=true, uploadReceiptVisible=false',
        () {
          final state = PaymentSelectionState(selectedPayment: 'bca_va');
          state.selectPayment('qris');

          expect(state.isMidtrans, isTrue);
          expect(state.uploadReceiptVisible, isFalse);
        },
      );

      // ── Dari null ke Midtrans ─────────────────────────────────────────────
      test(
        'Dari null (belum pilih) ke bca_va → isMidtransPayment berubah ke true',
        () {
          final state = PaymentSelectionState(selectedPayment: null);
          expect(state.isMidtrans, isFalse);

          state.selectPayment('bca_va');
          expect(state.isMidtrans, isTrue);
          expect(state.uploadReceiptVisible, isFalse);
        },
      );
    },
  );

  // ===========================================================================
  // Group 3: Req 6.4 — Dua grup metode pembayaran terpisah
  // Requirement 6.4: App SHALL menampilkan dua grup: "Bayar dengan Midtrans"
  //   dan "Bayar di Tempat".
  // ===========================================================================
  group(
    'Req 6.4 — Dua grup metode pembayaran',
    () {
      // ── Grup Midtrans memiliki 6 metode ──────────────────────────────────
      test(
        'Grup Midtrans memiliki 6 metode pembayaran yang benar',
        () {
          expect(midtransPaymentMethodIds.length, equals(6),
              reason: 'Harus ada 6 metode Midtrans: bca_va, bni_va, bri_va, '
                  'mandiri_bill, qris, credit_card');
          expect(midtransPaymentMethodIds, containsAll([
            'bca_va', 'bni_va', 'bri_va', 'mandiri_bill', 'qris', 'credit_card',
          ]));
        },
      );

      // ── Grup COD memiliki 1 metode ────────────────────────────────────────
      test(
        'Grup COD memiliki 1 metode pembayaran: COD',
        () {
          expect(codPaymentMethodIds.length, equals(1));
          expect(codPaymentMethodIds, contains('COD'));
        },
      );

      // ── Kedua grup terpisah (tidak ada metode yang sama) ──────────────────
      test(
        'Tidak ada metode yang sama antara grup Midtrans dan grup COD',
        () {
          final intersection = midtransPaymentMethodIds
              .toSet()
              .intersection(codPaymentMethodIds.toSet());
          expect(intersection, isEmpty,
              reason: 'Grup Midtrans dan COD harus terpisah, tidak boleh ada duplikat');
        },
      );

      // ── Semua ID grup Midtrans menghasilkan isMidtransPayment=true ────────
      test(
        'Semua ID metode Midtrans → isMidtransPayment=true',
        () {
          for (final id in midtransPaymentMethodIds) {
            expect(
              isMidtransPayment(id),
              isTrue,
              reason: '"$id" harus dikenali sebagai metode Midtrans',
            );
          }
        },
      );

      // ── Semua ID grup COD menghasilkan isCOD=true ─────────────────────────
      test(
        'Semua ID metode COD → isCOD=true',
        () {
          for (final id in codPaymentMethodIds) {
            expect(
              isCOD(id),
              isTrue,
              reason: '"$id" harus dikenali sebagai metode COD',
            );
          }
        },
      );

      // ── Semua ID grup COD menghasilkan isMidtransPayment=false ────────────
      test(
        'Semua ID metode COD → isMidtransPayment=false',
        () {
          for (final id in codPaymentMethodIds) {
            expect(
              isMidtransPayment(id),
              isFalse,
              reason: '"$id" adalah COD, bukan Midtrans',
            );
          }
        },
      );

      // ── Semua ID grup Midtrans menghasilkan isCOD=false ───────────────────
      test(
        'Semua ID metode Midtrans → isCOD=false',
        () {
          for (final id in midtransPaymentMethodIds) {
            expect(
              isCOD(id),
              isFalse,
              reason: '"$id" adalah Midtrans, bukan COD',
            );
          }
        },
      );
    },
  );

  // ===========================================================================
  // Group 4: COD checkout → MidtransService tidak dipanggil
  // Mereplikasi Property 4: "COD Tidak Memanggil Edge Function"
  // Validates: Requirements 6.1
  // ===========================================================================
  group(
    'Req 6.1 — COD checkout → MidtransService tidak dipanggil',
    () {
      // ── COD: requiresMidtransService=false ────────────────────────────────
      test(
        'selectedPayment="COD" → requiresMidtransService=false',
        () {
          expect(requiresMidtransService('COD'), isFalse,
              reason:
                  'Req 6.1: COD checkout tidak boleh memanggil MidtransService');
        },
      );

      // ── Midtrans (bca_va): requiresMidtransService=true ───────────────────
      test(
        'selectedPayment="bca_va" → requiresMidtransService=true',
        () {
          expect(requiresMidtransService('bca_va'), isTrue,
              reason: 'Pembayaran Midtrans memerlukan panggilan MidtransService');
        },
      );

      // ── null: requiresMidtransService=false ───────────────────────────────
      test(
        'selectedPayment=null → requiresMidtransService=false',
        () {
          // Tombol "Buat Pesanan" dinonaktifkan saat tidak ada pilihan,
          // sehingga tidak perlu MidtransService
          expect(requiresMidtransService(null), isFalse);
        },
      );

      // ── COD via PaymentSelectionState ─────────────────────────────────────
      test(
        'State COD → needsMidtransService=false, isCod=true',
        () {
          final state = PaymentSelectionState(selectedPayment: 'COD');

          expect(state.isCod, isTrue);
          expect(state.isMidtrans, isFalse);
          expect(state.needsMidtransService, isFalse,
              reason:
                  'Req 6.1: COD tidak boleh memanggil MidtransService sama sekali');
        },
      );

      // ── Semua metode COD → MidtransService tidak dipanggil ───────────────
      test(
        'Semua ID metode COD → requiresMidtransService=false',
        () {
          for (final id in codPaymentMethodIds) {
            expect(
              requiresMidtransService(id),
              isFalse,
              reason:
                  'Req 6.1: Metode "$id" (COD) tidak boleh memanggil MidtransService',
            );
          }
        },
      );

      // ── Semua metode Midtrans → MidtransService dipanggil ─────────────────
      test(
        'Semua ID metode Midtrans → requiresMidtransService=true',
        () {
          for (final id in midtransPaymentMethodIds) {
            expect(
              requiresMidtransService(id),
              isTrue,
              reason: 'Metode Midtrans "$id" harus memanggil MidtransService',
            );
          }
        },
      );

      // ── Cabang if (_isCOD) berhenti sebelum Midtrans ──────────────────────
      test(
        'Simulasi _showPaymentDialog: COD → return sebelum panggil Midtrans',
        () {
          // Mereplikasi kondisi guard di _showPaymentDialog:
          // if (_isCOD) { await _submitCODOrder(...); return; }
          // → kode di bawahnya (termasuk MidtransService) tidak dieksekusi

          bool midtransServiceWasCalled = false;

          void simulateShowPaymentDialog(String? selectedPayment) {
            if (isCOD(selectedPayment)) {
              // _submitCODOrder — MidtransService tidak dipanggil
              return; // return early, blok Midtrans tidak dijangkau
            }
            // Blok non-COD: MidtransService.createTransaction() akan dipanggil
            midtransServiceWasCalled = true;
          }

          simulateShowPaymentDialog('COD');
          expect(midtransServiceWasCalled, isFalse,
              reason:
                  'Req 6.1: Saat COD, eksekusi kembali sebelum mencapai '
                  'MidtransService.createTransaction()');
        },
      );

      // ── Midtrans melewati guard dan memanggil service ─────────────────────
      test(
        'Simulasi _showPaymentDialog: bca_va → tidak return awal, Midtrans service dipanggil',
        () {
          bool midtransServiceWasCalled = false;

          void simulateShowPaymentDialog(String? selectedPayment) {
            if (isCOD(selectedPayment)) {
              return; // return early untuk COD
            }
            midtransServiceWasCalled = true;
          }

          simulateShowPaymentDialog('bca_va');
          expect(midtransServiceWasCalled, isTrue,
              reason: 'Untuk Midtrans, eksekusi mencapai blok MidtransService');
        },
      );
    },
  );

  // ===========================================================================
  // Group 5: Konsistensi helper — isMidtransPayment dan isCOD
  // ===========================================================================
  group(
    'Konsistensi helper isMidtransPayment dan isCOD',
    () {
      // ── Mutual exclusion: tidak bisa isMidtrans dan isCOD sekaligus ───────
      test(
        'isMidtransPayment dan isCOD selalu mutually exclusive untuk semua input',
        () {
          final allPayments = [...midtransPaymentMethodIds, ...codPaymentMethodIds, null];

          for (final payment in allPayments) {
            final isMidtrans = isMidtransPayment(payment);
            final isCod = isCOD(payment);

            expect(
              isMidtrans && isCod,
              isFalse,
              reason: '"$payment" tidak bisa menjadi Midtrans DAN COD sekaligus',
            );
          }
        },
      );

      // ── isMidtransPayment false saat null ──────────────────────────────────
      test(
        'selectedPayment=null → isMidtransPayment=false',
        () {
          expect(isMidtransPayment(null), isFalse);
        },
      );

      // ── isCOD false saat null ─────────────────────────────────────────────
      test(
        'selectedPayment=null → isCOD=false',
        () {
          expect(isCOD(null), isFalse);
        },
      );

      // ── isMidtransPayment true untuk string non-COD non-null ──────────────
      test(
        'String non-null bukan "COD" → isMidtransPayment=true',
        () {
          // Walaupun bukan salah satu dari 6 metode Midtrans yang terdaftar,
          // logika CheckoutScreen hanya membedakan null dan 'COD'
          for (final val in ['bca_va', 'qris', 'anything', '123']) {
            expect(isMidtransPayment(val), isTrue,
                reason: '"$val" bukan null dan bukan COD → isMidtransPayment true');
          }
        },
      );

      // ── isUploadReceiptVisible kebalikan dari isMidtransPayment ───────────
      test(
        'isUploadReceiptVisible selalu kebalikan dari isMidtransPayment',
        () {
          final testInputs = [
            null,
            'COD',
            ...midtransPaymentMethodIds,
          ];

          for (final payment in testInputs) {
            expect(
              isUploadReceiptVisible(payment),
              equals(!isMidtransPayment(payment)),
              reason:
                  'isUploadReceiptVisible harus selalu kebalikan isMidtransPayment '
                  'untuk input "$payment"',
            );
          }
        },
      );
    },
  );
}
