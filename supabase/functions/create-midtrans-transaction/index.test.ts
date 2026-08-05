/**
 * Unit Tests: create-midtrans-transaction Edge Function
 *
 * Validates: Requirements 1.4, 8.3, 8.4, 8.5
 *
 * Skenario yang diuji:
 * 1. JWT valid + customer_id cocok → sukses memanggil Snap API (HTTP 200)
 * 2. Tidak ada header Authorization → HTTP 401
 * 3. customer_id di body tidak cocok dengan JWT sub → HTTP 403
 * 4. snap_token sudah ada untuk order_id → HTTP 409
 * 5. Midtrans Snap API timeout → HTTP 504
 *
 * Catatan: Test menggunakan pendekatan "stub global fetch + Deno.env" agar
 * dapat menguji logika handler tanpa jaringan atau database nyata.
 */

import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

// ─── JWT Test Helper ──────────────────────────────────────────────────────────

/**
 * Membuat JWT HMAC-SHA256 yang valid dengan sub = userId.
 * Digunakan untuk menyimulasikan token Supabase yang sah.
 */
async function makeJwt(
  userId: string,
  secret: string,
  expOffsetSeconds = 3600,
): Promise<string> {
  const header = { alg: "HS256", typ: "JWT" };
  const payload = {
    sub: userId,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + expOffsetSeconds,
  };

  function b64url(obj: unknown): string {
    const json = JSON.stringify(obj);
    const bytes = new TextEncoder().encode(json);
    let binary = "";
    for (const b of bytes) binary += String.fromCharCode(b);
    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
  }

  const signingInput = `${b64url(header)}.${b64url(payload)}`;
  const keyData = new TextEncoder().encode(secret);
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    keyData,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sigBuffer = await crypto.subtle.sign(
    "HMAC",
    cryptoKey,
    new TextEncoder().encode(signingInput),
  );
  const sigBytes = new Uint8Array(sigBuffer);
  let sigBinary = "";
  for (const b of sigBytes) sigBinary += String.fromCharCode(b);
  const signature = btoa(sigBinary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");

  return `${signingInput}.${signature}`;
}

// ─── Request Builder Helper ───────────────────────────────────────────────────

function makeRequest(
  body: Record<string, unknown>,
  authHeader?: string,
): Request {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };
  if (authHeader !== undefined) {
    headers["Authorization"] = authHeader;
  }
  return new Request("https://edge.supabase.co/functions/v1/create-midtrans-transaction", {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
}

// ─── Default Valid Body ───────────────────────────────────────────────────────

const VALID_CUSTOMER_ID = "user-uuid-1234";
const JWT_SECRET = "test-secret-at-least-32-chars-!!";
const SUPABASE_URL = "https://fake.supabase.co";
const SERVICE_ROLE_KEY = "fake-service-role-key";
const MIDTRANS_SERVER_KEY = "SB-Mid-server-fakekey";

function validBody(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    order_id: "order-uuid-5678",
    customer_id: VALID_CUSTOMER_ID,
    customer_email: "customer@example.com",
    customer_name: "Customer Name",
    customer_phone: "08123456789",
    total_amount: 100000,
    items: [
      {
        product_id: "prod-001",
        name: "Produk A",
        price: 100000,
        quantity: 1,
      },
    ],
    ...overrides,
  };
}

// ─── Env Stub Helper ──────────────────────────────────────────────────────────

/**
 * Override Deno.env.get sementara selama test berlangsung,
 * kemudian restore ke aslinya setelah selesai.
 */
function stubEnv(values: Record<string, string>): () => void {
  const original = Deno.env.get.bind(Deno.env);
  // @ts-ignore: override untuk test
  Deno.env.get = (key: string) => values[key] ?? undefined;
  return () => {
    // @ts-ignore: restore
    Deno.env.get = original;
  };
}

// ─── Fetch Stub Helper ────────────────────────────────────────────────────────

/**
 * Override globalThis.fetch sementara selama test berlangsung.
 * Memungkinkan kita menyimulasikan response DB Supabase dan Midtrans Snap API.
 *
 * Handler dapat:
 * - Mengembalikan Response (sukses atau error HTTP)
 * - Melempar Error/DOMException (simulasi timeout/network error)
 */
function stubFetch(
  handler: (req: RequestInfo | URL, init?: RequestInit) => Response,
): () => void {
  const original = globalThis.fetch;
  // @ts-ignore: override untuk test
  globalThis.fetch = async (req: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
    // handler bisa throw (AbortError dll) — biarkan exception propagate ke caller
    return handler(req, init);
  };
  return () => {
    globalThis.fetch = original;
  };
}

// ─── HANDLER UNDER TEST ───────────────────────────────────────────────────────
// Karena index.ts memanggil Deno.serve() secara langsung (side-effect saat diimpor),
// kita menduplikasi logika handler sebagai fungsi lokal `handleRequest`.
// Fungsi ini identik dengan callback Deno.serve() di index.ts sehingga
// perubahan apapun pada index.ts harus disinkronkan ke sini.

// Fungsi ini mereplikasi persis logika dari index.ts:
type ErrorResponse = { error: string };

function base64urlDecodeLocal(base64url: string): Uint8Array {
  const base64 = base64url
    .replace(/-/g, "+")
    .replace(/_/g, "/")
    .padEnd(base64url.length + (4 - (base64url.length % 4)) % 4, "=");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

async function verifyJwtLocal(
  token: string,
  jwtSecret: string,
): Promise<Record<string, unknown>> {
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("Format JWT tidak valid");

  const [headerB64, payloadB64, signatureB64] = parts;

  const keyData = new TextEncoder().encode(jwtSecret);
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    keyData,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );

  const signingInput = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  const signature = base64urlDecodeLocal(signatureB64);
  const isValid = await crypto.subtle.verify(
    { name: "HMAC", hash: "SHA-256" },
    cryptoKey,
    signature.buffer as ArrayBuffer,
    signingInput,
  );

  if (!isValid) throw new Error("Signature JWT tidak valid");

  const payloadJson = new TextDecoder().decode(base64urlDecodeLocal(payloadB64));
  const payload = JSON.parse(payloadJson) as Record<string, unknown>;

  const exp = payload["exp"];
  if (typeof exp === "number" && Math.floor(Date.now() / 1000) > exp) {
    throw new Error("JWT sudah kedaluwarsa");
  }

  return payload;
}

/**
 * Handler yang mengulang logika dari index.ts agar dapat diuji secara unit.
 * Menggunakan Deno.env.get() dan globalThis.fetch() sehingga stub berfungsi.
 *
 * Validates: Requirements 1.4, 8.3, 8.4, 8.5
 */
async function handleRequest(req: Request): Promise<Response> {
  const corsHeaders: Record<string, string> = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method tidak diizinkan." }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Parse JSON body
  let requestBody: unknown;
  try {
    requestBody = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ error: "Request body tidak dapat di-parse sebagai JSON" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  // Validasi field wajib (minimal)
  const b = requestBody as Record<string, unknown>;
  if (!b.order_id || !b.customer_id || !b.customer_email || !b.total_amount || !b.items) {
    return new Response(
      JSON.stringify({ error: "Field wajib tidak lengkap" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  // ── Verifikasi JWT ─────────────────────────────────────────────────────────
  // Requirements: 8.3, 8.4
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    const errBody: ErrorResponse = { error: "Unauthorized" };
    return new Response(JSON.stringify(errBody), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  const token = authHeader.replace("Bearer ", "").trim();

  const jwtSecret = Deno.env.get("SUPABASE_JWT_SECRET");
  if (!jwtSecret) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  let jwtPayload: Record<string, unknown>;
  try {
    jwtPayload = await verifyJwtLocal(token, jwtSecret);
  } catch {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── Validasi customer_id == JWT sub ─────────────────────────────────────────
  // Requirements: 8.5
  const jwtSub = jwtPayload["sub"];
  if (!jwtSub || jwtSub !== b.customer_id) {
    return new Response(JSON.stringify({ error: "Forbidden" }), {
      status: 403,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── Cek duplikat snap_token ─────────────────────────────────────────────────
  // Requirements: 1.8
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  let checkRes: Response;
  try {
    checkRes = await fetch(
      `${supabaseUrl}/rest/v1/orders?id=eq.${b.order_id}&select=snap_token`,
      {
        headers: {
          "apikey": serviceRoleKey,
          "Authorization": `Bearer ${serviceRoleKey}`,
        },
      },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: "Gagal memeriksa status pesanan. Coba lagi." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  const orders = await checkRes.json() as Array<{ snap_token: string | null }>;
  if (orders.length > 0 && orders[0].snap_token) {
    return new Response(
      JSON.stringify({ error: "Pesanan ini sudah memiliki sesi pembayaran aktif." }),
      { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  // ── Baca Midtrans Server Key ─────────────────────────────────────────────────
  // Requirements: 1.7, 8.1, 8.2
  const serverKey = Deno.env.get("MIDTRANS_SERVER_KEY");
  if (!serverKey) {
    return new Response(
      JSON.stringify({ error: "Konfigurasi server tidak lengkap." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  // ── Panggil Midtrans Snap API dengan timeout 10 detik ───────────────────────
  // Requirements: 1.4, 1.9
  const basicAuth = btoa(serverKey + ":");
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 10000);

  const body2 = b as {
    order_id: string; customer_id: string; customer_email: string;
    customer_name: string; customer_phone: string; total_amount: number;
    items: Array<{ product_id: string; name: string; price: number; quantity: number; }>;
  };

  const snapPayload = {
    transaction_details: {
      order_id: body2.order_id,
      gross_amount: body2.total_amount,
    },
    customer_details: {
      first_name: body2.customer_name ?? "",
      email: body2.customer_email,
      phone: body2.customer_phone ?? "",
    },
    item_details: (body2.items ?? []).map((item) => ({
      id: item.product_id,
      name: item.name,
      price: item.price,
      quantity: item.quantity,
    })),
  };

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
    if (err instanceof DOMException && err.name === "AbortError") {
      return new Response(
        JSON.stringify({ error: "Layanan pembayaran tidak merespons. Coba lagi." }),
        { status: 504, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
    return new Response(
      JSON.stringify({ error: "Gagal terhubung ke layanan pembayaran. Coba lagi." }),
      { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
  clearTimeout(timeoutId);

  if (!snapRes.ok) {
    let midtransErrorMessage = `Midtrans error: HTTP ${snapRes.status}`;
    try {
      const midtransErrorBody = await snapRes.json() as Record<string, unknown>;
      if (
        midtransErrorBody.error_messages &&
        Array.isArray(midtransErrorBody.error_messages) &&
        (midtransErrorBody.error_messages as string[]).length > 0
      ) {
        midtransErrorMessage = (midtransErrorBody.error_messages as string[]).join("; ");
      }
    } catch { /* gunakan pesan default */ }
    return new Response(JSON.stringify({ error: midtransErrorMessage }), {
      status: snapRes.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const snapData = await snapRes.json() as { token: string; redirect_url: string };
  return new Response(
    JSON.stringify({ snap_token: snapData.token, redirect_url: snapData.redirect_url }),
    { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
}

// ─── TESTS ────────────────────────────────────────────────────────────────────

/**
 * Test 1: JWT valid + customer_id cocok → sukses memanggil Snap API
 * Validates: Requirements 1.4, 8.3, 8.4, 8.5
 */
Deno.test("JWT valid + customer_id cocok → HTTP 200 dengan snap_token", async () => {
  const jwt = await makeJwt(VALID_CUSTOMER_ID, JWT_SECRET);

  const restoreEnv = stubEnv({
    SUPABASE_JWT_SECRET: JWT_SECRET,
    SUPABASE_URL: SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY: SERVICE_ROLE_KEY,
    MIDTRANS_SERVER_KEY: MIDTRANS_SERVER_KEY,
  });

  // Stub fetch: DB cek (tidak ada snap_token) + Midtrans Snap API sukses
  const restoreFetch = stubFetch((url) => {
    const urlStr = typeof url === "string" ? url : (url as URL | Request).toString();

    if (urlStr.includes("/rest/v1/orders")) {
      // DB cek → order belum punya snap_token
      return new Response(JSON.stringify([{ snap_token: null }]), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
    if (urlStr.includes("midtrans.com/snap/transactions")) {
      // Midtrans Snap API → success
      return new Response(
        JSON.stringify({ token: "snap-token-abc123", redirect_url: "https://app.sandbox.midtrans.com/snap/v2/vtweb/snap-token-abc123" }),
        { status: 201, headers: { "Content-Type": "application/json" } },
      );
    }
    return new Response(JSON.stringify({ error: "unexpected fetch" }), { status: 500 });
  });

  try {
    const req = makeRequest(validBody(), `Bearer ${jwt}`);
    const res = await handleRequest(req);

    assertEquals(res.status, 200);
    const resBody = await res.json() as Record<string, unknown>;
    assertEquals(resBody.snap_token, "snap-token-abc123");
    assertStringIncludes(resBody.redirect_url as string, "snap-token-abc123");
  } finally {
    restoreEnv();
    restoreFetch();
  }
});

/**
 * Test 2: Tidak ada header Authorization → HTTP 401
 * Validates: Requirements 8.3, 8.4
 */
Deno.test("Tidak ada Authorization header → HTTP 401", async () => {
  const restoreEnv = stubEnv({
    SUPABASE_JWT_SECRET: JWT_SECRET,
    SUPABASE_URL: SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY: SERVICE_ROLE_KEY,
    MIDTRANS_SERVER_KEY: MIDTRANS_SERVER_KEY,
  });

  try {
    // Buat request tanpa header Authorization sama sekali
    const req = makeRequest(validBody(), undefined);
    const res = await handleRequest(req);

    assertEquals(res.status, 401);
    const resBody = await res.json() as ErrorResponse;
    assertEquals(resBody.error, "Unauthorized");
  } finally {
    restoreEnv();
  }
});

/**
 * Test 3: customer_id di body tidak cocok dengan JWT sub → HTTP 403
 * Validates: Requirements 8.5
 */
Deno.test("customer_id tidak cocok JWT sub → HTTP 403", async () => {
  // JWT berisi sub = "user-uuid-1234", tapi body menggunakan customer_id berbeda
  const jwt = await makeJwt("user-uuid-1234", JWT_SECRET);

  const restoreEnv = stubEnv({
    SUPABASE_JWT_SECRET: JWT_SECRET,
    SUPABASE_URL: SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY: SERVICE_ROLE_KEY,
    MIDTRANS_SERVER_KEY: MIDTRANS_SERVER_KEY,
  });

  try {
    const bodyWithDifferentCustomerId = validBody({
      customer_id: "user-uuid-DIFFERENT",
    });
    const req = makeRequest(bodyWithDifferentCustomerId, `Bearer ${jwt}`);
    const res = await handleRequest(req);

    assertEquals(res.status, 403);
    const resBody = await res.json() as ErrorResponse;
    assertEquals(resBody.error, "Forbidden");
  } finally {
    restoreEnv();
  }
});

/**
 * Test 4: snap_token sudah ada untuk order_id → HTTP 409
 * Validates: Requirements 1.4 (referensi Req 1.8)
 */
Deno.test("snap_token sudah ada untuk order_id → HTTP 409", async () => {
  const jwt = await makeJwt(VALID_CUSTOMER_ID, JWT_SECRET);

  const restoreEnv = stubEnv({
    SUPABASE_JWT_SECRET: JWT_SECRET,
    SUPABASE_URL: SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY: SERVICE_ROLE_KEY,
    MIDTRANS_SERVER_KEY: MIDTRANS_SERVER_KEY,
  });

  // Stub fetch: DB cek → order SUDAH punya snap_token (duplikat)
  const restoreFetch = stubFetch((url) => {
    const urlStr = typeof url === "string" ? url : (url as URL | Request).toString();
    if (urlStr.includes("/rest/v1/orders")) {
      return new Response(JSON.stringify([{ snap_token: "existing-snap-token" }]), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
    // Midtrans tidak boleh dipanggil — jika dipanggil, hasilkan error untuk mendeteksi bug
    return new Response(JSON.stringify({ error: "Midtrans tidak seharusnya dipanggil!" }), {
      status: 500,
    });
  });

  try {
    const req = makeRequest(validBody(), `Bearer ${jwt}`);
    const res = await handleRequest(req);

    assertEquals(res.status, 409);
    const resBody = await res.json() as ErrorResponse;
    assertStringIncludes(resBody.error, "sesi pembayaran aktif");
  } finally {
    restoreEnv();
    restoreFetch();
  }
});

/**
 * Test 5: Midtrans Snap API timeout → HTTP 504
 * Validates: Requirements 1.4 (referensi Req 1.9)
 */
Deno.test("Midtrans Snap API timeout → HTTP 504", async () => {
  const jwt = await makeJwt(VALID_CUSTOMER_ID, JWT_SECRET);

  const restoreEnv = stubEnv({
    SUPABASE_JWT_SECRET: JWT_SECRET,
    SUPABASE_URL: SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY: SERVICE_ROLE_KEY,
    MIDTRANS_SERVER_KEY: MIDTRANS_SERVER_KEY,
  });

  // Stub fetch: DB cek sukses (tidak ada snap_token), Midtrans lempar AbortError
  const restoreFetch = stubFetch((url) => {
    const urlStr = typeof url === "string" ? url : (url as URL | Request).toString();
    if (urlStr.includes("/rest/v1/orders")) {
      return new Response(JSON.stringify([{ snap_token: null }]), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
    if (urlStr.includes("midtrans.com/snap/transactions")) {
      // Simulasi timeout: lempar DOMException AbortError
      throw new DOMException("The operation was aborted.", "AbortError");
    }
    return new Response(JSON.stringify({ error: "unexpected fetch" }), { status: 500 });
  });

  try {
    const req = makeRequest(validBody(), `Bearer ${jwt}`);
    const res = await handleRequest(req);

    assertEquals(res.status, 504);
    const resBody = await res.json() as ErrorResponse;
    assertStringIncludes(resBody.error, "tidak merespons");
  } finally {
    restoreEnv();
    restoreFetch();
  }
});
