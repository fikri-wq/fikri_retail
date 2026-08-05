// Edge Function: create-midtrans-transaction
// Menerima order data dari Flutter, memanggil Midtrans Snap API, mengembalikan snap_token
// Requirements: 1.1, 1.2, 1.3, 1.6, 1.7

// ─── TypeScript Interfaces ────────────────────────────────────────────────────

/** Request body yang diterima dari Flutter */
interface CreateTransactionRequest {
  order_id: string;        // UUID pesanan baru
  customer_id: string;     // UUID customer (harus cocok dengan JWT sub)
  customer_email: string;  // Email customer
  customer_name: string;   // Nama customer
  customer_phone: string;  // Nomor telepon customer
  total_amount: number;    // Total harga dalam Rupiah (integer)
  items: Array<{
    product_id: string;
    name: string;
    price: number;
    quantity: number;
    image_url?: string;
  }>;
}

/** Response ke Flutter (HTTP 200) */
interface CreateTransactionResponse {
  snap_token: string;
  redirect_url: string;
}

/** Response error (HTTP 4xx/5xx) */
interface ErrorResponse {
  error: string;
}

// ─── CORS Headers ─────────────────────────────────────────────────────────────

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

// ─── Validation ───────────────────────────────────────────────────────────────

/**
 * Memvalidasi field wajib pada request body.
 * Returns null jika valid, atau pesan error string jika ada field yang hilang/tidak valid.
 */
function validateRequest(body: unknown): string | null {
  if (!body || typeof body !== "object") {
    return "Request body harus berupa JSON object";
  }

  const req = body as Record<string, unknown>;

  if (!req.order_id || typeof req.order_id !== "string") {
    return "Field 'order_id' wajib diisi dan harus berupa string";
  }
  if (!req.customer_id || typeof req.customer_id !== "string") {
    return "Field 'customer_id' wajib diisi dan harus berupa string";
  }
  if (!req.customer_email || typeof req.customer_email !== "string") {
    return "Field 'customer_email' wajib diisi dan harus berupa string";
  }
  if (
    req.total_amount === undefined ||
    req.total_amount === null ||
    typeof req.total_amount !== "number" ||
    req.total_amount <= 0
  ) {
    return "Field 'total_amount' wajib diisi, harus berupa angka positif";
  }
  if (!req.items || !Array.isArray(req.items) || req.items.length === 0) {
    return "Field 'items' wajib diisi dan harus berupa array yang tidak kosong";
  }

  return null;
}

// ─── JWT Verification ─────────────────────────────────────────────────────────

/**
 * Decode base64url string ke string JSON.
 */
function base64urlDecodeToString(base64url: string): string {
  const base64 = base64url
    .replace(/-/g, "+")
    .replace(/_/g, "/")
    .padEnd(base64url.length + (4 - (base64url.length % 4)) % 4, "=");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return new TextDecoder().decode(bytes);
}

/**
 * Verifikasi JWT menggunakan Supabase Auth API.
 * Menggunakan endpoint /auth/v1/user dengan Bearer token untuk memvalidasi
 * JWT secara server-side — lebih reliable daripada verifikasi signature manual.
 * Returns decoded payload jika valid.
 * Throws Error jika JWT tidak valid atau expired.
 */
async function verifyJwt(token: string): Promise<Record<string, unknown>> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error("Konfigurasi Supabase tidak tersedia");
  }

  // Verifikasi JWT dengan memanggil Supabase Auth API
  const res = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      "Authorization": `Bearer ${token}`,
      "apikey": supabaseAnonKey,
    },
  });

  if (!res.ok) {
    throw new Error("JWT tidak valid atau sudah kedaluwarsa");
  }

  // Decode payload dari JWT untuk mendapatkan 'sub' (user ID)
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new Error("Format JWT tidak valid");
  }

  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(base64urlDecodeToString(parts[1]));
  } catch {
    throw new Error("Payload JWT tidak dapat di-parse");
  }

  return payload;
}

// ─── Main Handler ─────────────────────────────────────────────────────────────

Deno.serve(async (req: Request): Promise<Response> => {
  // Handle CORS preflight request (Flutter Web)
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  // Hanya menerima metode POST
  if (req.method !== "POST") {
    const errorBody: ErrorResponse = { error: "Method tidak diizinkan. Gunakan POST." };
    return new Response(JSON.stringify(errorBody), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── Parse JSON body ──────────────────────────────────────────────────────────
  let requestBody: unknown;
  try {
    requestBody = await req.json();
  } catch {
    const errorBody: ErrorResponse = { error: "Request body tidak dapat di-parse sebagai JSON" };
    return new Response(JSON.stringify(errorBody), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── Validasi field wajib ─────────────────────────────────────────────────────
  const validationError = validateRequest(requestBody);
  if (validationError !== null) {
    const errorBody: ErrorResponse = { error: validationError };
    return new Response(JSON.stringify(errorBody), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const body = requestBody as CreateTransactionRequest;

  // ── Task 2.2: Verifikasi JWT Supabase ────────────────────────────────────────

  // 1. Baca header Authorization: Bearer <token>
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    const errorBody: ErrorResponse = { error: "Unauthorized" };
    return new Response(JSON.stringify(errorBody), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  const token = authHeader.replace("Bearer ", "").trim();

  // 2. Decode dan verifikasi JWT menggunakan SUPABASE_JWT_SECRET (HMAC-SHA256)
  let jwtPayload: Record<string, unknown>;
  try {
    jwtPayload = await verifyJwt(token);
  } catch {
    const errorBody: ErrorResponse = { error: "Unauthorized" };
    return new Response(JSON.stringify(errorBody), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // 3. Bandingkan customer_id di body dengan sub dari JWT → HTTP 403 jika tidak cocok
  const jwtSub = jwtPayload["sub"];
  if (!jwtSub || jwtSub !== body.customer_id) {
    const errorBody: ErrorResponse = { error: "Forbidden" };
    return new Response(JSON.stringify(errorBody), {
      status: 403,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  console.log(`[create-midtrans-transaction] JWT verified for customer_id: ${body.customer_id}, order_id: ${body.order_id}`);

  // ── Task 2.3: Logika utama pembuatan transaksi Midtrans ─────────────────────

  // 1. Cek duplikat snap_token untuk order_id yang sama → HTTP 409 jika sudah ada
  // Requirements: 1.8
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  let checkRes: Response;
  try {
    checkRes = await fetch(
      `${supabaseUrl}/rest/v1/orders?id=eq.${body.order_id}&select=snap_token`,
      {
        headers: {
          "apikey": serviceRoleKey,
          "Authorization": `Bearer ${serviceRoleKey}`,
        },
      },
    );
  } catch (err) {
    console.error("[create-midtrans-transaction] Gagal mengakses DB untuk cek duplikat:", err);
    const errBody: ErrorResponse = { error: "Gagal memeriksa status pesanan. Coba lagi." };
    return new Response(JSON.stringify(errBody), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const orders = await checkRes.json() as Array<{ snap_token: string | null }>;
  if (orders.length > 0 && orders[0].snap_token) {
    console.log(`[create-midtrans-transaction] Duplicate snap_token detected for order_id: ${body.order_id}`);
    const errBody: ErrorResponse = { error: "Pesanan ini sudah memiliki sesi pembayaran aktif." };
    return new Response(JSON.stringify(errBody), {
      status: 409,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // 2. Baca MIDTRANS_SERVER_KEY dari Deno.env.get() — tidak dari body/header client
  // Requirements: 1.2, 1.7
  const serverKey = Deno.env.get("MIDTRANS_SERVER_KEY");
  if (!serverKey) {
    console.error("[create-midtrans-transaction] MIDTRANS_SERVER_KEY tidak tersedia di environment");
    const errBody: ErrorResponse = { error: "Konfigurasi server tidak lengkap." };
    return new Response(JSON.stringify(errBody), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // 3. Bangun payload SnapApiRequest
  // Requirements: 1.3, 1.6
  interface SnapApiRequest {
    transaction_details: { order_id: string; gross_amount: number; };
    customer_details: { first_name: string; email: string; phone: string; };
    item_details: Array<{ id: string; name: string; price: number; quantity: number; }>;
  }

  const snapPayload: SnapApiRequest = {
    transaction_details: {
      order_id: body.order_id,
      gross_amount: body.total_amount,
    },
    customer_details: {
      first_name: body.customer_name,
      email: body.customer_email,
      phone: body.customer_phone,
    },
    item_details: body.items.map((item) => ({
      id: item.product_id,
      name: item.name,
      price: item.price,
      quantity: item.quantity,
    })),
  };

  // 4. POST ke Midtrans Snap API dengan Basic Auth + timeout 10 detik
  // Requirements: 1.2, 1.4, 1.9
  const basicAuth = btoa(serverKey + ":");
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 10000);

  let snapRes: Response;
  try {
    snapRes = await fetch("https://app.sandbox.midtrans.com/snap/transactions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Basic ${basicAuth}`,
      },
      body: JSON.stringify(snapPayload),
      signal: controller.signal,
    });
  } catch (err) {
    clearTimeout(timeoutId);
    // Handle timeout (AbortError) → HTTP 504
    // Requirements: 1.9
    if (err instanceof DOMException && err.name === "AbortError") {
      console.error("[create-midtrans-transaction] Midtrans API timeout setelah 10 detik");
      const errBody: ErrorResponse = { error: "Layanan pembayaran tidak merespons. Coba lagi." };
      return new Response(JSON.stringify(errBody), {
        status: 504,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    // Handle network / other fetch errors
    console.error("[create-midtrans-transaction] Gagal terhubung ke Midtrans:", err);
    const errBody: ErrorResponse = { error: "Gagal terhubung ke layanan pembayaran. Coba lagi." };
    return new Response(JSON.stringify(errBody), {
      status: 502,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  clearTimeout(timeoutId);

  // 5. Handle error HTTP 4xx/5xx dari Midtrans — teruskan kode HTTP yang sama ke Flutter
  // Requirements: 1.4
  if (!snapRes.ok) {
    let midtransErrorMessage = `Midtrans error: HTTP ${snapRes.status}`;
    try {
      const midtransErrorBody = await snapRes.json() as Record<string, unknown>;
      if (
        midtransErrorBody.error_messages &&
        Array.isArray(midtransErrorBody.error_messages) &&
        midtransErrorBody.error_messages.length > 0
      ) {
        midtransErrorMessage = (midtransErrorBody.error_messages as string[]).join("; ");
      } else if (typeof midtransErrorBody.message === "string") {
        midtransErrorMessage = midtransErrorBody.message;
      }
    } catch {
      // Gunakan pesan default jika body tidak bisa di-parse
    }
    console.error(`[create-midtrans-transaction] Midtrans API returned ${snapRes.status}: ${midtransErrorMessage}`);
    const errBody: ErrorResponse = { error: midtransErrorMessage };
    return new Response(JSON.stringify(errBody), {
      status: snapRes.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // 6. Return { snap_token, redirect_url } dengan HTTP 200 jika sukses
  // Requirements: 1.3
  let snapData: { token: string; redirect_url: string };
  try {
    snapData = await snapRes.json() as { token: string; redirect_url: string };
  } catch {
    console.error("[create-midtrans-transaction] Gagal mem-parse response Midtrans");
    const errBody: ErrorResponse = { error: "Respons tidak valid dari layanan pembayaran." };
    return new Response(JSON.stringify(errBody), {
      status: 502,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  console.log(`[create-midtrans-transaction] Berhasil mendapatkan snap_token untuk order_id: ${body.order_id}`);

  const successBody: CreateTransactionResponse = {
    snap_token: snapData.token,
    redirect_url: snapData.redirect_url,
  };
  return new Response(JSON.stringify(successBody), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
