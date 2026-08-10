# iOS Ad Hoc Signing & CI/CD Setup Guide (Windows Developers)

Ushbu yo'riqnoma macOS/Mac kompyuterisiz, Windows operatsion tizimidan turib, GitHub Actions yordamida mobil ilovamizni (Flutter) haqiqiy iPhone telefoningiz uchun kod-imzolangan (code signed) `.ipa` formatida yig'ish va o'rnatish yo'lini ko'rsatadi.

---

## 1. Apple Developer Portali sozlamalari

Sizga **Apple Developer Program** ($99/yil) a'zoligi talab qilinadi. Brauzerda [developer.apple.com](https://developer.apple.com) sahifasiga kiring va "Account" bo'limiga o'ting.

### A. App ID (Bundle ID) ro'yxatdan o'tkazish
1. **Certificates, Identifiers & Profiles** -> **Identifiers** bo'limiga o'ting.
2. Yangi qo'shish tugmasini bosing (**+**).
3. **App IDs** tanlang va "Continue" bosing.
4. Turi sifatida **App** tanlang.
5. Sozlamalarni kiriting:
   - **Description:** `Avtohelp Mobile App`
   - **Bundle ID (Explicit):** `uz.avtohelp.master_help` (Loyiha kodi bilan bir xil bo'lishi shart!)
6. **Capabilities** ro'yxatidan ilovangizga kerakli xizmatlarni yoqing (masalan: *Push Notifications*).
7. **Register** tugmasini bosing.

### B. iPhone UDID (Qurilma ID) ro'yxatdan o'tkazish
*Ad Hoc imzolangan ilova faqat ro'yxatdan o'tgan iPhone qurilmalariga o'rnatiladi.*
1. iPhone telefoningizni kompyuterga ulang, iTunes-ni oching va qurilmaning **UDID** kodini nusxalab oling (yoki [showmyudid.com](https://showmyudid.com) yordamida brauzer orqali aniqlang).
2. Developer portalda **Devices** bo'limiga o'ting.
3. Yangi qurilma qo'shish (**+**) tugmasini bosing.
4. Telefon nomini va **UDID** kodini yozib, **Register** qiling.

### C. Apple Distribution sertifikatini olish
1. **Certificates** bo'limiga o'ting va **+** bosing.
2. **Apple Distribution** (yoki *iOS Distribution*) tanlang.
3. Sizdan **CSR (Certificate Signing Request)** yuklash so'raladi. Uni Windowsda tayyorlash uchun:
   - Kompyuterda terminalni ochib, PowerShell skriptini ishga tushiring:
     ```powershell
     .\scripts\ios\prepare-signing.ps1
     ```
   - Skript sizga `C:\ios-signing` papkasini ochib beradi va OpenSSL yo'lini tekshiradi.
   - Quyidagi buyruqni terminalda bajaring (OpenSSL yordamida shaxsiy kalit va CSR yaratish):
     ```powershell
     & "C:\Program Files\Git\usr\bin\openssl.exe" genrsa -out C:\ios-signing\private.key 2048
     & "C:\Program Files\Git\usr\bin\openssl.exe" req -new -key C:\ios-signing\private.key -out C:\ios-signing\request.certSigningRequest -subj "/emailAddress=your-email@example.com, CN=Your Name, C=UZ"
     ```
4. Yaratilgan `C:\ios-signing\request.certSigningRequest` faylini Apple Developer portaliga yuklang (**Choose File** -> **Generate**).
5. Tayyor bo'lgan `distribution.cer` sertifikatini yuklab oling va uni `C:\ios-signing\` papkasiga saqlang.

### D. Sertifikatni `.p12` formatiga o'tkazish
Windowsda yuklab olingan `.cer` va shaxsiy kalitimizni birlashtirib `.p12` faylini yaratamiz:
```powershell
& "C:\Program Files\Git\usr\bin\openssl.exe" x509 -in C:\ios-signing\distribution.cer -inform DER -out C:\ios-signing\distribution.pem -outform PEM
& "C:\Program Files\Git\usr\bin\openssl.exe" pkcs12 -export -inkey C:\ios-signing\private.key -in C:\ios-signing\distribution.pem -out C:\ios-signing\distribution.p12
```
*Sizdan `.p12` fayli uchun **parol** (P12_PASSWORD) yaratish so'raladi. Uni eslab qoling!*

### E. Ad Hoc Provisioning Profile yaratish
1. Portalda **Profiles** bo'limiga o'ting va **+** bosing.
2. **Distribution** ostidan **Ad Hoc** tanlang va "Continue" bosing.
3. Yuqorida yaratilgan **App ID** (`uz.avtohelp.master_help`) tanlang.
4. Yaratilgan **Apple Distribution sertifikatini** tanlang.
5. Ilova o'rnatiladigan **iPhone qurilmasini (UDID)** tanlang.
6. Profilga nom bering (masalan: `Avtohelp_AdHoc`).
7. **Generate** bosing va tayyor profile faylini (`.mobileprovision`) yuklab olib, `C:\ios-signing\` papkasiga saqlang.

---

## 2. GitHub Secrets Sozlamalari

Fayllarni GitHub-ga xavfsiz tarzda Base64 formatda yuboramiz. Buning uchun Windowsda tayyorlagan ikkinchi skriptimizni ishga tushiring:
```powershell
.\scripts\ios\encode-secrets.ps1
```
Skript `C:\ios-signing` ichida 2 ta Base64 matnli fayl yaratadi.

GitHub-da loyihangiz sahifasiga kiring va **Settings** -> **Secrets and variables** -> **Actions** bo'limidan quyidagi maxfiy kalitlarni (Repository Secrets) qo'shing:

1. `P12_BASE64` - `distribution_p12_base64.txt` fayli ichidagi barcha yozuvni to'liq nusxalab joylang.
2. `P12_PASSWORD` - `.p12` sertifikatini yaratishda qo'ygan parolingiz.
3. `PROVISIONING_PROFILE_BASE64` - `Avtohelp_AdHoc_mobileprovision_base64.txt` fayli ichidagi barcha yozuvni nusxalab joylang.
4. `KEYCHAIN_PASSWORD` - macOS runner vaqtinchalik kalitlar ombori uchun istalgan ixtiyoriy parol (masalan: `supersecret123`).
5. `GOOGLE_MAPS_API_KEY` - Sizning Google Maps API kalitingiz (Android va iOS buildlar uchun ishlatiladi).

---

## 3. GitHub Actions orqali build qilish

1. Barcha o'zgarishlarni GitHub-ga yuklang (Push qiling).
2. GitHub sahifangizda **Actions** tabiga o'ting.
3. Chap menyudan **Build Mobile Apps** tanlang.
4. **Run workflow** tugmasini bosing.
5. Qurish jarayoni yakunlangach, quyidagi natijalarni (Artifacts) yuklab olishingiz mumkin bo'ladi:
   - 🤖 **Avtohelp-Android-APK** -> `app-release.apk`
   - 🍏 **Avtohelp-iOS-AdHoc-IPA** -> `Runner.ipa` (kod-imzolangan real telefon uchun tayyor ilova!)

---

## 4. Telefonga o'rnatish

Yuklab olingan `.ipa` faylini iPhone qurilmangizga o'rnatish uchun:
- **Tavsiya etilgan eng oson yo'l (Simsiz):** [diawi.com](https://www.diawi.com) yoki [installonair.com](https://www.installonair.com) xizmatiga `.ipa` faylini yuklang. U sizga QR-kod yoki havola beradi. Telefoningiz kamerasi orqali QR-kodni skanerlab, ilovani to'g'ridan-to'g'ri o'rnating.
- **Kabel orqali (Kompyuterdan):** **3uTools** dasturi (yoki Apple Configurator) orqali telefoningizga o'rnating.
