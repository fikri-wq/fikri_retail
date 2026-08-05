/**
 * signature_helper.ts
 * Helper module untuk komputasi SHA-512 signature webhook Midtrans.
 * Dipisahkan agar dapat diimpor oleh index.ts dan signature_test.ts.
 * Requirements: 4.1, 4.2
 */

/**
 * Menghitung SHA-512 hash dari string gabungan untuk verifikasi webhook Midtrans.
 * Format: SHA-512(order_id + status_code + gross_amount + server_key)
 *
 * @param orderId       - ID pesanan (order_id dari payload Midtrans)
 * @param statusCode    - Status code HTTP (status_code dari payload Midtrans)
 * @param grossAmount   - Total harga string (gross_amount dari payload Midtrans)
 * @param serverKey     - Server key Midtrans (dari environment variable)
 * @returns             - Hex string hasil SHA-512
 */
export async function computeWebhookSignature(
  orderId: string,
  statusCode: string,
  grossAmount: string,
  serverKey: string,
): Promise<string> {
  const input = orderId + statusCode + grossAmount + serverKey;
  const encoded = new TextEncoder().encode(input);
  const hashBuffer = await crypto.subtle.digest("SHA-512", encoded);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}
