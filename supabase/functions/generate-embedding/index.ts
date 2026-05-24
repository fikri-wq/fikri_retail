import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

// Deklarasi global agar VS Code tidak memunculkan garis merah
declare const Supabase: any;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// 1. GUNAKAN AI NATIVE DARI SUPABASE (Bukan dari library npm luar)
// Model 'gte-small' ini otomatis menghasilkan array 384 dimensi
const session = new Supabase.ai.Session('gte-small');

serve(async (req: Request) => {
  // Handle CORS dari Vercel
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = await req.json();
    const input = body.input;

    if (!input) {
      throw new Error("Teks input tidak ditemukan.");
    }

    // 2. Jalankan AI Engine bawaan Supabase secara langsung
    const embedding = await session.run(input, { mean_pool: true, normalize: true });

    // 3. Kembalikan array vektor ke Flutter Web Anda
    return new Response(JSON.stringify({ embedding }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
})