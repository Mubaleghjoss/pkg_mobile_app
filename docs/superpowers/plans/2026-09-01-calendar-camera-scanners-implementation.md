# Kalender dan Scanner Kamera PKGenerus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menyediakan kalender read-only lintas peran, membuka scanner presensi bagi pamong, dan menambahkan scanner QR lembar tracer Quran untuk pamong serta siswa.

**Architecture:** Laravel menyediakan API v1 token-based dan menjalankan seluruh pembatasan akses. Flutter menggunakan model/repository native, sedangkan scanner presensi dan tracer berbagi plugin kamera tetapi mempunyai parser dan alur domain terpisah. Pengembangan memakai irisan vertikal TDD: test gagal, implementasi minimum, lalu test lulus.

**Tech Stack:** Laravel 11, PHP 8.2, Sanctum, PHPUnit, Flutter/Dart, Riverpod 3, GoRouter, Dio, mobile_scanner, Android emulator API 34.

**Spec:** `docs/superpowers/specs/2026-09-01-calendar-camera-scanners-design.md`

## Global Constraints

- Jangan commit, push, membuat repository remote, atau deploy.
- Jangan menghidupkan kembali endpoint `/kelas`; sumber kelas aktif tetap Binaan Pamong dan Kelas Sekolah.
- Server menjadi sumber kebenaran untuk hak akses, cakupan data, status verifikasi, dan barcode.
- Kalender tahap pertama read-only.
- Tracer tahap pertama scan QR lembar dan input manual rentang bacaan; tidak ada OCR.
- Klaim scan optik final memerlukan HP fisik; emulator hanya membuktikan permission, preview, navigasi, dan kontrak API.
- Pertahankan semua perubahan lokal yang sudah ada.

---

### Task 1: API kalender lintas peran

**Files:**
- Create: `E:/hermes/pkgenerus/app/Http/Controllers/Api/CalendarController.php`
- Modify: `E:/hermes/pkgenerus/routes/api.php`
- Create: `E:/hermes/pkgenerus/tests/Feature/CalendarApiTest.php`

**Interfaces:**
- Consumes: aktor Sanctum staff/siswa/ortu dan logika event dari `app/Http/Controllers/CalendarController.php`.
- Produces: `GET /api/v1/calendar/events?start=YYYY-MM-DD&end=YYYY-MM-DD` dengan `{success,data,meta}`.

- [ ] **Step 1: Tulis test gagal autentikasi dan bentuk respons staff**
  Buat test yang meminta endpoint tanpa token dan mengharapkan 401; lalu sebagai staff mengharapkan `success`, array `data`, serta `meta.actor=staff` dan rentang tanggal yang diminta.
- [ ] **Step 2: Jalankan test spesifik dan buktikan RED**
  Run: `source E:/hermes/scripts/env.sh && php artisan test tests/Feature/CalendarApiTest.php`
  Expected: gagal karena rute/controller API belum ada.
- [ ] **Step 3: Implementasikan route dan controller minimum**
  Tambahkan route di grup `auth:sanctum`; validasi `start/end` format tanggal, `end>=start`, dan rentang maksimal 93 hari. Adaptasi pembentukan event dari controller kalender web tanpa mengembalikan URL internal.
- [ ] **Step 4: Tambah test cakupan siswa dan orang tua**
  Test siswa hanya memperoleh event dirinya; token ortu hanya memperoleh event anak terkait; staff pamong tidak memperoleh event siswa di luar binaan.
- [ ] **Step 5: Jalankan RED lalu implementasikan scope server-side**
  Gunakan relasi aktor dan helper cakupan yang sudah ada; jangan menyaring hak akses di Flutter.
- [ ] **Step 6: Tambah test validasi rentang**
  Uji tanggal invalid, `end < start`, dan rentang lebih dari 93 hari menghasilkan 422.
- [ ] **Step 7: Jalankan test kalender sampai GREEN**
  Run: `source E:/hermes/scripts/env.sh && php artisan test tests/Feature/CalendarApiTest.php`
  Expected: seluruh test file lulus.

### Task 2: Kalender native Flutter

**Files:**
- Create: `lib/features/calendar/domain/calendar_event.dart`
- Create: `lib/features/calendar/data/calendar_repository.dart`
- Create: `lib/features/calendar/presentation/calendar_screen.dart`
- Modify: `lib/app/providers.dart`
- Modify: `lib/app/router.dart`
- Create: `test/calendar_test.dart`

**Interfaces:**
- Consumes: endpoint Task 1 melalui `ApiClient` dan aktor `AuthState`.
- Produces: `CalendarEvent.fromJson`, repository `events(start,end)`, provider state bulan/filter/tanggal, dan route `/calendar` untuk semua aktor.

- [ ] **Step 1: Tulis test gagal parsing event dan grouping tanggal lokal**
  Uji ISO timestamp dipanggil `.toLocal()`, `all_day`, `type`, `color`, dan grouping berdasarkan tanggal lokal.
- [ ] **Step 2: Jalankan test dan buktikan RED**
  Run: `flutter test test/calendar_test.dart`
  Expected: gagal karena model belum ada.
- [ ] **Step 3: Implementasikan model minimum lalu GREEN**
  Buat model immutable dan helper tanggal tanpa dependency kalender baru.
- [ ] **Step 4: Tulis test gagal repository**
  Gunakan pola fake Dio/repository test yang sudah ada; pastikan parameter `start/end` dan mapper response benar.
- [ ] **Step 5: Implementasikan repository/provider lalu GREEN**
  Muat hanya rentang bulan aktif dan expose refresh/error/empty state.
- [ ] **Step 6: Tulis widget test kalender**
  Uji judul bulan, perubahan bulan, tanggal terpilih, filter kategori, agenda terdekat, empty, dan error/retry.
- [ ] **Step 7: Implementasikan UI tanpa package kalender tambahan**
  Gunakan `showDatePicker`/grid Material ringan sesuai pola aplikasi, chip kategori, daftar agenda tanggal terpilih, dan agenda terdekat.
- [ ] **Step 8: Tambahkan route/menu untuk staff, siswa, dan ortu**
  Pastikan menu Kalender muncul di “Lainnya” semua aktor dan route tidak memberi aksi tulis.
- [ ] **Step 9: Jalankan test kalender Flutter sampai GREEN**
  Run: `flutter test test/calendar_test.dart`

### Task 3: Perbaikan akses scanner presensi pamong

**Files:**
- Modify: `lib/app/router.dart`
- Test: `test/fitur_baru_test.dart` atau `test/presensi_scanner_navigation_test.dart`

**Interfaces:**
- Consumes: `GoRouterState.matchedLocation` dan route `/scan-qr` yang sudah ada.
- Produces: FAB “Scan QR” pada rute `/presensi` staff walaupun Presensi berasal dari “Lainnya”.

- [ ] **Step 1: Tulis regression test gagal**
  Render shell staff pada matched location `/presensi`; harapkan `find.text('Scan QR')` satu kali dan route lain tidak menampilkannya.
- [ ] **Step 2: Jalankan test dan buktikan RED**
  Run: `flutter test test/presensi_scanner_navigation_test.dart`
  Expected: FAB tidak ditemukan.
- [ ] **Step 3: Patch minimum `_fabFor`**
  Tentukan aksi kontekstual dari `widget.state.matchedLocation`, bukan `_tabs[_index].path`; pertahankan bottom navigation tiga tab dan menu Lainnya.
- [ ] **Step 4: Jalankan test sampai GREEN**
  Run test spesifik, kemudian `flutter test test/qr_payload_test.dart test/presensi_scanner_navigation_test.dart`.

### Task 4: API barcode tracer Quran stateless dan idempotent

**Files:**
- Modify: `app/Http/Controllers/Api/QuranReadingController.php`
- Create: `app/Services/QuranMobileBarcodeFlowService.php`
- Modify: `routes/api.php`
- Create: `tests/Feature/QuranBarcodeApiTest.php`

**Interfaces:**
- Consumes: resolver lembar/signature dan aturan `QuranReadingController` web, cakupan binaan, model entri Quran.
- Produces: `POST /api/v1/quran/barcode/identify` dan `POST /api/v1/quran/barcode/store`; flow cache TTL 30 menit terikat aktor; retry store mengembalikan entry yang sama.

- [ ] **Step 1: Tulis test gagal identify siswa valid**
  Token siswa + `sheet_payload` miliknya menghasilkan flow acak, `expires_at`, dan identitas masked; lembar siswa lain ditolak tanpa bocor identitas.
- [ ] **Step 2: Jalankan test dan buktikan RED**
  Run: `source E:/hermes/scripts/env.sh && php artisan test tests/Feature/QuranBarcodeApiTest.php`
- [ ] **Step 3: Implementasikan service flow minimum dan endpoint identify**
  Cache key menyimpan actor type/id, context, sheet id, siswa id, expiry, dan status; respons `Cache-Control: private, no-store`.
- [ ] **Step 4: Tambah test pamong scope dan ortu ditolak**
  Pamong binaan berhasil; luar binaan 403; orang tua 403.
- [ ] **Step 5: Tambah test gagal store dan validasi rentang**
  Siswa menghasilkan pending; pamong verified; ayat/surat/page invalid 422; flow aktor lain dan expired ditolak.
- [ ] **Step 6: Implementasikan store memakai aturan domain web**
  Jangan percaya `siswa_id` dari request. Ambil siswa/lembar dari flow dan catat verifier untuk pamong.
- [ ] **Step 7: Tambah test idempotensi**
  Dua request store identik untuk flow selesai harus mengembalikan `entry_id` yang sama dan hanya satu record.
- [ ] **Step 8: Implementasikan hasil flow selesai dan jalankan GREEN**
  Simpan entry id pada cache flow selesai sampai TTL; retry mengembalikan respons sukses yang sama.

### Task 5: Scanner dan formulir tracer Flutter

**Files:**
- Modify: `lib/features/quran/data/quran_models.dart`
- Modify: `lib/features/quran/data/quran_repository.dart`
- Create: `lib/features/quran/presentation/quran_barcode_scan_screen.dart`
- Create: `lib/features/quran/presentation/quran_barcode_form_screen.dart`
- Modify: `lib/features/quran/presentation/quran_screen.dart`
- Modify: `lib/app/router.dart`
- Create: `test/quran_barcode_test.dart`

**Interfaces:**
- Consumes: endpoint Task 4, `mobile_scanner`, katalog surah repository yang ada.
- Produces: identify model, store payload/result, route scan/form, tombol siswa “Scan lembar”, dan menu staff “Tracer Quran”.

- [ ] **Step 1: Tulis test gagal model/repository identify dan store**
  Uji mapping flow/student/status/entry id serta request tanpa `siswa_id`.
- [ ] **Step 2: Jalankan RED lalu implementasikan model/repository minimum**
- [ ] **Step 3: Tulis test gagal validasi rentang bacaan**
  Surat awal/akhir, ayat maksimum, urutan lintas surat, halaman opsional, dan catatan diuji sebagai fungsi murni.
- [ ] **Step 4: Implementasikan validator dan jalankan GREEN**
- [ ] **Step 5: Tulis widget test peran dan status**
  Siswa melihat “Scan lembar” dan copy pending; staff melihat “Tracer Quran” dan copy langsung terverifikasi; ortu tidak mendapat aksi scan.
- [ ] **Step 6: Implementasikan scanner tracer**
  Batasi QR, kirim raw string sebagai `sheet_payload`, guard duplicate/busy, kontrol kamera, state permission/error, serta input manual hanya debug/emulator.
- [ ] **Step 7: Implementasikan form dan hasil**
  Tampilkan identitas dari server, dropdown surat, ayat, halaman/catatan opsional, preview, submit tunggal, hasil status, dan scan berikutnya.
- [ ] **Step 8: Jalankan test tracer sampai GREEN**
  Run: `flutter test test/quran_barcode_test.dart`

### Task 6: Quality gates backend dan Flutter

**Files:** seluruh perubahan Task 1–5.

**Interfaces:** menghasilkan bukti terbaru, bukan perubahan fitur baru.

- [ ] **Step 1: Format dan test backend terfokus**
  Run Pint pada controller/service/routes/test baru, lalu jalankan `CalendarApiTest`, `QuranBarcodeApiTest`, dan `BinaanKelasSekolahApiTest`.
- [ ] **Step 2: Jalankan suite PHPUnit penuh dan bandingkan baseline**
  Catat total test/assertion/error/failure. Jika merah, buktikan file baru bukan regresi menggunakan stash scoped seperti panduan skill; pulihkan stash setelah pembanding.
- [ ] **Step 3: Analyze dan seluruh test Flutter**
  Run: `flutter analyze` dan `flutter test`; hasil yang diterima adalah exit 0.
- [ ] **Step 4: Build APK emulator**
  Run: `flutter build apk --debug --dart-define=PKG_API_BASE=http://10.0.2.2:8010`.
- [ ] **Step 5: Install dan launch bersih**
  `adb install -r`, `am force-stop`, lalu launch package `id.pkgenerus.pkgenerus_app`; verifikasi package dan PID.

### Task 7: Verifikasi emulator lintas peran

**Files:** tidak ada perubahan produksi kecuali regression fix yang ditemukan melalui TDD.

**Interfaces:** menghasilkan bukti UI/API dan daftar keterbatasan optik.

- [ ] **Step 1: Pastikan backend lokal aktif dan API host merespons**
- [ ] **Step 2: Uji kalender staff/pamong**
  Login dummy, buka Lainnya → Kalender, ganti tanggal/bulan/filter, cocokkan event dengan curl token.
- [ ] **Step 3: Uji scanner presensi**
  Buka Presensi → Scan QR; verifikasi permission dan preview. Gunakan input debug/no-camera hanya bila preview virtual memicu ANR; uji payload valid, invalid, expired, dan duplikat terhadap API.
- [ ] **Step 4: Uji siswa**
  Kalender hanya data sendiri; Quran → Scan lembar; identify/store menghasilkan pending.
- [ ] **Step 5: Uji pamong tracer**
  Menu Tracer Quran; lembar binaan berhasil verified, luar binaan ditolak.
- [ ] **Step 6: Uji orang tua**
  Kalender anak tampil read-only; tidak ada scanner tracer.
- [ ] **Step 7: Cek logcat**
  Pastikan tidak ada Flutter exception/crash baru; dokumentasikan bahwa scan optik HP fisik masih acceptance terpisah bila perangkat tidak tersedia.

### Task 8: Final review tanpa commit

**Files:** spec, plan, seluruh diff lokal.

- [ ] **Step 1: Jalankan `git diff --check` pada kedua repo**
- [ ] **Step 2: Audit daftar file berubah terhadap scope**
  Tidak boleh ada `.env`, secret, APK, `build/`, `.dart_tool/`, atau file kredensial.
- [ ] **Step 3: Cocokkan setiap kriteria selesai spec dengan bukti test/emulator**
- [ ] **Step 4: Laporkan hasil dan blocker nyata**
  Jangan commit/push/deploy. Minta acceptance test HP fisik bila scan optik belum bisa dibuktikan.
