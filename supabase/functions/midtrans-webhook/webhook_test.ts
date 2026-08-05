/**
 * webhook_test.ts
 * Property-based test untuk idempoten webhook Midtrans.
 *
 * Property 3: Idempoten Webhook Processing
 *   Validates: Requirements 4.8
 *
 *   ∀ order dengan payment_status = 'paid':
 *     applyTransactionStatus(anyNotification, order) → null
 *     (tidak ada UPDATE query yang dieksekusi ulang)
 *
 * Diuji dengan ≥100 kombinasi notification payload yang berbeda.
 */

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  applyTransactionStatus,
  type FraudStatus,
  type OrderRecord,
  type OrderStatus,
  type TransactionStatus,
} from "./webhook_logic.ts";

// ─── Generators ───────────────────────────────────────────────────────────────

const ALL_TRANSACTION_STATUSES: TransactionStatus[] = [
  "pending",
  "capture",
  "settlement",
  "cancel",
  "expire",
  "deny",
];

const ALL_FRAUD_STATUSES: Array<FraudStatus | undefined> = [
  "accept",
  "challenge",
  "deny",
  undefined,
];

const ALL_ORDER_STATUSES: OrderStatus[] = [
  "pending",
  "diantar",
  "selesai",
  "cancelled",
];

const CHARS = "abcdefghijklmnopqrstuvwxyz0123456789-_";

/** Membuat string acak dengan panjang antara minLen dan maxLen. */
function randomString(minLen: number, maxLen: number): string {
  const len = minLen + Math.floor(Math.random() * (maxLen - minLen + 1));
  let result = "";
  for (let i = 0; i < len; i++) {
    result += CHARS[Math.floor(Math.random() * CHARS.length)];
  }
  return result;
}

/** Memilih elemen acak dari array. */
function randomPick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

/** Membuat OrderRecord acak dengan payment_status = 'paid'. */
function randomPaidOrder(): OrderRecord {
  return {
    payment_status: "paid",
    status: randomPick(ALL_ORDER_STATUSES),
    midtrans_transaction_id: Math.random() > 0.3
      ? randomString(10, 36)
      : null,
  };
}

/** Membuat kombinasi notification yang bervariasi. */
function randomNotification(): {
  transactionStatus: TransactionStatus;
  fraudStatus: FraudStatus | undefined;
  transactionId: string;
} {
  return {
    transactionStatus: randomPick(ALL_TRANSACTION_STATUSES),
    fraudStatus: randomPick(ALL_FRAUD_STATUSES),
    transactionId: randomString(8, 36),
  };
}

// ─── Property 3: Idempoten Webhook Processing ─────────────────────────────────

/**
 * **Validates: Requirements 4.8**
 *
 * Property 3: Idempoten Webhook Processing
 *
 * Untuk SETIAP order dengan payment_status = 'paid',
 * memanggil applyTransactionStatus() dengan notifikasi APAPUN
 * harus selalu mengembalikan null — artinya tidak ada UPDATE database yang dilakukan.
 *
 * Diuji dengan ≥100 kombinasi notifikasi yang berbeda-beda.
 */
Deno.test(
  "Property 3: order yang sudah 'paid' tidak menghasilkan UPDATE untuk notifikasi apapun (≥100 kombinasi)",
  () => {
    const ITERATIONS = 100;

    for (let i = 0; i < ITERATIONS; i++) {
      const paidOrder = randomPaidOrder();
      const notification = randomNotification();

      const result = applyTransactionStatus(
        paidOrder,
        notification.transactionStatus,
        notification.fraudStatus,
        notification.transactionId,
      );

      assertEquals(
        result,
        null,
        `Iterasi ${i + 1}: applyTransactionStatus harus mengembalikan null ` +
          `saat payment_status='paid'. ` +
          `transaction_status="${notification.transactionStatus}", ` +
          `fraud_status="${notification.fraudStatus ?? "undefined"}", ` +
          `order.status="${paidOrder.status}"`,
      );
    }
  },
);

// ─── Property 3 — Exhaustive: semua kombinasi transaction_status × fraud_status ───

/**
 * **Validates: Requirements 4.8**
 *
 * Ekshaustif: menguji setiap kombinasi transaction_status × fraud_status
 * terhadap berbagai order yang sudah 'paid'.
 * Memastikan tidak ada kombinasi yang "lolos" dari idempoten-check.
 */
Deno.test(
  "Property 3: semua kombinasi transaction_status × fraud_status ditolak untuk order 'paid'",
  () => {
    // Setiap kombinasi transaction_status × fraud_status diuji dengan 10 order berbeda
    const ORDERS_PER_COMBO = 10;

    for (const transactionStatus of ALL_TRANSACTION_STATUSES) {
      for (const fraudStatus of ALL_FRAUD_STATUSES) {
        for (let k = 0; k < ORDERS_PER_COMBO; k++) {
          const paidOrder = randomPaidOrder();
          const transactionId = randomString(8, 36);

          const result = applyTransactionStatus(
            paidOrder,
            transactionStatus,
            fraudStatus,
            transactionId,
          );

          assertEquals(
            result,
            null,
            `applyTransactionStatus harus null untuk order 'paid'. ` +
              `transaction_status="${transactionStatus}", ` +
              `fraud_status="${fraudStatus ?? "undefined"}", ` +
              `order.status="${paidOrder.status}"`,
          );
        }
      }
    }
    // Total: 6 transaction_status × 4 fraud_status × 10 orders = 240 kombinasi
  },
);

// ─── Kontras: order yang BELUM paid boleh menghasilkan UPDATE ────────────────

/**
 * Tes kontras untuk memastikan idempoten-check TIDAK memblokir update yang sah.
 * Order dengan payment_status = 'unpaid' atau 'failed' HARUS bisa diupdate
 * saat menerima notifikasi 'settlement'.
 *
 * Ini bukan Property 3, tetapi memvalidasi bahwa implementasi idempoten
 * tidak terlalu agresif (over-blocking).
 */
Deno.test(
  "Kontras: order 'unpaid' menerima settlement → menghasilkan update (bukan null)",
  () => {
    const ITERATIONS = 50;

    for (let i = 0; i < ITERATIONS; i++) {
      const unpaidOrder: OrderRecord = {
        payment_status: "unpaid",
        status: randomPick(["pending", "diantar", "selesai", "cancelled"]),
        midtrans_transaction_id: null,
      };

      const transactionId = randomString(8, 36);

      // settlement harus menghasilkan update ke 'paid'
      const settlementResult = applyTransactionStatus(
        unpaidOrder,
        "settlement",
        undefined,
        transactionId,
      );

      assertEquals(
        settlementResult !== null,
        true,
        `Iterasi ${i + 1}: order 'unpaid' + 'settlement' harus menghasilkan update (bukan null)`,
      );
      assertEquals(
        settlementResult?.payment_status,
        "paid",
        `Iterasi ${i + 1}: settlement harus menghasilkan payment_status='paid'`,
      );

      // capture + accept juga harus menghasilkan update ke 'paid'
      const captureResult = applyTransactionStatus(
        unpaidOrder,
        "capture",
        "accept",
        transactionId,
      );

      assertEquals(
        captureResult !== null,
        true,
        `Iterasi ${i + 1}: order 'unpaid' + 'capture'+'accept' harus menghasilkan update`,
      );
      assertEquals(
        captureResult?.payment_status,
        "paid",
        `Iterasi ${i + 1}: capture+accept harus menghasilkan payment_status='paid'`,
      );
    }
  },
);

// ─── Edge Cases: order 'failed' juga bersifat idempoten untuk paid ────────────

/**
 * Memastikan bahwa hanya order dengan payment_status = 'paid' yang mendapat
 * perlakuan idempoten. Order 'failed' masih bisa menerima update.
 */
Deno.test(
  "Edge case: order 'failed' menerima settlement → menghasilkan update ke 'paid'",
  () => {
    const ITERATIONS = 30;

    for (let i = 0; i < ITERATIONS; i++) {
      const failedOrder: OrderRecord = {
        payment_status: "failed",
        status: "pending",
        midtrans_transaction_id: null,
      };

      const transactionId = randomString(8, 36);

      const result = applyTransactionStatus(
        failedOrder,
        "settlement",
        undefined,
        transactionId,
      );

      assertEquals(
        result !== null,
        true,
        `Iterasi ${i + 1}: order 'failed' + 'settlement' harus menghasilkan update (bukan null)`,
      );
      assertEquals(
        result?.payment_status,
        "paid",
        `Iterasi ${i + 1}: settlement pada order 'failed' harus menghasilkan payment_status='paid'`,
      );
    }
  },
);
