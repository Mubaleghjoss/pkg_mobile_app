# Desain Kalender dan Scanner Kamera PKGenerus

Tanggal: 2026-09-01
Status: Menunggu tinjauan pengguna
Repositori: Flutter `pkgenerus_app` dan Laravel `pkgenerus`

## 1. Tujuan

Menambahkan tiga kemampuan aplikasi mobile tanpa menggandakan aturan domain server:

1. Kalender native read-only untuk pamong/admin, siswa, dan orang tua.
2. Memperbaiki akses dan membuktikan scanner QR presensi yang sudah ada.
3. Menambahkan scanner QR lembar Tracer Bacaan Al-Quran untuk pamong dan siswa.

Server tetap menjadi satu-satunya sumber kebenaran untuk cakupan data, validasi token/barcode, status verifikasi, dan pencegahan pengiriman ganda.

## 2. Ruang Lingkup

### Termasuk

- API v1 kalender terautentikasi dan berbasis peran.
- Layar kalender Flutter: bulan, kategori, agenda tanggal, dan agenda terdekat.
- Perbaikan visibilitas tombol Scan QR Presensi pada rute Presensi.
- Uji izin kamera, preview, parser, request API, serta hasil scanner presensi.
- API v1 identifikasi dan penyimpanan barcode lembar tracer.
- Scanner dan formulir rentang bacaan tracer untuk pamong dan siswa.
- Pengujian akses, validasi, idempotensi, analyze, test, build, install, dan emulator.

### Tidak termasuk pada tahap ini

- Membuat atau mengubah event kalender dari aplikasi.
- Foto lembar bacaan, OCR, atau konfirmasi hasil OCR.
- Scanner tracer untuk orang tua.
- Face attendance.
- FCM/push notification native.
- Generator lembar/PDF tracer dari aplikasi.
- Deploy produksi, commit, atau push.

## 3. Arsitektur Umum

Flutter memanggil endpoint API v1 dengan token Sanctum yang sudah digunakan aplikasi. Laravel menentukan aktor dari token dan mengembalikan data yang sudah dibatasi. Flutter tidak menerima seluruh data lalu menyaring hak akses di klien.

Komponen scanner kamera dapat memakai infrastruktur `mobile_scanner` yang sama, tetapi parser dan alur bisnis dipisahkan:

- Scanner presensi menerima payload QR siswa berformat PKG/JSON dan mengirim ke endpoint presensi.
- Scanner tracer menerima `sheet_payload` QR lembar dan menjalankan alur identifikasi lalu penyimpanan bacaan.

## 4. Kalender

### 4.1 Endpoint

`GET /api/v1/calendar/events?start=YYYY-MM-DD&end=YYYY-MM-DD`

Wajib `auth:sanctum`. Rentang tanggal divalidasi dan dibatasi, misalnya maksimum 93 hari, untuk mencegah kueri tanpa batas.

### 4.2 Cakupan per aktor

#### Pamong/admin

- Pamong: hanya ringkasan dan agenda siswa binaan aktif.
- Admin/non-pamong berhak: seluruh siswa aktif.
- Jenis event: ringkasan presensi, tugas PKG, tracer karakter, schedule reminder, jadwal presensi, materi/RPP, dan jadwal pengajar yang memang dapat dilihat aktor.

#### Siswa

- Presensi sendiri.
- Tugas PKG dan status pengumpulan sendiri.
- Tracer karakter sendiri.
- Schedule reminder untuk siswa/all.
- Jadwal presensi dan event siswa lain yang sudah disediakan domain kalender server.

#### Orang tua

- Data kalender anak yang terikat pada token orang tua.
- Read-only.
- Tidak mendapat URL/aksi tulis.

### 4.3 Kontrak respons

Respons distandardisasi sebagai:

```json
{
  "success": true,
  "data": [
    {
      "id": "string",
      "title": "string",
      "start": "ISO-8601",
      "end": "ISO-8601|null",
      "all_day": true,
      "type": "string",
      "color": "#RRGGBB",
      "details": {}
    }
  ],
  "meta": {
    "start": "YYYY-MM-DD",
    "end": "YYYY-MM-DD",
    "actor": "staff|siswa|ortu",
    "scope": "semua|binaan|sendiri|anak"
  }
}
```

`details` hanya memuat field aman untuk aktor. URL web internal tidak dianggap sebagai navigasi mobile.

### 4.4 UI Flutter

- Menu Kalender tersedia di “Lainnya” untuk semua aktor.
- Tampilan awal bulan berjalan.
- Penanda warna pada tanggal yang memiliki event.
- Filter kategori event.
- Daftar agenda tanggal terpilih.
- Bagian agenda terdekat.
- Refresh dan state loading/error/empty mengikuti pola aplikasi.
- Penggantian bulan memuat rentang bulan tersebut, bukan seluruh tahun.

## 5. Scanner QR Presensi

### 5.1 Bug akses sekarang

Presensi adalah menu tambahan staff, bukan tab utama. `HomeShell._fabFor()` menghitung path dari indeks tab utama sehingga ketika rute aktif `/presensi`, path yang diperiksa tetap `/`. Akibatnya FAB Scan QR tidak terlihat.

### 5.2 Perbaikan

- Penentuan FAB memakai `state.matchedLocation` atau aksi scan ditaruh eksplisit di layar Presensi.
- Tombol hanya tampil untuk aktor staff yang dapat membuka Presensi.
- Rute `/scan-qr` tetap halaman scanner tersendiri.

### 5.3 Perilaku scanner

- Kamera belakang sebagai default; tombol ganti kamera tersedia.
- Hanya format QR untuk presensi.
- Satu payload diproses sekali sampai reset.
- Payload invalid tidak dikirim ke server.
- Respons sukses menampilkan nama, NIS, status, dan jam masuk.
- Token invalid/kedaluwarsa, duplikat, rate limit, transport error, dan izin kamera ditolak menghasilkan pesan yang dapat ditindaklanjuti.
- Input manual tetap hanya pada build debug untuk pengujian emulator.

## 6. Scanner Tracer Bacaan

### 6.1 Aktor

- Siswa: hanya QR lembar miliknya; hasil `pending`.
- Pamong: hanya QR lembar siswa binaannya; hasil langsung `verified` dan mencatat verifier.
- Admin yang memiliki akses tracer dapat mengikuti perilaku operasional.
- Orang tua: read-only, tanpa scanner.

### 6.2 Endpoint

Dua endpoint terautentikasi:

1. `POST /api/v1/quran/barcode/identify`

Request:

```json
{"sheet_payload":"..."}
```

Respons:

```json
{
  "success": true,
  "data": {
    "flow_id": "random-token",
    "expires_at": "ISO-8601",
    "student": {
      "name": "...",
      "masked_nis": "...",
      "school_grade": "...",
      "group": "..."
    }
  }
}
```

2. `POST /api/v1/quran/barcode/store`

Request berisi `flow_id`, surat/ayat awal-akhir, opsional halaman awal-akhir, dan catatan.

Respons berisi pesan, `entry_id`, status, dan payload entri yang sudah distandardisasi.

### 6.3 Flow stateless mobile

Alur web sekarang menyimpan flow pada session. API mobile tidak memakai session web. Flow mobile disimpan server-side (cache atau tabel ringan) dengan:

- ID acak kuat.
- TTL 30 menit.
- Terikat pada aktor, ID aktor, konteks, lembar, dan siswa.
- Sekali pakai, tetapi idempotent: pengiriman ulang flow yang sudah selesai mengembalikan entri yang sama.
- Tidak menerima `siswa_id` dari klien sebagai sumber otoritatif.

### 6.4 UI Flutter

#### Siswa

Tombol “Scan lembar” pada layar Quran. Alur:

1. Scan QR lembar.
2. Tampilkan identitas siswa hasil server.
3. Isi surat dan ayat awal-akhir; akhir surat opsional bila sama.
4. Opsional halaman dan catatan.
5. Preview ringkas lalu simpan.
6. Tampilkan status menunggu verifikasi.

#### Pamong

Menu “Tracer Quran” di “Lainnya”. Tahap pertama berisi:

- Tombol scan lembar.
- Identitas siswa binaan hasil scan.
- Form rentang bacaan yang sama.
- Konfirmasi bahwa hasil langsung terverifikasi.
- Setelah berhasil, tampilkan hasil dan tombol scan berikutnya.

### 6.5 Format scanner

Lembar tracer menggunakan QR. Scanner tracer dapat dibatasi pada `BarcodeFormat.qrCode`. Payload tidak diparse sebagai QR presensi; dikirim sebagai string `sheet_payload` ke endpoint identify, lalu server memvalidasi signature/status lembar.

## 7. Keamanan dan Error Handling

- Semua endpoint baru memakai `auth:sanctum`.
- Hak akses diterapkan server-side.
- Flow tracer tidak dapat dipakai aktor lain, siswa lain, atau setelah kedaluwarsa.
- Lembar nonaktif/tidak valid dijawab tanpa membocorkan data pribadi.
- Pamong di luar binaan mendapat 403.
- Orang tua mendapat 403 untuk scanner/store.
- Kalender tidak mengirim field sensitif atau URL internal yang tidak dapat dipakai aplikasi.
- Scanner berhenti sementara saat request berlangsung dan dapat dilanjutkan setelah reset.
- Tidak ada data presensi/tracer yang disimpan offline sebagai antrean pada tahap ini.

## 8. Pengujian

### 8.1 Laravel

- Kalender: autentikasi wajib, validasi rentang, tiap aktor, batas binaan, orang tua-anak, serta bentuk event.
- Tracer: identify valid, invalid, nonaktif, milik siswa lain, di luar binaan, orang tua ditolak, flow kedaluwarsa, aktor berbeda, store valid, rentang invalid, dan double-submit idempotent.
- Jalankan test fitur baru, Pint, lalu suite penuh untuk membandingkan baseline yang sudah diketahui merah.

### 8.2 Flutter

- Parsing dan grouping event kalender.
- Perubahan bulan, tanggal terpilih, filter, empty/error state.
- FAB scanner presensi terlihat pada rute Presensi staff.
- Parser QR presensi, duplicate guard, dan ringkasan respons.
- Model/repository tracer identify/store.
- Form rentang surat/ayat dan validasi ayat terhadap katalog surah.
- Perbedaan copy/status pamong dan siswa.
- Orang tua tidak melihat scanner.

### 8.3 Emulator dan perangkat

Emulator:

- CAMERA permission grant/deny.
- Preview scanner berhasil dibuka.
- Input manual debug menguji presensi valid/invalid ke API.
- Input manual debug menguji sheet tracer valid/invalid ke API.
- Navigasi tiga aktor dan kalender.
- Analyze, seluruh test, build APK, install, force-stop, launch, dan cek logcat.

HP fisik:

- Scan optik QR presensi siswa.
- Scan optik QR lembar tracer.
- Kamera belakang/depan, izin pertama kali, izin ditolak, cahaya rendah, dan scan ulang.

Klaim “kamera bisa digunakan untuk scan” baru final setelah tes optik pada HP fisik. Sebelum itu laporan dibatasi pada “preview dan alur API terbukti di emulator”.

## 9. Urutan Implementasi

1. API dan test kalender.
2. Model/repository/UI kalender Flutter.
3. Perbaikan akses scanner presensi dan test.
4. API flow barcode tracer dan test.
5. Scanner/form tracer Flutter dan test.
6. Analyze/test/build.
7. Uji emulator seluruh peran.
8. Acceptance test optik HP fisik oleh pengguna atau perangkat yang tersedia.
9. Baru setelah semua disetujui: commit, repo private, dan push.

## 10. Kriteria Selesai

- Kalender menampilkan event benar dan terfilter untuk ketiga aktor.
- Staff dapat membuka scanner dari halaman Presensi.
- Preview kamera dan alur request presensi terbukti di emulator.
- Siswa dan pamong dapat scan/masukkan QR lembar tracer dan menyimpan sesuai status aktornya.
- Akses silang ditolak server.
- Analyze bersih, seluruh test perubahan lulus, APK terpasang dan navigasi teruji.
- Tidak ada commit, push, atau deploy tanpa instruksi eksplisit pengguna.
