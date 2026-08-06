import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'order_provider.dart';

/// Halaman yang ditampilkan setelah customer selesai membayar via Midtrans.
/// Bisa diakses via redirect dari Midtrans Finish URL atau dari dalam aplikasi.
class PaymentSuccessScreen extends ConsumerWidget {
  final String? orderId;
  final String? transactionStatus;

  const PaymentSuccessScreen({
    super.key,
    this.orderId,
    this.transactionStatus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuccess = transactionStatus == 'settlement' ||
        transactionStatus == 'capture' ||
        transactionStatus == null; // default anggap sukses

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon status
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: isSuccess
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSuccess
                        ? Icons.check_circle_rounded
                        : Icons.hourglass_empty_rounded,
                    size: 60,
                    color: isSuccess ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(height: 24),

                // Judul
                Text(
                  isSuccess ? 'Pembayaran Berhasil!' : 'Pembayaran Diproses',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Deskripsi
                Text(
                  isSuccess
                      ? 'Terima kasih! Pesanan kamu sedang diproses dan akan segera dikirim.'
                      : 'Pembayaran kamu sedang dalam proses verifikasi.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                if (orderId != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ID Pesanan: ${orderId!.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                // Tombol lihat pesanan
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.invalidate(customerOrdersProvider);
                      // Kembali ke halaman utama
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B8E6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Lihat Pesanan Saya',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Tombol kembali belanja
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00B8E6),
                      side: const BorderSide(color: Color(0xFF00B8E6)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Kembali Belanja',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
