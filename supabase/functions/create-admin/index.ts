import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // ── 1. Verifikasi pemanggil adalah admin ──────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user: callerUser } } = await callerClient.auth.getUser();
    if (!callerUser) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: callerProfile } = await callerClient
      .from("profiles")
      .select("role")
      .eq("id", callerUser.id)
      .single();

    if (!callerProfile || callerProfile.role !== "admin") {
      return new Response(
        JSON.stringify({ error: "Forbidden: hanya admin yang bisa membuat admin baru." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── 2. Baca body ──────────────────────────────────────────────────────
    const { email, password, full_name } = await req.json();
    if (!email || !password || !full_name) {
      return new Response(
        JSON.stringify({ error: "Field email, password, dan full_name wajib diisi." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── 3. Buat user baru pakai Admin API ─────────────────────────────────
    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: newUser, error: signUpError } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name },
    });

    if (signUpError) {
      let msg = signUpError.message;
      if (msg.includes("already registered") || msg.includes("User already registered")) {
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
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── 4. Tunggu trigger handle_new_user selesai ─────────────────────────
    await new Promise((resolve) => setTimeout(resolve, 1500));

    // ── 5. Set role admin via RPC function SECURITY DEFINER ───────────────
    // Function 'set_user_role_admin' di database berjalan sebagai superuser
    // sehingga 100% bypass RLS — tidak perlu policy tambahan apapun.
    // PASTIKAN sudah menjalankan SQL di file supabase_set_admin_role.sql !
    const { error: rpcError } = await adminClient.rpc("set_user_role_admin", {
      target_user_id: newUserId,
      target_full_name: full_name,
    });

    if (rpcError) {
      // RPC gagal — rollback dengan hapus user
      await adminClient.auth.admin.deleteUser(newUserId);
      return new Response(
        JSON.stringify({
          error: `Gagal set role: ${rpcError.message}. Pastikan SQL function set_user_role_admin sudah dibuat di Supabase.`,
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── 6. Sukses ─────────────────────────────────────────────────────────
    return new Response(
      JSON.stringify({
        success: true,
        user_id: newUserId,
        message: `Admin "${full_name}" berhasil dibuat.`,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
