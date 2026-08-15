# Avtohelp Android APK — Build Ko'rsatmasi

## 1-qadam: Android Studio o'rnatish

1. https://developer.android.com/studio ga kiring
2. **Android Studio** ni yuklab o'rnating
3. Birinchi ishga tushganda:
   - "Standard" sozlamani tanlang
   - Android SDK avtomatik o'rnatiladi

---

## 2-qadam: Flutter Android SDK ni ko'rsatish

```powershell
flutter config --android-sdk "C:\Users\Bobomurodov\AppData\Local\Android\Sdk"
```

---

## 3-qadam: Litsenziyalarni qabul qilish

```powershell
$env:Path += ";C:\src\flutter\bin"; flutter doctor --android-licenses
# Hamma savolga "y" deb javob bering
```

---

## 4-qadam: Release APK build qilish

```powershell
cd C:\Users\Bobomurodov\Desktop\avtohelp\mobile
$env:Path += ";C:\src\flutter\bin"
flutter build apk --release --split-per-abi
```

---

## 5-qadam: APK joylashuvi

```
mobile\build\app\outputs\flutter-apk\
  app-arm64-v8a-release.apk   ← Yangi Samsung/Xiaomi uchun (yuborilsin)
  app-armeabi-v7a-release.apk ← Eski telefonlar uchun
```

---

## Muhim: Nima uchun endi Play Protect o'tadi?

| Ilgari (❌) | Hozir (✅) |
|------------|-----------|
| Debug keystore bilan imzolangan | Release keystore `avtohelp-release.jks` bilan imzolangan |
| `isMinifyEnabled = false` | `isMinifyEnabled = true` — kichik, toza APK |
| App nomi: `master_help` | App nomi: `Avtohelp` |
| `allowBackup` yo'q | `allowBackup="false"` — xavfsizroq |

---

## Alternativ: GitHub Actions orqali avtomatik build

Agar Android Studio o'rnatish qiyin bo'lsa, GitHub Actions bepul cloud build qiladi.
