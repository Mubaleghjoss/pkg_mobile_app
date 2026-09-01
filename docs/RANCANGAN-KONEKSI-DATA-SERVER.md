# Rancangan Koneksi App Mobile ke Data Server

Dokumen ini menjawab dua pertanyaan:

1. Kalau app Flutter ini dihubungkan ke data server (produksi), apa bisa?
2. Apa ada yang harus disesuaikan di sisi data server?

Semua pernyataan di bawah berasal dari pembacaan kode nyata di `E:/hermes/pkgenerus_app`
dan `E:/hermes/pkgenerus`, bukan asumsi. Yang belum terverifikasi ditandai eksplisit.

---

## 1. Jawaban singkat

Bisa. Secara arsitektur tidak ada penghalang, karena app ini sudah 100% konsumen HTTP
tanpa database lokal, dan base URL-nya sudah bisa diganti tanpa mengubah kode.

Tapi belum bisa langsung diarahkan ke produksi apa adanya. Ada 6 hal di sisi server
yang harus disesuaikan lebih dulu (bagian 4), dan yang paling mengikat adalah HTTPS.

---

## 2. Kenapa bisa: bukti dari kode

### App tidak punya sumber data sendiri

`lib/core/api_config.dart`:

    static const String baseUrl = String.fromEnvironment(
      'PKG_API_BASE',
      defaultValue: 'http://127.0.0.1:8010',
    );

    static String get apiV1 => '$baseUrl/api/v1';

Artinya pindah server = ganti satu nilai saat build:

    flutter build apk --release --dart-define=PKG_API_BASE=https://<domain-produksi>

Tidak ada SQLite, tidak ada seed data, tidak ada mock yang dipakai di jalur produksi.
Semua repository di `lib/features/*/data/` memanggil `ApiConfig.apiV1`.

### Kontrak API sudah cocok

Backend mengekspos 74 rute di bawah `api/v1` (diverifikasi dengan
`php artisan route:list --path=api/v1`). App sudah memakai antara lain:

| Kebutuhan app | Endpoint server |
|---|---|
| Login pamong/pengurus | `POST api/v1/login` |
| Login siswa | `POST api/v1/siswa/login` |
| Login orang tua | `POST api/v1/ortu/login` |
| Identitas akun | `GET api/v1/me`, `GET api/v1/siswa-account/me` |
| Perpanjang token | `POST api/v1/refresh` |
| Ganti password | `POST api/v1/change-password` |
| Dashboard | `GET api/v1/dashboard/stats`, `/dashboard/recent-activities` |
| Tugas PKG | `GET api/v1/tugas-pkg`, `/summary`, `/history` |
| Karakter luhur | `GET api/v1/karakter-luhur`, `/{slug}` |
| Materi | `GET api/v1/materi`, `/folders`, `/{materi}` |
| Presensi | `GET/POST api/v1/presensi`, `/statistics`, `/scan-qr` |
| Qur'an | `GET api/v1/quran/entries`, `/progress`, `/surahs` |
| Gamifikasi | `GET api/v1/gamifikasi/badges`, `/ringkasan`, `/leaderboard` |
| Monitoring ortu | `GET api/v1/ortu/ringkasan`, `/presensi`, `/quran`, `/tugas` |
| Verifikasi pamong | `GET api/v1/pamong/verifikasi` + verify/bulk |
| Binaan pamong | `GET api/v1/binaan-pamong` |
| Agregasi 10 fitur | `GET api/v1/mobile/fitur-server` |

### Autentikasi sudah sesuai model server

Server memakai Sanctum bearer token dengan masa berlaku 7 hari
(`config/sanctum.php`: `SANCTUM_TOKEN_EXPIRATION` default 10080 menit).
App menyimpan token dan me-refresh proaktif bila sisa umur < 1 hari
(`ApiConfig.refreshThreshold`). Jadi tidak ada perubahan alur login yang dibutuhkan.

---

## 3. Yang perlu disiapkan di app (kecil)

- Build produksi wajib menyertakan `--dart-define=PKG_API_BASE=https://<domain>`.
  Default `http://127.0.0.1:8010` hanya untuk pengembangan.
- Timeout saat ini 15s connect / 30s receive. Shared hosting cPanel lebih lambat dari
  `artisan serve` lokal; kalau produksi sering timeout, naikkan `receiveTimeout`.

---

## 4. Yang HARUS disesuaikan di sisi data server

Ini daftar prioritas. Nomor 1 dan 2 bersifat pemblokir.

### 4.1 HTTPS (pemblokir)

Sekarang base URL uji adalah `http://10.181.170.50:8010` — HTTP tanpa TLS.
Android modern memblokir cleartext traffic secara default, dan mengirim bearer token
lewat HTTP di jaringan publik berarti token bisa dicuri di tengah jalan.

Yang harus dilakukan: sajikan API di `https://` dengan sertifikat valid, lalu set
`APP_URL` ke domain HTTPS itu. Jangan menambahkan pengecualian cleartext di app
sebagai jalan pintas untuk produksi.

### 4.2 CORS dan Sanctum stateful domain

`config/cors.php` saat ini:

    'allowed_origins' => explode(',', env('CORS_ALLOWED_ORIGINS', 'http://localhost:3000,http://localhost:5173')),
    'supports_credentials' => env('CORS_SUPPORTS_CREDENTIALS', true),

Default-nya masih localhost dev. Untuk produksi:

- Set `CORS_ALLOWED_ORIGINS` ke domain yang benar-benar dipakai. Kalau kliennya hanya
  APK Android (bukan Flutter Web), CORS tidak dibutuhkan untuk app — jangan dilonggarkan
  ke `*`, terutama karena `supports_credentials` bernilai true.
- Set `SANCTUM_STATEFUL_DOMAINS` hanya untuk domain web, bukan untuk app mobile.
  App memakai bearer token, bukan cookie session.

### 4.3 Portabilitas SQL antara MySQL produksi dan SQLite test

Ini bukan teori — sudah ketemu dan sudah diperbaiki di sesi ini. Dua controller memakai
`DATE_FORMAT(tanggal, '%Y-%m')` yang hanya ada di MySQL/MariaDB dan pecah di SQLite:

- `app/Http/Controllers/OrtuDashboardController.php`
- `app/Http/Controllers/Api/OrtuMonitoringController.php`

Keduanya kini memakai `SUBSTR(tanggal, 1, 7)` yang jalan di kedua engine. Ini relevan
langsung ke app karena jalur `api/v1/ortu/*` dipakai fitur monitoring orang tua.

Aturan ke depan: hindari fungsi khusus MySQL di query yang juga dilewati test.

### 4.4 Push notification belum benar-benar ada di server

App saat ini memakai local notification watcher — artinya notifikasi baru muncul saat
app dibuka dan melakukan polling, bukan didorong server. Jadi "notifikasi realtime"
belum tersedia.

Tabel yang ada adalah tabel PWA push (`2026_07_18_090000_create_pwa_push_tables.php`),
yang dirancang untuk Web Push, bukan untuk FCM Android.

Untuk realtime di app perlu ditambahkan di server:

- kredensial FCM (server key / service account),
- tabel device token per akun (siswa/ortu/pamong) beserta endpoint registrasi dan
  pencabutan token saat logout,
- pemicu pengiriman pada event yang relevan (tugas baru, verifikasi, jadwal).

Sampai itu ada, jangan menjanjikan push realtime ke pengguna.

### 4.5 Sertifikat dan reward belum punya tabel terkonfirmasi

Dari 10 fitur yang disinkronkan, sembilan punya tabel nyata yang sudah diverifikasi
lewat file migration (chat, pwa push, WebAuthn, profil, RPP/materi, `face_profiles`,
Qur'an lanjutan, laporan penyaksian, `generus_registrations`).

Untuk sertifikat & reward, belum ada model/tabel yang saya bisa tunjuk. Jadi bagian itu
di endpoint agregasi masih berupa kontrak/status, bukan data. Kalau fitur ini mau
dipakai, server perlu tabel sertifikat lebih dulu.

### 4.6 Pengamanan endpoint agregasi

`GET api/v1/mobile/fitur-server` mengembalikan ringkasan banyak modul sekaligus.
Nilai praktisnya tinggi, tapi konsekuensi kebocorannya juga besar: satu token yang
jatuh ke tangan salah membuka gambaran lintas modul.

Yang perlu dipastikan sebelum produksi:

- endpoint berada di belakang auth (resolusi token siswa/pamong),
- ada rate limit khusus, seperti rute lain yang sudah memakai `throttle`,
- respons hanya memuat data dalam cakupan aktor yang login, bukan seluruh server.

---

## 5. Urutan kerja yang disarankan

1. Siapkan domain HTTPS untuk API produksi, set `APP_URL`.
2. Rapikan `CORS_ALLOWED_ORIGINS` dan `SANCTUM_STATEFUL_DOMAINS`.
3. Uji jalur read dulu (login, dashboard, materi, tugas, presensi read) dari APK yang
   dibuild dengan `PKG_API_BASE` produksi.
4. Baru aktifkan jalur tulis (presensi store, submit tugas, setor Qur'an).
5. Tambahkan FCM bila push realtime memang diinginkan.
6. Tambahkan tabel sertifikat bila fitur sertifikat/reward mau dipakai.

---

## 6. Catatan kejujuran

- Angka 74 rute `api/v1` dan daftar endpoint di atas berasal dari `route:list` nyata.
- Perbaikan `DATE_FORMAT` sudah dijalankan dan test terkait lulus.
- Belum ada pengujian app melawan server produksi. Semua verifikasi sejauh ini melawan
  backend lokal (`artisan serve` port 8010) dan MariaDB lokal port 3307.
- Klaim "bisa dihubungkan" adalah kesimpulan arsitektural dari kode, bukan hasil uji
  end-to-end ke produksi.
