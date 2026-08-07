import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { phone, code } = await req.json();

    if (!phone || !code) {
      return new Response(
        JSON.stringify({ error: "Telefon raqami va OTP kod kiritilishi shart." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);
    const supabaseAnon = createClient(supabaseUrl, supabaseAnonKey);

    // 1. OTP kodni bazadan tekshirish
    const { data: otpData, error: otpError } = await supabaseAdmin
      .from("otp_codes")
      .select("*")
      .eq("phone", phone)
      .eq("code", code)
      .single();

    if (otpError || !otpData) {
      return new Response(
        JSON.stringify({ error: "Noto'g'ri yoki eskirgan OTP kod." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Kod eskirganligini tekshirish
    const now = new Date();
    const expiresAt = new Date(otpData.expires_at);
    if (now > expiresAt) {
      return new Response(
        JSON.stringify({ error: "OTP kod muddati tugagan." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Ishlatilgan kodni o'chirish
    await supabaseAdmin.from("otp_codes").delete().eq("phone", phone);

    // 3. Maxfiy parolni generatsiya qilish (Telefon raqam + JWT_SECRET asosida)
    const jwtSecret = Deno.env.get("JWT_SECRET") ?? "fallback-secret-for-password-generation";
    const passwordData = new TextEncoder().encode(phone + jwtSecret);
    const hashBuffer = await crypto.subtle.digest("SHA-256", passwordData);
    const passwordHash = Array.from(new Uint8Array(hashBuffer))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");

    // 4. Foydalanuvchi auth.users da borligini tekshirish (Virtual Email yordamida)
    const email = `${phone.replace("+", "")}@masterhelp.uz`;
    const { data: usersList, error: listError } = await supabaseAdmin.auth.admin.listUsers();
    if (listError) {
      throw new Error(`Foydalanuvchilarni tekshirishda xatolik: ${listError.message}`);
    }

    const existingUser = usersList.users.find((u) => u.email === email);
    let userId: string;

    if (!existingUser) {
      // Yangi user yaratish
      const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
        email: email,
        password: passwordHash,
        email_confirm: true,
      });

      if (createError) {
        throw new Error(`Yangi foydalanuvchi yaratishda xatolik: ${createError.message}`);
      }
      userId = newUser.user.id;
    } else {
      userId = existingUser.id;
      // Parolni har ehtimolga qarshi yangilab qo'yamiz
      await supabaseAdmin.auth.admin.updateUserById(userId, {
        password: passwordHash,
        email_confirm: true,
      });
    }

    // 5. Foydalanuvchini tizimga kiritish (Session olish)
    const { data: sessionData, error: signInError } = await supabaseAnon.auth.signInWithPassword({
      email: email,
      password: passwordHash,
    });

    if (signInError) {
      throw new Error(`Tizimga kirishda xatolik: ${signInError.message}`);
    }

    // 6. Profil mavjudligini tekshirish
    const { data: profile, error: profileError } = await supabaseAdmin
      .from("profiles")
      .select("*")
      .eq("id", userId)
      .single();

    let hasProfile = false;
    let userRole = null;

    if (profile) {
      hasProfile = true;
      userRole = profile.role;
    }

    return new Response(
      JSON.stringify({
        session: sessionData.session,
        user: sessionData.user,
        has_profile: hasProfile,
        role: userRole,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Noma'lum xatolik yuz berdi" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
