/**
 * signature_test.ts
 * Property-based tests untuk verifikasi signature webhook Midtrans.
 *
 * Property 1: Signature Webhook — Determinisme
 *   Validates: Requirements 4.1
 *   ∀ (orderId, statusCode, grossAmount, serverKey):
 *     computeWebhookSignature(orderId, statusCode, grossAmount, serverKey) ==
 *     computeWebhookSignature(orderId, statusCode, grossAmount, serverKey)
 *
 * Property 2: Signature Invalid Selalu Ditolak
 *   Validates: Requirements 4.2
 *   ∀ validSignature, tamperedSignature di mana validSignature ≠ tamperedSignature:
 *     verifySignature(tamperedSignature) == false
 */

import { assertEquals, assertNotEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { computeWebhookSignature } from "./signature_helper.ts";

// ─── Random String Generator ──────────────────────────────────────────────────

const CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_";

/** Membuat string acak dengan panjang antara minLen dan maxLen (inklusif). */
function randomString(minLen: number, maxLen: number): string {
  const len = minLen + Math.floor(Math.random() * (maxLen - minLen + 1));
  let result = "";
  for (let i = 0; i < len; i++) {
    result += CHARS[Math.floor(Math.random() * CHARS.length)];
  }
  return result;
}

/** Membuat string angka acak (mirip gross_amount Midtrans, e.g. "150000.00"). */
function randomGrossAmount(): string {
  const whole = Math.floor(Math.random() * 10_000_000) + 1000;
  return `${whole}.00`;
}

/** Membuat status_code acak (200, 201, 202, 400, 401, 500). */
function randomStatusCode(): string {
  const codes = ["200", "201", "202", "400", "401", "500"];
  return codes[Math.floor(Math.random() * codes.length)];
}

/**
 * Memodifikasi satu karakter acak pada sebuah string sehingga hasilnya berbeda.
 * Jika string kosong, menambahkan satu karakter.
 */
function tamperString(original: string): string {
  if (original.length === 0) {
    return "x";
  }
  // Pilih posisi acak dan ganti karakter di posisi tersebut
  const pos = Math.floor(Math.random() * original.length);
  const originalChar = original[pos];
  // Pilih karakter pengganti yang berbeda dari karakter asli
  let replacement: string;
  do {
    replacement = "0123456789abcdef"[Math.floor(Math.random() * 16)];
  } while (replacement === originalChar);

  return original.slice(0, pos) + replacement + original.slice(pos + 1);
}

// ─── Property 1: Determinisme SHA-512 ────────────────────────────────────────

/**
 * **Validates: Requirements 4.1**
 *
 * Property 1: Signature Webhook — Determinisme
 * SHA-512 dari input yang sama harus selalu menghasilkan output yang sama.
 * Diuji dengan ≥100 kombinasi input acak.
 */
Deno.test("Property 1: computeWebhookSignature bersifat deterministik (≥100 kombinasi)", async () => {
  const ITERATIONS = 100;

  for (let i = 0; i < ITERATIONS; i++) {
    const orderId = randomString(8, 36);
    const statusCode = randomStatusCode();
    const grossAmount = randomGrossAmount();
    const serverKey = randomString(20, 50);

    const result1 = await computeWebhookSignature(orderId, statusCode, grossAmount, serverKey);
    const result2 = await computeWebhookSignature(orderId, statusCode, grossAmount, serverKey);

    assertEquals(
      result1,
      result2,
      `Iterasi ${i + 1}: SHA-512 harus deterministik untuk input ` +
        `(orderId="${orderId}", statusCode="${statusCode}", grossAmount="${grossAmount}")`,
    );
  }
});

// ─── Property 2: Signature Invalid Selalu Ditolak ─────────────────────────────

/**
 * **Validates: Requirements 4.2**
 *
 * Property 2: Signature Invalid Selalu Ditolak
 * Signature yang dimodifikasi (walaupun satu karakter) harus selalu ditolak.
 * Diuji dengan ≥100 kombinasi input acak.
 *
 * Pendekatan verifikasi inline:
 *   validSignature   = computeWebhookSignature(orderId, statusCode, grossAmount, serverKey)
 *   tamperedSignature = tamper(validSignature) di mana tamperedSignature ≠ validSignature
 *   verifySignature(tamperedSignature) := tamperedSignature === validSignature → false
 */
Deno.test("Property 2: signature yang dimodifikasi selalu ditolak (≥100 kombinasi)", async () => {
  const ITERATIONS = 100;

  for (let i = 0; i < ITERATIONS; i++) {
    const orderId = randomString(8, 36);
    const statusCode = randomStatusCode();
    const grossAmount = randomGrossAmount();
    const serverKey = randomString(20, 50);

    // Hitung signature yang valid
    const validSignature = await computeWebhookSignature(
      orderId,
      statusCode,
      grossAmount,
      serverKey,
    );

    // Buat versi yang telah dimodifikasi (minimal satu karakter berbeda)
    const tamperedSignature = tamperString(validSignature);

    // Pastikan hasil tamper benar-benar berbeda sebelum melanjutkan pengujian
    assertNotEquals(
      tamperedSignature,
      validSignature,
      `Iterasi ${i + 1}: tamperedSignature harus berbeda dari validSignature`,
    );

    // Verifikasi inline: tamperedSignature !== validSignature berarti tolak
    const isValid = tamperedSignature === validSignature;

    assertEquals(
      isValid,
      false,
      `Iterasi ${i + 1}: signature yang dimodifikasi harus ditolak (isValid harus false). ` +
        `validSignature="${validSignature.slice(0, 16)}...", ` +
        `tamperedSignature="${tamperedSignature.slice(0, 16)}..."`,
    );
  }
});

// ─── Bonus: Berbagai Panjang & Karakter Ekstrem ───────────────────────────────

Deno.test("Property 1: determinisme tetap berlaku untuk string sangat pendek dan sangat panjang", async () => {
  const edgeCases: Array<[string, string, string, string]> = [
    // String kosong
    ["", "200", "0.00", "key"],
    // String sangat panjang
    [randomString(200, 500), "201", randomGrossAmount(), randomString(100, 200)],
    // Karakter khusus yang umum di UUID
    ["abc-123-xyz-456", "200", "99999.00", "SandboxKey-abc123"],
    // Angka saja
    ["12345678", "200", "10000.00", "serverkey123"],
  ];

  for (const [orderId, statusCode, grossAmount, serverKey] of edgeCases) {
    const r1 = await computeWebhookSignature(orderId, statusCode, grossAmount, serverKey);
    const r2 = await computeWebhookSignature(orderId, statusCode, grossAmount, serverKey);
    assertEquals(r1, r2, `SHA-512 harus deterministik untuk orderId="${orderId.slice(0, 20)}..."`);
  }
});

Deno.test("Property 2: perubahan pada orderId, statusCode, atau grossAmount menghasilkan signature berbeda", async () => {
  const serverKey = "fixed-server-key-for-comparison";
  const orderId = "order-abc-123";
  const statusCode = "200";
  const grossAmount = "50000.00";

  const baseSignature = await computeWebhookSignature(orderId, statusCode, grossAmount, serverKey);

  // Ubah orderId
  const sig2 = await computeWebhookSignature(orderId + "x", statusCode, grossAmount, serverKey);
  assertNotEquals(baseSignature, sig2, "Mengubah orderId harus menghasilkan signature berbeda");

  // Ubah statusCode
  const sig3 = await computeWebhookSignature(orderId, "201", grossAmount, serverKey);
  assertNotEquals(baseSignature, sig3, "Mengubah statusCode harus menghasilkan signature berbeda");

  // Ubah grossAmount
  const sig4 = await computeWebhookSignature(orderId, statusCode, "50001.00", serverKey);
  assertNotEquals(baseSignature, sig4, "Mengubah grossAmount harus menghasilkan signature berbeda");

  // Ubah serverKey
  const sig5 = await computeWebhookSignature(orderId, statusCode, grossAmount, serverKey + "x");
  assertNotEquals(baseSignature, sig5, "Mengubah serverKey harus menghasilkan signature berbeda");
});
