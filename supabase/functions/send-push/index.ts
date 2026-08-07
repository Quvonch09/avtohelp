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
    const { user_id, title, body, data } = await req.json();

    if (!user_id || !title || !body) {
      return new Response(
        JSON.stringify({ error: "user_id, title va body maydonlari shart." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Foydalanuvchining fcm_token ini olish
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("fcm_token")
      .eq("id", user_id)
      .single();

    if (profileError || !profile || !profile.fcm_token) {
      // Agar foydalanuvchida fcm_token bo'lmasa, bildirishnomalar logiga saqlaymiz va tugatamiz
      await supabase.from("notifications").insert({
        user_id,
        title,
        body,
        data,
      });

      return new Response(
        JSON.stringify({ message: "Foydalanuvchining FCM tokeni topilmadi, xabar faqat ichki logga saqlandi." }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const fcmToken = profile.fcm_token;

    // 2. FCM xabarini yuborish
    const fcmServiceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT");
    let sent = false;

    if (fcmServiceAccountJson) {
      try {
        const serviceAccount = JSON.parse(fcmServiceAccountJson);
        const projectId = serviceAccount.project_id;

        // Eslatma: Google Auth orqali token olish uchun Edge funksiyalarda Deno kutubxonalari kerak.
        // Bu erda Google Auth token olish va FCM v1 API ga so'rov yuborish sxemasi keltirilgan.
        // Haqiqiy deployda 'google-auth-library' yoki shunga o'xshash import ishlatiladi.
        const accessToken = await getGoogleAccessToken(serviceAccount);

        const fcmResponse = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${accessToken}`,
            },
            body: JSON.stringify({
              message: {
                token: fcmToken,
                notification: {
                  title,
                  body,
                },
                data: data ? Object.fromEntries(
                  Object.entries(data).map(([k, v]) => [k, typeof v === "object" ? JSON.stringify(v) : String(v)])
                ) : undefined,
              },
            }),
          }
        );

        const fcmResult = await fcmResponse.json();
        if (fcmResponse.status === 200) {
          sent = true;
        } else {
          console.error("FCM API error:", fcmResult);
        }
      } catch (err) {
        console.error("FCM yuborishda OAuth xatolik:", err);
      }
    } else {
      console.warn("FCM_SERVICE_ACCOUNT muhit o'zgaruvchisi topilmadi. FCM yuborish o'tkazib yuborildi (Faqat logga saqlanadi).");
    }

    // 3. Yuborilgan xabarni db dagi bildirishnomalar logiga saqlash
    await supabase.from("notifications").insert({
      user_id,
      title,
      body,
      data,
      is_read: false,
    });

    return new Response(
      JSON.stringify({ message: "Bildirishnoma qayta ishlandi.", sent }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Noma'lum xatolik" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

// Google Service Account yordamida OAuth2 token olish funksiyasi (JWT sign)
async function getGoogleAccessToken(serviceAccount: any): Promise<string> {
  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + 3600;

  // JWT claim to'plami
  const header = { alg: "RS256", typ: "JWT" };
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: exp,
    iat: iat,
  };

  // JWT ni kodlash
  const encodedHeader = btoa(JSON.stringify(header));
  const encodedClaimSet = btoa(JSON.stringify(claimSet));
  const signatureInput = `${encodedHeader}.${encodedClaimSet}`;

  // Kriptografik imzolash
  const privateKeyPem = serviceAccount.private_key;
  const privateKey = await importPrivateKey(privateKeyPem);
  
  const signatureBuffer = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    new TextEncoder().encode(signatureInput)
  );

  const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signatureBuffer)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  const jwt = `${signatureInput}.${encodedSignature}`;

  // Token olish uchun so'rov yuborish
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const data = await res.json();
  return data.access_token;
}

// PEM formatdagi Private Key ni Deno crypto.subtle formatiga o'tkazish
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
  const pemContents = pem
    .replace(pemHeader, "")
    .replace(pemFooter, "")
    .replace(/\s/g, "");

  const binaryDerString = atob(pemContents);
  const binaryDer = new Uint8Array(binaryDerString.length);
  for (let i = 0; i < binaryDerString.length; i++) {
    binaryDer[i] = binaryDerString.charCodeAt(i);
  }

  return await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
}
