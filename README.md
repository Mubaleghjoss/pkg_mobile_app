# pkgenerus_app

Klien mobile/web PKGenerus. Backend tetap Laravel (`E:\hermes\pkgenerus`) dan
tidak diubah — aplikasi ini hanya konsumen `/api/v1` dengan Sanctum bearer token.

Rancangan lengkap, peta layar, kontrak endpoint, dan gap API: `docs/RANCANGAN-FLUTTER.md`.

## Menjalankan

Toolchain portabel harus dimuat lebih dulu:

```bash
source /e/hermes/scripts/env.sh
```

Backend lokal (MariaDB :3307 + Laravel :8010) harus hidup. Cek cepat:

```bash
curl --noproxy '*' -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8010/api/v1/kelas
```

Lalu jalankan aplikasi:

```bash
# Web (paling cepat untuk uji API)
flutter run -d chrome

# Emulator Android — 10.0.2.2 adalah alias host laptop dari dalam emulator
flutter run --dart-define=PKG_API_BASE=http://10.0.2.2:8010

# HP fisik satu Wi-Fi (backend perlu: php artisan serve --host=0.0.0.0 --port=8010)
flutter run --dart-define=PKG_API_BASE=http://<IP-LAN-laptop>:8010
```

Alamat backend yang sedang aktif ditampilkan di layar login.

## Akun tester

| Username | Password | Role | Cakupan |
|---|---|---|---|
| `tester_admin` | `tester123` | admin | semua menu |
| `tester_pamong` | `tester123` | teacher | siswa + presensi |
| `tester_ortu` | `tester123` | student | presensi saja (menu Siswa sengaja 403) |

## Verifikasi

```bash
flutter analyze
flutter test
```

Keduanya bersih pada 2026-08-30 (11 tes lulus). Tes memakai potongan payload
nyata dari backend lokal, jadi perubahan bentuk respons API akan langsung
membuat tes gagal.
