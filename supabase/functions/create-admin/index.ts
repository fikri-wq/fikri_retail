import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ── 1. Verifikasi pemanggil adalah admin ──────────────────────────────
    // Buat client biasa untuk verifikasi JWT si pemanggil
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Client untuk cek identitas pemanggil (pakai JWT dari header)
    const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user: callerUser },
    } = await callerClient.auth.getUser();

    if (!callerUser) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Cek apakah si pemanggil adalah admin
    const { data: callerProfile } = await callerClient
      .from("profiles")
      .select("role")
      .eq("id", callerUser.id)
      .single();

    if (!callerProfile || callerProfile.role !== "admin") {
      return new Response(
        JSON.stringify({ error: "Forbidden: hanya admin yang bisa membuat admin baru." }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // ── 2. Baca body request ──────────────────────────────────────────────
    const { email, password, full_name } = await req.json();

    if (!email || !password || !full_name) {
      return new Response(
        JSON.stringify({ error: "Field email, password, dan full_name wajib diisi." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // ── 3. Buat user baru pakai service_role (bypass RLS) ─────────────────
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: newUser, error: signUpError } =
      await adminClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true, // Langsung aktif, tidak perlu verifikasi email
        user_metadata: { full_name },
      });

    if (signUpError) {
      let msg = signUpError.message;
      if (msg.includes("already registered") || msg.includes("already been registered")) {
        msg = "Email sudah terdaftar. Gunakan email lain.";
      }
      return new Response(JSON.stringify({ error: msg }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const newUserId = newUser.user?.id;
    if (!newUserId) {
      return new Response(
        JSON.stringify({ error: "Gagal mendapatkan ID user baru." }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // ── 4. Upsert profile dengan role admin (pakai service_role, bypass RLS) ──
    const { error: profileError } = await adminClient.from("profiles").upsert({
      id: newUserId,
      full_name,
      role: "admin",
    });

    if (profileError) {
      // Rollback: hapus user yang baru dibuat jika profile gagal
      await adminClient.auth.admin.deleteUser(newUserId);
      return new Response(
        JSON.stringify({ error: `Gagal set role admin: ${profileError.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // ── 5. Sukses ─────────────────────────────────────────────────────────
    return new Response(
      JSON.stringify({
        success: true,
        user_id: newUserId,
        message: `Admin "${full_name}" berhasil dibuat.`,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
