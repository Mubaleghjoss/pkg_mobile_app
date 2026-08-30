# Rancangan Aplikasi Flutter PKGenerus

Dokumen ini adalah rancangan yang SUDAH DIIMPLEMENTASIKAN sebagai fondasi
(bukan rencana kosong). Status setiap bagian ditandai eksplisit:
`[SIAP]` sudah jalan dan terverifikasi, `[BELUM]` masih pekerjaan berikutnya.

Terakhir diverifikasi: 2026-08-30 pada backend lokal `http://127.0.0.1:8010`.

## 1. Ruang lingkup dan prinsip

- Backend Laravel TIDAK diubah. Flutter murni konsumen `/api/v1` (Sanctum
  bearer token). Semua kebutuhan data yang belum ada API-nya dicatat sebagai
  gap, bukan diakali dengan scraping halaman web.
- Satu sumber kebenaran status login: `AuthController` (Riverpod Notifier).
  Router, layar, dan interceptor HTTP semuanya membaca state yang sama.
- Fail-visible, bukan fail-silent: setiap error API muncul sebagai pesan
  berbahasa Indonesia dengan tombol coba lagi, tidak ada `catch {}` kosong.
- Permission dari server yang menentukan UI, bukan asumsi di klien. Menu yang
  tidak diizinkan tetap terlihat tapi menampilkan alasan penolakan.

## 2. Arsitektur

```
lib/
  main.dart                       ProviderScope + MaterialApp.router
  app/
    providers.dart                wiring dependency (Dio, store, repository)
    router.dart                   GoRouter + redirect auth + HomeShell
    theme.dart                    Material 3, seed #2563EB
  core/
    api_config.dart               base URL via --dart-define PKG_API_BASE
    network/
      api_client.dart             factory Dio + interceptor token/401
      api_result.dart             hasil sukses/gagal tanpa exception
      paginated.dart              PageMeta dari `meta` Laravel
    storage/
      session_store.dart          secure storage + fallback prefs
  features/<fitur>/
    data/                         repository (HTTP -> model)
    domain/                       model murni
    application/                  controller/state (Riverpod)
    presentation/                 layar
  shared/widgets/state_widgets.dart  ErrorPanel, StatCard, NoPermissionPanel
```

Pemisahan tiga lapis per fitur dipilih karena aplikasi ini akan tumbuh ke
banyak modul (binaan pamong, penilaian, rapor). Lapisan `data` memegang bentuk
JSON backend, sehingga saat API berubah hanya satu file per fitur yang disentuh.

### Alasan pemilihan paket

| Kebutuhan | Paket | Alasan |
|---|---|---|
| State management | `flutter_riverpod` 3.0.0 | compile-safe, mudah di-test tanpa widget, `ref.invalidate` cocok untuk pull-to-refresh |
| Navigasi | `go_router` 18 | redirect deklaratif untuk auth gate, ShellRoute untuk bottom nav |
| HTTP | `dio` 5.11 | interceptor untuk bearer token dan penanganan 401 terpusat |
| Token | `flutter_secure_storage` 11 | Keystore Android; ada fallback prefs supaya app tidak mati |
| Scan QR | `mobile_scanner` 7.4 | presensi lewat `POST /presensi/scan-qr` |
| Grafik | `fl_chart` 1.2 | rekap presensi |
| Cache offline | `sqflite` 2.4 | rencana mode offline daftar siswa |

## 3. Autentikasi (SIAP)

Kontrak yang diverifikasi langsung dari backend:

- `POST /api/v1/login` menerima field **`username`** (bukan `email`) + `password`.
- Respons: `{user:{id,username,role,permissions[]}, token, expires_at}`; token
  Sanctum berumur 7 hari.
- Rate limit login 5 percobaan / 5 menit per IP, balasan HTTP 429.
- `GET /api/v1/me` untuk validasi token saat app start.
- `POST /api/v1/refresh` menerbitkan token baru dan mencabut yang lama.
- `POST /api/v1/logout` mencabut token.

Alur di aplikasi:

1. App start: `AuthController.restoreSession()` membaca token tersimpan.
2. Token kedaluwarsa lokal -> langsung logout, tanpa memanggil server.
3. Token ada -> `GET /me` untuk verifikasi dan menyegarkan daftar permission.
4. Jika `/me` gagal karena jaringan (bukan 401), sesi tersimpan tetap dipakai
   supaya aplikasi bisa dibuka saat offline; error muncul per layar.
5. Interceptor menangkap HTTP 401 kapan pun, menghapus sesi, dan memaksa router
   ke `/login` dengan pesan "Sesi berakhir".
6. Logout selalu membersihkan token lokal, bahkan bila panggilan server gagal.

## 4. Peta layar dan gerbang permission

| Route | Layar | Permission | Status |
|---|---|---|---|
| `/login` | LoginScreen | - | SIAP |
| `/` | DashboardScreen (4 kartu metrik + aktivitas) | - | SIAP |
| `/siswa` | SiswaScreen (cari + infinite scroll) | `view_students` | SIAP |
| `/presensi` | PresensiScreen (riwayat berwarna per status) | `view_attendance` | SIAP |
| `/kelas` | KelasScreen (data arsip) | - | SIAP |
| `/scan-qr` | ScanQrScreen (mobile_scanner + input manual debug) | - (endpoint publik) | SIAP |
| `/siswa/:id` | SiswaDetailScreen (identitas, akademik, wali, sistem) | `view_students` | SIAP |
| `/profil` | Profil, ganti password, tema | - | BELUM |

Navigasi: `NavigationBar` di layar sempit, `NavigationRail` otomatis pada lebar
>= 800px, jadi tablet dan web tidak memakai tata letak ponsel yang melebar.

## 5. Endpoint API v1 yang dipakai (terverifikasi)

| Endpoint | Isi | Catatan |
|---|---|---|
| `GET /siswa` | data[] + meta paginasi 15/halaman | mendukung `search`, `status`, `page` |
| `GET /siswa/statistics` | total, aktif, non_aktif, per_jenis_kelamin | - |
| `GET /siswa/{id}` | detail siswa | dipakai `/siswa/:id`; hanya di sini ada `is_biodata_complete` + `missing_biodata_fields` |
| `GET /siswa/{id}/qr-code` | `qr_data.token` + SVG + `siswa_info` | sumber token untuk uji scan |
| `GET /presensi` | data[] + meta, `siswa` ter-nest | filter `tanggal`, `status` |
| `POST /presensi/scan-qr` | `{success, message, data:{status, jam_masuk, siswa}, student}` | PUBLIK tanpa token, limit 30/menit |
| `GET /dashboard/stats` | total_students, present/absent/late_today | - |
| `GET /dashboard/recent-activities` | aktivitas terbaru | - |
| `GET /kelas` | data[] kelas | backend menandai `deprecated: true` |

### Gap API yang perlu dibuat di backend (BELUM)

Modul utama PKGenerus versi web belum punya padanan di API v1:

1. Binaan Pamong dan Kelas Sekolah — pengganti `/kelas` yang deprecated.
2. Penilaian karakter / capaian pembinaan.
3. Rapor dan rekap periodik.
4. Endpoint mutasi presensi (create/update manual, bukan hanya scan QR).

Sampai ini tersedia, aplikasi hanya bisa menampilkan data baca. Menandai ini
sebagai gap lebih jujur daripada membuat layar yang datanya dikarang.

## 6. Penanganan error

`ApiResult` memetakan status HTTP ke pesan Indonesia, tanpa melempar exception:

- 401 → sesi dibersihkan, pindah ke login.
- 403 → `NoPermissionPanel` menyebut nama permission yang kurang.
- 422 → `fieldErrors` per field untuk ditempel di form.
- 429 → pesan rate limit apa adanya dari server (memuat sisa detik).
- timeout / connection error → menyebut base URL yang sedang dipakai, sehingga
  salah setting alamat emulator langsung kelihatan.

## 7. Konfigurasi alamat backend

Base URL disuntik saat build, default `http://127.0.0.1:8010`:

```bash
# Emulator Android (10.0.2.2 = host laptop dari dalam emulator)
flutter run --dart-define=PKG_API_BASE=http://10.0.2.2:8010

# HP fisik satu Wi-Fi; backend harus: php artisan serve --host=0.0.0.0 --port=8010
flutter run --dart-define=PKG_API_BASE=http://192.168.x.x:8010

# Produksi
flutter build apk --release --dart-define=PKG_API_BASE=https://pkgenerus.my.id
```

Alamat aktif ditampilkan di layar login supaya tester tahu ia menunjuk ke mana.

## 8. Akun tester

| Username | Password | Role | Permission | Yang bisa diuji |
|---|---|---|---|---|
| `tester_admin` | `tester123` | admin | 14 | semua menu |
| `tester_pamong` | `tester123` | teacher | 9 | siswa + presensi |
| `tester_ortu` | `tester123` | student | 2 (`view_attendance`, `view_qr`) | presensi saja; `/siswa` sengaja 403 |

Akun `tester_ortu` memang dibatasi supaya gerbang permission benar-benar teruji,
bukan hanya jalur bahagia.

## 9. Verifikasi yang sudah dijalankan

- `flutter analyze` → No issues found.
- `flutter test` → 24 tes lulus (parsing payload nyata, header bearer,
  pembersihan sesi saat 401, 422 fieldErrors, 429 rate limit, 403 permission,
  plus 13 tes `QrPayload` untuk format PKG/JSON dan bentuk request body).
- `flutter build web --release` → sukses.
- `flutter build apk --debug` → sukses.
- Login ketiga akun tester via HTTP nyata; matriks izin sesuai harapan
  (`tester_ortu` mendapat 403 pada `/siswa`, 200 pada `/presensi`).

### Uji end-to-end di emulator Android (mobile-mcp)

Dijalankan pada AVD **Pixel_8 / Android 14** (`emulator-5554`) dengan APK
`--dart-define=PKG_API_BASE=http://10.0.2.2:8010`, dikendalikan lewat
[mobile-mcp](https://github.com/mobile-next/mobile-mcp).

Terbukti dari perangkat, bukan hanya dari kode:

- Reachability: `nc 10.0.2.2 8010` di dalam emulator → `HTTP/1.1 200 OK`.
- Login `tester_admin` sukses; dashboard menampilkan "Peran: admin · 14 izin"
  dan metrik nyata dari backend (Total siswa 10).
- `/siswa` memuat 10 siswa; menekan satu baris membuka `/siswa/:id` dan
  menampilkan seksi Identitas, Akademik, Wali, Sistem.
- Tab Presensi memuat riwayat; FAB "Scan QR" hanya muncul di tab ini.
- Scan QR → API → DB terbukti: payload asli dari `GET /siswa/{id}/qr-code`
  dikirim dari layar scan, panel hasil menampilkan
  "Berhasil mencatat kehadiran (Terlambat) / Reza Firmansyah · NIS 2024007",
  dan baris baru muncul di `GET /presensi` (Bayu Setiawan 15:14, Aisyah Putri
  15:15, Reza Firmansyah 15:19).

Skrip langkah mobile-mcp ada di `E:/hermes/scripts/mcp_steps_*.json`, dijalankan
oleh `E:/hermes/scripts/mobile_mcp_driver.js` dan diringkas `mcp_report.py`.

#### Kendala emulator yang harus diakali

1. **AVD tidak terbaca toolchain portabel.** `Pixel_8` dibuat Android Studio dan
   system image `android-34` ada di `%LOCALAPPDATA%\Android\Sdk`, jadi emulator
   harus dijalankan dari SDK itu (`ANDROID_HOME` menunjuk ke sana), bukan dari
   `E:/hermes/tools/android-sdk`. Flag yang stabil:
   `-gpu swiftshader_indirect -no-snapshot -no-boot-anim -no-audio`.
2. **Kamera virtual memblokir UI thread.** Begitu dialog/keyboard muncul di atas
   preview `mobile_scanner`, Android memunculkan ANR
   "PKGenerus isn't responding". Karena itu ada
   `--dart-define=PKG_SCAN_NO_CAMERA=true` yang mengganti preview dengan
   placeholder; alur scan → API tetap diuji lewat tombol input manual (build
   debug saja). Di perangkat asli flag ini tidak dipakai.
3. `mobile_scanner.stop()`/`start()` bisa menggantung di emulator, jadi
   dibungkus `timeout(3s)` supaya kegagalan kamera tidak menahan pengiriman.
4. `INTERNET` permission sebelumnya hanya ada di manifest `debug`/`profile`;
   sekarang ditambahkan ke `main/AndroidManifest.xml` agar build release tidak
   gagal jaringan.

### Bug backend yang ditemukan saat uji ini

`POST /api/v1/presensi/scan-qr` selalu **HTTP 500**
("Trying to access array offset on value of type null") untuk semua bentuk body.
Penyebabnya di backend, bukan di Flutter: `PresensiController::scanQr()` membaca
`$request->validated('qr_data')['student_id']`, tetapi `qr_data` tidak pernah
dideklarasikan di `ScanQrRequest::rules()` sehingga `validated()` mengembalikan
`null`. Artinya fitur scan QR mobile belum pernah bisa dipakai.

Perbaikan (LOKAL, belum di-deploy) di
`app/Http/Requests/Presensi/ScanQrRequest.php`: `prepareForValidation()` mengurai
isi QR menjadi `qr_data`. Hasil uji sesudahnya:

| Body | Sebelum | Sesudah |
|---|---|---|
| `PKG|1|<id>|<token>|<hash>` | 500 | 200 "Berhasil mencatat kehadiran" |
| `token` polos + `student_id` | 500 | 200 |
| token 64-hex palsu | 500 | 400 `QR_EXPIRED` |
| token `"abc"` | 500 | 422 "Token QR tidak valid." |

Bentuk JSON bersarang (`{"token":"{\"student_id\":…}"}`) masih 422; parser sudah
menerimanya saat diuji langsung dengan `php -r`, jadi penyebabnya di lapisan lain
(dugaan: middleware yang menyentuh body). Dampaknya nol untuk aplikasi karena QR
yang dicetak backend selalu format pipe PKG.

### Catatan build Android

`compileSdk` dipin ke **37** di `android/app/build.gradle.kts` karena
`flutter_secure_storage` 11.x menolak dikompilasi di bawah API 37 (AAR metadata
check). Dua kendala lingkungan yang sudah diselesaikan:

1. SDK manager toolchain portabel memasang platform sebagai
   `platforms/android-37.0` dengan `AndroidVersion.ApiLevel=37.0`, sementara
   Gradle mencari direktori `android-37`. Gejalanya:
   `Failed to find target with hash string 'android-37'`.
   Solusi: direktori `platforms/android-37` disiapkan dengan
   `AndroidVersion.ApiLevel=37`. SDK manager tetap mencetak peringatan
   "inconsistent location" — itu peringatan, bukan kegagalan.
2. Turun ke `compileSdk = 36` bukan jalan keluar; build gagal justru karena
   `flutter_secure_storage` mensyaratkan 37.

Peringatan yang tersisa dan aman diabaikan untuk sekarang: `mobile_scanner`
masih memakai Kotlin Gradle Plugin (Flutter versi mendatang akan menolaknya),
jadi paket itu perlu dipantau saat upgrade Flutter.

Hasil build terverifikasi:

- `build/app/outputs/flutter-apk/app-debug.apk` — 218 MB (debug, wajar karena
  berisi semua ABI + tidak di-obfuscate).
- `build/web` — 41 MB (release).

## 10. Langkah berikutnya (urutan yang disarankan)

1. Riwayat presensi per siswa di layar detail (butuh filter `siswa_id` pada
   `GET /presensi`; cek dulu apakah backend mendukungnya).
2. Profil dan ganti password.
3. Cache offline `sqflite` untuk daftar siswa.
4. Review + deploy perbaikan `ScanQrRequest.php` ke produksi (saat ini lokal).
5. Bahas penambahan endpoint untuk binaan pamong / penilaian / rapor sebelum
   membangun layarnya.
6. Pantau `mobile_scanner` saat upgrade Flutter (masih memakai KGP lama).
