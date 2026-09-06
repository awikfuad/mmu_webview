# MMU TV — WebView Kiosk Android TV (Flutter)

Aplikasi kiosk berbasis `webview_flutter` yang menampilkan aplikasi web **MMU A-44**
(frontend: `frontend/` — route `/` = *Dashboard Harian Publik* mode kiosk).

Fitur Android native:
- **Autostart** — app otomatis terbuka penuh saat TV/STB dinyalakan (`BootReceiver` mendengar `BOOT_COMPLETED` + `LOCKED_BOOT_COMPLETED` + `QUICKBOOT_POWERON` vendor).
- **Kiosk** — fullscreen immersive (`IMMERSIVE_STICKY`, sistem bars disembunyikan), layar tidak mati/screen saver (`FLAG_KEEP_SCREEN_ON`), orientasi **landscape**.
- **Retry otomatis** — bila server web belum nyala, WebView otomatis coba muat ulang tiap 10 detik sampai tersambung.

---

## Struktur

```
mmu_webview/
├── lib/main.dart                 # WebView kiosk (Dart)
├── pubspec.yaml
└── android/
    ├── app/src/main/AndroidManifest.xml
    ├── app/src/main/kotlin/com/mmu/mmu_webview/MainActivity.kt   # kiosk native
    ├── app/src/main/kotlin/com/mmu/mmu_webview/BootReceiver.kt   # autostart
    └── app/src/main/res/                                         # icon/splash
```

---

## Build

```bash
cd mmu_webview

# (hanya sekali) Genapkan scaffolding platform bila gradle wrapper/gradlew tidak ada.
# File kustom (manifest, MainActivity.kt, BootReceiver.kt, res/) TIDAK ditimpa.
flutter create --platforms=android --org com.mmu --project-name mmu_webview .

flutter pub get

# APK release dengan alamat web MMU (ganti IP / pakai domain Vercel bila perlu)
flutter build apk --release --dart-define=APP_URL=http://192.168.1.50:5173
```

- `APP_URL` default `https://mmu-new-frontend.vercel.app/` (deployment web MMU).
  Tanpa custom, APK kiosk langsung menampilkan dashboard harian dari URL tersebut.
  Untuk server LAN/development tetap bisa:
  `--dart-define=APP_URL=http://<IP_LAN_HOST>:5173`.
- Karena memakai HTTP LAN, manifest sudah menyetel `android:usesCleartextTraffic="true"`.
- Release pakai `signingConfigs.debug` (kiosk internal). Untuk produksi ganti ke keystore
  sendiri di `android/app/build.gradle` `buildTypes.release`.

> **Syarat Java untuk build**: Gradle 8.4 + AGP 8.1 butuh **Java 17–24**.
> Pakai JBR bawaan Android Studio: `flutter config --jdk-dir="C:\Program Files\Android\Android Studio\jbr"`
> (atau set `JAVA_HOME` ke JDK 17–24). JDK 26 tidak didukung oleh versi Gradle/AGP ini.

Hasil: `build/app/outputs/flutter-apk/app-release.apk` → instal via USB/flashdisk pada TV/STB.

---

## Autostart saat TV dinyalakan

Receiver sudah terdaftar di manifest (ACTION `BOOT_COMPLETED`, `LOCKED_BOOT_COMPLETED`,
`QUICKBOOT_POWERON`). Setelah install + jalankan sekali, perangkat kemudian matikan/nyalakan
TV — app harus langsung tampil.

**Catatan Android 10+ (Android TV box/STB):** sistem membatasi activity yang dibuka receiver
background. Jika autostart tidak jalan di perangkat kamu, coba urutan berikut:

1. **Jadikan Home app** — aktifkan intent-filter `HOME` (hapus komentar blok `<!-- OPSI kiosk penuh -->`
   di `AndroidManifest.xml`), lalu di Setting TV pilih app ini sebagai **Home**.
   Setelah itu setiap boot Android langsung menampilkan app ini (cara paling andal di kiosk).
2. **Pengaturan vendor box** — banyak STB (X96, MXQ, dll.) punya menu "Auto Start"/"Boot App":
   pilih MMU TV agar dijalankan otomatis.
3. **Utilitas pihak ketiga** (mis. *Auto Start*, *Boot Manager*) — whitelist package ini:
   `com.mmu.mmu_webview`.

### Simulasi/test autostart tanpa me-restart TV

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
# buka sekali lalu keluar (agar aplikasi ter-scan launcher)
adb shell am start -n com.mmu.mmu_webview/.MainActivity
adb shell input keyevent KEYCODE_HOME

# trigger BOOT_COMPLETED lalu cek log
adb shell am broadcast -a android.intent.action.BOOT_COMPLETED -p com.mmu.mmu_webview
adb logcat -s MMU-BootReceiver

# alternatif bila BOOT_COMPLETED ditolak di user space:
adb shell am broadcast -a android.intent.action.QUICKBOOT_POWERON -p com.mmu.mmu_webview
```

Log sukses: `MMU-BootReceiver: Boot diterima (...) — autostart MMU TV`.

---

## Konfigurasi & verifikasi kiosk

| Perilaku | Implementasi |
|----------|--------------|
| Sistem bars disembunyikan | `MainActivity.hideSystemBars()` (API 29+ `WindowInsetsController`, lama `SYSTEM_UI_FLAG`) |
| Layar tidak mati | `FLAG_KEEP_SCREEN_ON` |
| Orientasi landscape | `android:screenOrientation="landscape"` di manifest |
| Kategori Android TV | `LEANBACK_LAUNCHER` dibutuhkan untuk tampil di baris app TV |
| Retry server mati | `_scheduleRetry()` di `lib/main.dart` (10 detik) |
| Alamat web | `--dart-define=APP_URL=...` |

---

## Troubleshooting

- **Layar hitam / "tidak dapat terhubung"** — pastikan `APP_URL` benar-benar bisa diakses TV
  (uji dari browser di perangkat), host server hidup, dan firewall mengizinkan port.
- **Autostart tidak jalan** — ikuti langkah "Android 10+" di atas; pastikan app pernah dibuka
  sekali dan tidak di-force-stop dari Settings (force-stop = receiver ikut dimatikan).
- **`flutter.sdk not set in local.properties`** — jalankan `flutter create .` sekali (otomatis
  membuat `local.properties`), atau `flutter doctor` untuk memastikan SDK terpasang.