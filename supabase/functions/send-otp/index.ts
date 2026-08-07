import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // CORS handles preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { phone } = await req.json();

    if (!phone || !phone.startsWith("+998")) {
      return new Response(
        JSON.stringify({ error: "Noto'g'ri telefon raqam format. (+998XXXXXXXXX formatida bo'lishi kerak)" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4 xonali kod generatsiya qilish
    const otpCode = Math.floor(1000 + Math.random() * 9000).toString();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString(); // 5 daqiqadan keyin eskiradi

    // Supabase DB ulanish (Service Role - RLS ni chetlab o'tish uchun)
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Kodni bazaga saqlash (Upsert - agar oldin yuborilgan bo'lsa yangilaydi)
    const { error: dbError } = await supabase
      .from("otp_codes")
      .upsert({ phone, code: otpCode, expires_at: expiresAt });

    if (dbError) {
      throw new Error(`Kodni bazaga saqlashda xatolik: ${dbError.message}`);
    }

    // Eskiz.uz orqali SMS yuborish
    const eskizEmail = Deno.env.get("ESKIZ_EMAIL");
    const eskizPassword = Deno.env.get("ESKIZ_PASSWORD");
    const eskizToken = Deno.env.get("ESKIZ_TOKEN"); // Agar token tayyor bo'lsa

    let token = eskizToken;

    // Agar token bo'lmasa, Eskiz API dan login orqali yangi token olish
    if (!token && eskizEmail && eskizPassword) {
      const loginRes = await fetch("https://yolo.eskiz.uz/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: eskizEmail, password: eskizPassword }),
      });
      const loginData = await loginRes.json();
      token = loginData.data?.token;
    }

    if (token) {
      // Eskiz API orqali SMS yuborish
      const cleanPhone = phone.replace("+", ""); // Eskiz plyussiz telefon qabul qiladi
      const smsText = `Master Help tasdiqlash kodi: ${otpCode}. Kodni hech kimga bermang.`;

      const smsRes = await fetch("https://yolo.eskiz.uz/api/message/sms/send", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${token}`
        },
        body: JSON.stringify({
          mobile_phone: cleanPhone,
          message: smsText,
          from: "4546", // Eskiz default yoki tasdiqlangan sender nomi
          callback_url: null
        }),
      });

      const smsData = await smsRes.json();
      if (smsRes.status !== 200) {
        console.error("Eskiz SMS yuborishda xatolik:", smsData);
      }
    } else {
      console.warn("Eskiz API token topilmadi. SMS yuborilmadi. Test rejimi: OTP Kod =", otpCode);
    }

    return new Response(
      JSON.stringify({ message: "Tasdiqlash kodi yuborildi.", test_mode: !token ? { code: otpCode } : undefined }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Noma'lum xatolik yuz berdi" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
