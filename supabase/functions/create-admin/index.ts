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

    // ── 3. Buat user baru pakai Admin API (service_role) ──────────────────
    // auth.admin.createUser() TIDAK memicu trigger handle_new_user
    // jadi kita handle insert profiles manual di sini
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

    // ── 4. Insert/update profiles langsung via SQL (bypass RLS sepenuhnya) ─
    // Menggunakan rpc dengan fungsi SECURITY DEFINER yang akan kita buat,
    // ATAU pakai Postgres REST endpoint dengan service_role yang bypass RLS.
    //
    // Catatan: createClient dengan serviceRoleKey + schema postgres
    // otomatis bypass RLS untuk operasi DML.
    // Jika masih gagal, berarti ada policy EXPLICIT DENY yang memblok INSERT.
    // Solusi: jalankan SQL di bawah ini di Supabase SQL Editor:
    //   ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
    // atau tambah policy: USING (true) WITH CHECK (true) untuk service_role.

    // Coba insert dulu (jika trigger belum jalan)
    const { error: insertError } = await adminClient
      .from("profiles")
      .insert({ id: newUserId, full_name, role: "admin" });

    if (insertError) {
      // Jika insert gagal karena duplicate (trigger sudah jalan duluan), coba update
      if (insertError.code === "23505") {
        // Duplicate key — trigger sudah insert dengan role='customer', update saja
        const { error: updateError } = await adminClient
          .from("profiles")
          .update({ full_name, role: "admin" })
          .eq("id", newUserId);

        if (updateError) {
          await adminClient.auth.admin.deleteUser(newUserId);
          return new Response(
            JSON.stringify({ error: `Gagal set role admin: ${updateError.message}` }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      } else {
        // Error lain
        await adminClient.auth.admin.deleteUser(newUserId);
        return new Response(
          JSON.stringify({ error: `Gagal buat profil: ${insertError.message}` }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // ── 5. Sukses ─────────────────────────────────────────────────────────
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
