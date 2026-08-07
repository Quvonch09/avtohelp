# Master Help — Flutter Mobil Ilovasi (Android APK)

Ushbu qatlam platformaning mijozlar va ustalar uchun mo'ljallangan **Flutter** mobil ilovasi manba kodlaridan iborat.

---

## 📱 APK Tayyorlash va Telefonga O'rnatish Qo'llanmasi

### 1-Usul: GitHub Actions orqali Avtomatik APK Yaratish (Tavsiya etiladi)
Loyiha ildizida `.github/workflows/build-apk.yml` fayli joylashtirilgan.
1. Ushbu loyihani GitHub-ga yuklang (`git push`).
2. GitHub sahifangizda **Actions** bo'limiga o'ting.
3. **Build Mobile Android APK** tugmasini bosing yoki har bir push-da avtomatik APK tayyorlanadi.
4. Tayyor bo'lgach, **Artifacts** bo'limidan `Avtohelp-MasterHelp-Release-APK.zip` faylini yuklab olib, telefonga o'rnating.

---

### 2-Usul: Kompyuterda Lokal Yig'ish (Local Build)

Agar kompyuteringizda Flutter va Android SDK o'rnatilgan bo'lsa:

```bash
# 1. Mobil ilova papkasiga o'ting
cd mobile

# 2. Kutubxonalarni yuklab oling
flutter pub get

# 3. Android APK faylini release rejimida build qiling
flutter build apk --release
```

**Tayyor APK fayli manzili:**
```text
mobile/build/app/outputs/flutter-apk/app-release.apk
```
Ushbu `.apk` faylini Telegram yoki USB orqali Android telefoningizga o'tkazib, darhol o'rnatishingiz mumkin.

---

### 3-Usul: Web versiyada sinash (Flutter Web)

```bash
cd mobile
flutter run -d chrome
```

