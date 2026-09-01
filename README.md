# PKGenerus Mobile App (Flutter)

Klien mobile/web untuk sistem **Pembinaan Karakter Generus (PKGenerus)**.
Aplikasi ini **tidak punya database sendiri** — seluruh data dibaca dari backend
Laravel melalui `/api/v1` dengan autentikasi Sanctum bearer token.

- Backend (repo terpisah): `pembinaan-karakter-generus` (Laravel 11, PHP 8.2)
- Klien ini: Flutter (Dart SDK `^3.13.2`), Material 3, Riverpod + GoRouter + Dio
- Rancangan lengkap, peta layar, kontrak endpoint, dan daftar gap API:
  [`docs/RANCANGAN-FLUTTER.md`](docs/RANCANGAN-FLUTTER.md)

## Aktor dan cakupan

| Aktor | Login | Cakupan |
|---|---|---|
| Pamong / staff / admin | `POST /api/v1/login` (field `username`) | binaan, presensi, materi, tugas, laporan |
| Orang tua | `POST /api/v1/ortu/login` (`username` + password) | monitoring anak, verifikasi |
| Siswa | `POST /api/v1/siswa/login` (field `nis`) | tugas, quran, gamifikasi, presensi |

## Fitur yang sudah berjalan

- Autentikasi 3 aktor + refresh token proaktif, satu sumber state (`AuthController`)
- Dashboard per aktor, presensi (statistik + scanner QR), materi & folder materi
- Tugas PKG (daftar, detail, riwayat, komentar), Quran (progres + barcode sheet)
- Binaan pamong & kelas sekolah (`/binaan-pamong`, `/kelas-sekolah`)
- Gamifikasi: badge, arcade bertempo, streak
- Kalender kegiatan, notifikasi verifikasi (local notification watcher)
- **Fitur Server** (`/fitur-server`): dashboard 10 fitur sisi server yang datanya
  dibaca riil dari DB Laravel via `GET /api/v1/mobile/fitur-server`

10 fitur yang diringkas endpoint tersebut: chat siswa/ortu/pamong, push
notification server, biometrik/WebAuthn, profil lengkap + foto, jurnal RPP &
target materi, presensi wajah, sertifikat & reward, Quran lanjutan, laporan
penyaksian, dan pendaftaran generus.

## Struktur

```
lib/
  main.dart                     ProviderScope + MaterialApp.router
  app/                          providers.dart (wiring), router.dart, theme.dart
  core/
    api_config.dart             base URL + timeout (dart-define)
    network/                    ApiClient (Dio), ApiResult, mapper error
    storage/                    session store (flutter_secure_storage)
    notifications/              watcher verifikasi
  features/<fitur>/
    data/                       repository + model (parse JSON API)
    application/                provider Riverpod
    presentation/               layar
  shared/widgets/               komponen lintas fitur
test/                           unit + widget test (payload nyata dari backend)
```

Konvensi tiap fitur: `data/` (repository + model) → `application/` (provider) →
`presentation/` (layar). Repository selalu mengembalikan `ApiResult<T>` supaya
error API tampil sebagai pesan Indonesia + tombol coba lagi (fail-visible).

## Menjalankan

Toolchain portabel dimuat lebih dulu (khusus mesin dev penulis):

```bash
source /e/hermes/scripts/env.sh
```

Backend harus hidup. Cek cepat:

```bash
curl --noproxy '*' -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8010/api/v1/kelas
```

Lalu:

```bash
# Web — paling cepat untuk uji API
flutter run -d chrome

# Emulator Android (10.0.2.2 = alias host laptop dari dalam emulator)
flutter run --dart-define=PKG_API_BASE=http://10.0.2.2:8010

# HP fisik satu Wi-Fi; backend perlu: php artisan serve --host=0.0.0.0 --port=8010
flutter run --dart-define=PKG_API_BASE=http://<IP-LAN-laptop>:8010
```

Base URL default `http://127.0.0.1:8010` dan bisa dioverride lewat
`--dart-define=PKG_API_BASE=...`. Alamat backend yang aktif ditampilkan di layar
login, jadi salah target langsung kelihatan.

### Build & install APK debug

```bash
flutter build apk --debug --dart-define=PKG_API_BASE=http://<IP-LAN-laptop>:8010
flutter install -d <serial-device> --debug
```

APK: `build/app/outputs/flutter-apk/app-debug.apk`
Application id: `id.pkgenerus.pkgenerus_app`

## Verifikasi

```bash
flutter analyze
flutter test
```

Status terakhir yang diverifikasi (2026-09-01): `flutter analyze` bersih,
`flutter test` 93 tes lulus, build APK debug sukses, terinstal dan berjalan di
perangkat Android fisik (Infinix X6853, Android 16).

Tes memakai potongan payload nyata dari backend, jadi perubahan bentuk respons
API akan langsung membuat tes gagal — itu memang disengaja sebagai alarm
kontrak API.

## Akun tester (khusus DB lokal/dev)

`tester_admin`, `tester_pamong`, `tester_ortu` — password seragam untuk seeding
lokal saja. **Jangan pernah dipakai atau dibuat di server produksi.**
Kredensial produksi tidak disimpan di repo ini.

## Catatan keamanan

- Token disimpan lewat `flutter_secure_storage`, tidak pernah di plain prefs.
- Tidak ada API key/secret di dalam repo. Konfigurasi runtime lewat `dart-define`.
- Backend tetap penentu otorisasi; menu yang tidak diizinkan menampilkan alasan
  penolakan dari server, bukan asumsi klien.
