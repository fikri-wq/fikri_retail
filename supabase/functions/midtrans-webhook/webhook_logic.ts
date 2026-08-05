/**
 * webhook_logic.ts
 * Pure business-logic helpers untuk midtrans-webhook Edge Function.
 * Dipisahkan agar dapat diuji secara unit/property tanpa Deno.serve().
 *
 * Requirements: 4.3, 4.4, 4.8
 */

// ─── Types ────────────────────────────────────────────────────────────────────

export type PaymentStatus = "unpaid" | "paid" | "failed";
export type OrderStatus = "pending" | "diantar" | "selesai" | "cancelled";

export type TransactionStatus =
  | "pending"
  | "capture"
  | "settlement"
  | "cancel"
  | "expire"
  | "deny";

export type FraudStatus = "accept" | "challenge" | "deny";

/** Subset dari tabel orders yang relevan untuk idempoten-check dan update. */
export interface OrderRecord {
  payment_status: PaymentStatus;
  status: OrderStatus;
  midtrans_transaction_id: string | null;
}

/** Hasil dari applyTransactionStatus — null berarti "tidak ada perubahan". */
export interface StatusUpdate {
  payment_status: PaymentStatus;
  status: OrderStatus;
  midtrans_transaction_id: string | null;
}

// ─── Pure Logic ───────────────────────────────────────────────────────────────

/**
 * Menentukan apakah database perlu diupdate berdasarkan status order saat ini
 * dan notifikasi webhook yang masuk.
 *
 * Idempoten (Requirements 4.8):
 *   Jika payment_status order sudah 'paid', kembalikan null (tidak ada update).
 *
 * Pemetaan transaction_status → StatusUpdate (Requirements 4.3, 4.4):
 *   'settlement'                          → payment_status='paid',   status='diantar'
 *   'capture' + fraud_status='accept'     → payment_status='paid',   status='diantar'
 *   'cancel' | 'expire' | 'deny'          → payment_status='failed', status tidak berubah
 *   'pending'                             → null (tidak ada perubahan)
 *
 * @param currentOrder        - Baris order saat ini dari database
 * @param transactionStatus   - transaction_status dari payload Midtrans
 * @param fraudStatus         - fraud_status dari payload Midtrans (opsional)
 * @param transactionId       - transaction_id dari payload Midtrans (untuk settlement)
 * @returns StatusUpdate jika ada perubahan yang perlu di-UPDATE, atau null.
 */
export function applyTransactionStatus(
  currentOrder: OrderRecord,
  transactionStatus: TransactionStatus,
  fraudStatus: FraudStatus | undefined,
  transactionId: string,
): StatusUpdate | null {
  // ── Idempoten check (Requirements 4.8) ──────────────────────────────────────
  // Jika order sudah 'paid', tidak ada UPDATE yang perlu dilakukan.
  if (currentOrder.payment_status === "paid") {
    return null;
  }

  // ── Pemetaan transaction_status (Requirements 4.3, 4.4) ────────────────────
  if (
    transactionStatus === "settlement" ||
    (transactionStatus === "capture" && fraudStatus === "accept")
  ) {
    return {
      payment_status: "paid",
      status: "diantar",
      midtrans_transaction_id: transactionId,
    };
  }

  if (
    transactionStatus === "cancel" ||
    transactionStatus === "expire" ||
    transactionStatus === "deny"
  ) {
    return {
      payment_status: "failed",
      status: currentOrder.status, // status tetap tidak berubah
      midtrans_transaction_id: currentOrder.midtrans_transaction_id,
    };
  }

  // 'pending' atau status lainnya → tidak ada perubahan
  return null;
}
