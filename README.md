# Master Help — Avto-Servis Marketplace (Texnik Hujjatlar & Ishga tushirish qo'llanmasi)

Ushbu loyiha yo'lda qolgan haydovchilarni eng yaqin (3km radiusdagi) tasdiqlangan va online bo'lgan ustalar bilan bog'laydigan avto-servis marketplace hisoblanadi. 

Loyiha bitta umumiy Flutter kod bazasi orqali iOS va Android platformalarida ishlaydi. Tezlik va sifatni ta'minlash maqsadida backend va ma'lumotlar bazasi sifatida **Supabase (PostgreSQL + PostGIS)** tanlangan. Admin panel esa **Next.js 14** da ishlab chiqiladi.

---

## 🚀 Texnologiyalar Stacki

*   **Mobil ilova:** Flutter 3.22 (Dart)
    *   *Kutubxonalar:* `supabase_flutter`, `google_maps_flutter`, `geolocator`, `firebase_messaging`, `flutter_bloc`.
*   **Backend & DB:** Supabase (PostgreSQL 15 + PostGIS)
    *   *Xizmatlar:* Supabase Auth, Storage (Logotiplar/Avatarlar), Realtime websocket, Edge Functions (TypeScript/Deno).
*   **Admin Panel:** Next.js 14 + Tailwind CSS + shadcn/ui.
*   **SMS Provayder:** Eskiz.uz API.
*   **Push Xizmati:** Firebase Cloud Messaging (FCM v1).

---

## 📂 Loyiha Tuzilishi

Loyiha 3 ta asosiy qismdan iborat bo'ladi:
1.  `/supabase` — Ma'lumotlar bazasi migratsiyalari va Edge funksiyalar kodlari.
2.  `/mobile` — Flutter mobil ilovasi (iOS & Android).
3.  `/admin` — Next.js admin boshqaruv paneli.

---

## 🛠️ Loyihani Ishga Tushirish va O'rnatish

### 1. Supabase (Backend va Ma'lumotlar Bazasi)

Loyihani mahalliy (local) yoki Supabase bulutli servisida ishga tushirish mumkin.

#### Mahalliy ishga tushirish (Supabase CLI):
Mahalliy kompyuterda Docker o'rnatilgan bo'lishi kerak.

1.  Supabase CLI ni o'rnating:
    ```bash
    npm install -g supabase
    ```
2.  Loyihani initsializatsiya qiling:
    ```bash
    supabase init
    ```
3.  Mahalliy Supabase konteynerlarini ishga tushiring:
    ```bash
    supabase start
    ```
    Bu buyruq sizga mahalliy `Studio URL`, `API URL`, `anon key` va `service role key`larni beradi.

4.  Biz tayyorlagan migratsiya faylini qo'llang (Baza sxemasi, indekslar, triggerlar va seed ma'lumotlari yuklanadi):
    ```bash
    supabase db reset
    ```
    *(Migratsiya fayli: [20260804000000_init.sql](file:///c:/Users/Bobomurodov/Desktop/avtohelp/supabase/migrations/20260804000000_init.sql))*

#### Bulutda sozlash (Supabase Cloud):
1.  [supabase.com](https://supabase.com) saytida yangi loyiha oching.
2.  **SQL Editor** bo'limiga o'ting va [20260804000000_init.sql](file:///c:/Users/Bobomurodov/Desktop/avtohelp/supabase/migrations/20260804000000_init.sql) fayli ichidagi kodlarni nusxalab olib, ishga tushiring (Run).
3.  Bu SQL skript barcha jadvallarni yaratadi, PostGIS ni faollashtiradi, 3km radiusda usta qidirish funksiyasini yozadi va boshlang'ich Chevrolet, BYD, Hyundai kabi markalarni hamda servis xizmatlarini bazaga qo'shadi.

#### Edge Functions (SMS va Push yuborish):
Edge funksiyalar `/supabase/functions` papkasida joylashgan:
*   `send-otp` — Eskiz.uz SMS integratsiyasi.
*   `verify-otp` — Kod tekshiruvi va JWT Auth token yaratish.
*   `send-push` — FCM OAuth2 yordamida push yuborish.

Ularni Supabase bulutiga yuklash (deploy):
```bash
supabase functions deploy send-otp
supabase functions deploy verify-otp
supabase functions deploy send-push
```

#### Supabase Edge Function muhit o'zgaruvchilari (Environment Variables):
Bulutda quyidagi kalitlarni sozlang:
```bash
supabase secrets set ESKIZ_EMAIL="sizning_eskiz_email"
supabase secrets set ESKIZ_PASSWORD="sizning_eskiz_parol"
supabase secrets set ESKIZ_TOKEN="ixtiyoriy_doimiy_token"
supabase secrets set FCM_SERVICE_ACCOUNT='{"project_id": "...", "private_key": "...", ...}'
```

---

### 2. Flutter Mobil Ilovasi (`/mobile`)

#### `pubspec.yaml` bog'liqliklari:
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Supabase integratsiyasi
  supabase_flutter: ^2.5.0
  
  # Xarita va Joylashuv
  google_maps_flutter: ^2.6.0
  geolocator: ^11.0.0
  permission_handler: ^11.3.0
  
  # Push Notifications
  firebase_core: ^2.27.0
  firebase_messaging: ^14.7.19
  
  # State Management va tarmoq
  flutter_bloc: ^8.1.3
  dio: ^5.4.0
```

#### Flutterda Supabase va Maps-ni initsializatsiya qilish (`main.dart`):
```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Supabase ni ulash
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  runApp(const MyApp());
}
```

#### Flutterda 3km radiusdagi yaqin ustalarni olish kodi:
```dart
final response = await Supabase.instance.client.rpc(
  'search_nearby_masters',
  params: {
    'user_lat': 41.311081, // Haydovchi kengligi
    'user_lng': 69.240562, // Haydovchi uzunligi
    'target_service_id': 1, // Masalan: Evakuator
    'target_brand_id': 2,   // Masalan: BYD
    'radius_meters': 3000.0 // 3 km radius
  },
);
// response ichida ustalar ro'yxati, masofasi va narxlari keladi.
```

---

### 3. Next.js Admin Panel (`/admin`)

Admin panel Next.js 14 va Tailwind + Shadcn UI da tuziladi.

#### Muhit o'zgaruvchilari (`.env.local`):
```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### Supabase Client yaratish (`lib/supabase.ts`):
```typescript
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
```

#### Admin uchun Ustalarni Tasdiqlash so'rovi (API / Page):
```typescript
// Tasdiqlanishi kutilayotgan usta foydalanuvchilarni olish
const { data: pendingMasters } = await supabase
  .from('profiles')
  .select('*')
  .eq('role', 'MASTER')
  .eq('is_verified', false)

// Usta profilingizni tasdiqlash
const verifyMaster = async (masterId: string) => {
  const { error } = await supabase
    .from('profiles')
    .update({ is_verified: true })
    .eq('id', masterId)
  
  if (!error) {
    // FCM push notification yuborish uchun Edge funksiyasini chaqirish
    await fetch(`${supabaseUrl}/functions/v1/send-push`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${supabaseAnonKey}`
      },
      body: JSON.stringify({
        user_id: masterId,
        title: 'Akkaunt tasdiqlandi!',
        body: 'Siz endi buyurtmalarni qabul qilishingiz va online bo‘lishingiz mumkin.'
      })
    })
  }
}
```

---

## 🔒 Xavfsizlik Qoidalari (RLS - Row Level Security)

Barcha jadvallarda RLS yoqilgan. Bu foydalanuvchilar bir-birlarining maxfiy ma'lumotlarini (masalan, telefon, joylashuv, buyurtmalar tarixi) ruxsatsiz o'qiy olmasligini ta'minlaydi.
*   **Foydalanuvchilar** faqat o'zlarining shaxsiy mashinalari (`user_cars`) va buyurtmalarini boshqara oladilar.
*   **Masterlar** o'z xizmatlari va narxlarini boshqara oladilar.
*   **Admin** barcha jadvallarni o'qish va tahrirlash huquqiga ega.
