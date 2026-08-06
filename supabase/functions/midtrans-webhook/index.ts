// Edge Function: midtrans-webhook
// Menerima notifikasi pembayaran dari Midtrans, verifikasi signature, update status order di DB
// Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8

// ─── TypeScript Interfaces ────────────────────────────────────────────────────

/** Payload webhook dari Midtrans */
interface MidtransNotification {
  transaction_id: string;
  order_id: string;
  status_code: string;
  gross_amount: string;
  signature_key: string;
  transaction_status:
    | "pending"
    | "capture"
    | "settlement"
    | "cancel"
    | "expire"
    | "deny";
  fraud_status?: "accept" | "challenge" | "deny";
  payment_type?: string;
}

/** Response ke Midtrans (HTTP 200) */
interface WebhookResponse {
  status: "ok";
}

/** Response error */
interface ErrorResponse {
  error: string;
}

// ─── CORS Headers ─────────────────────────────────────────────────────────────
// Ditambahkan untuk konsistensi dengan Edge Function lain, meskipun webhook
// dari Midtrans tidak menggunakan CORS secara langsung.

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

// ─── Field Wajib Webhook ──────────────────────────────────────────────────────

const REQUIRED_FIELDS: Array<keyof MidtransNotification> = [
  "order_id",
  "status_code",
  "gross_amount",
  "signature_key",
  "transaction_status",
];

// ─── Validation ───────────────────────────────────────────────────────────────

/**
 * Memvalidasi bahwa semua field wajib hadir dalam payload webhook.
 * Returns null jika valid, atau pesan error string jika ada field yang hilang.
 * Requirements: 4.7
 */
function validateNotification(body: unknown): string | null {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return "Request body harus berupa JSON object";
  }

  const payload = body as Record<string, unknown>;

  for (const field of REQUIRED_FIELDS) {
    if (
      payload[field] === undefined ||
      payload[field] === null ||
      payload[field] === ""
    ) {
      return `Field wajib '${field}' tidak ada atau kosong dalam payload webhook`;
    }
  }

  return null;
}

// ─── SHA-512 Signature Helper ─────────────────────────────────────────────────
// Fungsi diimpor dari signature_helper.ts agar dapat digunakan juga oleh test.
// Requirements: 4.1, 4.2

import { computeWebhookSignature } from "./signature_helper.ts";

// ─── Main Handler ─────────────────────────────────────────────────────────────

Deno.serve(async (req: Request): Promise<Response> => {
  // Handle CORS preflight request
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  // Hanya menerima metode POST (Midtrans mengirim webhook via POST)
  if (req.method !== "POST") {
    const errorBody: ErrorResponse = {
      error: "Method tidak diizinkan. Webhook Midtrans harus menggunakan POST.",
    };
    return new Response(JSON.stringify(errorBody), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── Parse JSON body ──────────────────────────────────────────────────────────
  // Requirements: 4.7 — return HTTP 400 jika body tidak valid JSON
  let rawBody: unknown;
  try {
    rawBody = await req.json();
  } catch {
    const errorBody: ErrorResponse = {
      error:
        "Request body tidak dapat di-parse sebagai JSON valid",
    };
    return new Response(JSON.stringify(errorBody), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── Validasi field wajib ─────────────────────────────────────────────────────
  // Requirements: 4.7 — return HTTP 400 jika field wajib tidak lengkap
  const validationError = validateNotification(rawBody);
  if (validationError !== null) {
    const errorBody: ErrorResponse = { error: validationError };
    return new Response(JSON.stringify(errorBody), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const notification = rawBody as MidtransNotification;

  console.log(
    `[midtrans-webhook] Menerima notifikasi untuk order_id: ${notification.order_id}, ` +
      `transaction_status: ${notification.transaction_status}, status_code: ${notification.status_code}`
  );

  // ── Task 4.2: Verifikasi SHA-512 Signature ───────────────────────────────────
  // Requirements: 4.1, 4.2
  const serverKey = Deno.env.get("MIDTRANS_SERVER_KEY");
  if (!serverKey) {
    console.error("[midtrans-webhook] MIDTRANS_SERVER_KEY tidak tersedia");
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const expectedSignature = await computeWebhookSignature(
    notification.order_id,
    notification.status_code,
    notification.gross_amount,
    serverKey,
  );

  if (notification.signature_key !== expectedSignature) {
    console.warn(
      `[midtrans-webhook] Invalid signature for order_id: ${notification.order_id}`
    );
    return new Response(JSON.stringify({ error: "Invalid signature" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  console.log(
    `[midtrans-webhook] Signature verified for order_id: ${notification.order_id}. ` +
      `Proceeding to database update (Task 4.3).`
  );

  // ── Task 4.3: Update Database ─────────────────────────────────────────────
  // Requirements: 4.3, 4.4, 4.5, 4.6, 4.8, 7.5

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    console.error(
      "[midtrans-webhook] SUPABASE_URL atau SUPABASE_SERVICE_ROLE_KEY tidak tersedia"
    );
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  console.log(`[midtrans-webhook] SUPABASE_URL available: ${!!supabaseUrl}, SERVICE_ROLE_KEY available: ${!!serviceRoleKey}`);
  console.log(`[midtrans-webhook] SUPABASE_URL value: ${supabaseUrl}`);

  // ── 1. Lookup order berdasarkan order_id ─────────────────────────────────
  const lookupUrl =
    `${supabaseUrl}/rest/v1/orders?id=eq.${encodeURIComponent(notification.order_id)}&select=id,payment_status`;
  
  console.log(`[midtrans-webhook] Lookup URL: ${lookupUrl}`);

  const lookupRes = await fetch(lookupUrl, {
    method: "GET",
    headers: {
      "apikey": serviceRoleKey,
      "Authorization": `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json",
    },
  });

  if (!lookupRes.ok) {
    const errBody = await lookupRes.text();
    console.error(
      `[midtrans-webhook] Gagal lookup order ${notification.order_id}: HTTP ${lookupRes.status} — ${errBody}`
    );
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const orders = await lookupRes.json() as Array<{
    id: string;
    payment_status: string;
  }>;

  if (!orders || orders.length === 0) {
    console.error(
      `[midtrans-webhook] Order tidak ditemukan untuk order_id: ${notification.order_id}`
    );
    return new Response(JSON.stringify({ error: "Order not found" }), {
      status: 404,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const order = orders[0];

  // ── 2. Idempoten: jika sudah 'paid', tidak perlu UPDATE ulang ────────────
  // Requirements: 4.8
  if (order.payment_status === "paid") {
    console.log(
      `[midtrans-webhook] Order ${notification.order_id} sudah berstatus 'paid'. Idempoten — skip UPDATE.`
    );
    const okResponse: WebhookResponse = { status: "ok" };
    return new Response(JSON.stringify(okResponse), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── 3. Tentukan update payload berdasarkan transaction_status ────────────
  // Requirements: 4.3, 4.4
  const { transaction_status, fraud_status, transaction_id } = notification;

  let updatePayload: Record<string, string> | null = null;

  const isSettled = transaction_status === "settlement";
  const isCaptureAccepted =
    transaction_status === "capture" && fraud_status === "accept";

  if (isSettled || isCaptureAccepted) {
    // Requirements: 4.3 — settlement/capture+accept → paid + diantar + simpan transaction_id
    updatePayload = {
      payment_status: "paid",
      status: "diantar",
      midtrans_transaction_id: transaction_id,
    };
    console.log(
      `[midtrans-webhook] order_id: ${notification.order_id} → payment_status='paid', status='diantar'`
    );
  } else if (
    transaction_status === "cancel" ||
    transaction_status === "expire" ||
    transaction_status === "deny"
  ) {
    // Requirements: 4.4 — cancel/expire/deny → failed (status dibiarkan 'pending')
    updatePayload = {
      payment_status: "failed",
    };
    console.log(
      `[midtrans-webhook] order_id: ${notification.order_id} → payment_status='failed' (${transaction_status})`
    );
  } else if (transaction_status === "pending") {
    // Requirements: 4.3 — pending: tidak ada perubahan pada order
    console.log(
      `[midtrans-webhook] order_id: ${notification.order_id} transaction_status='pending' — tidak ada perubahan DB.`
    );
    const okResponse: WebhookResponse = { status: "ok" };
    return new Response(JSON.stringify(okResponse), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } else {
    // transaction_status tidak dikenali — log dan return 200 tanpa update
    console.log(
      `[midtrans-webhook] order_id: ${notification.order_id} transaction_status tidak dikenali: '${transaction_status}' — tidak ada perubahan DB.`
    );
    const okResponse: WebhookResponse = { status: "ok" };
    return new Response(JSON.stringify(okResponse), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── 4. Eksekusi UPDATE via Supabase REST API dengan service_role key ──────
  // Requirements: 7.5 — bypass RLS menggunakan SUPABASE_SERVICE_ROLE_KEY
  const updateUrl =
    `${supabaseUrl}/rest/v1/orders?id=eq.${encodeURIComponent(notification.order_id)}`;

  const updateRes = await fetch(updateUrl, {
    method: "PATCH",
    headers: {
      "apikey": serviceRoleKey,
      "Authorization": `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json",
      "Prefer": "return=minimal",
    },
    body: JSON.stringify(updatePayload),
  });

  if (!updateRes.ok) {
    const errText = await updateRes.text();
    console.error(
      `[midtrans-webhook] Gagal UPDATE order ${notification.order_id}: HTTP ${updateRes.status} — ${errText}`
    );
    return new Response(JSON.stringify({ error: "Gagal memperbarui order" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  console.log(
    `[midtrans-webhook] UPDATE berhasil untuk order_id: ${notification.order_id}`
  );

  // ── 5. Return HTTP 200 { "status": "ok" } — Requirements: 4.5 ────────────
  const okResponse: WebhookResponse = { status: "ok" };
  return new Response(JSON.stringify(okResponse), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
