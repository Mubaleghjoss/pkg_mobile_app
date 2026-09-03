# Profil dan Branding — Design

Tanggal: 2026-09-03
Status: disetujui

## Tujuan

Foto profil mobile memakai data dan berkas yang sama dengan website, dapat dilihat/diperbarui dari Profil Saya sesuai hak akses, dan seluruh turunan logo aplikasi konsisten dengan logo server.

## Temuan terverifikasi

- Model `Siswa` memiliki `foto_path` dan accessor `foto_url`; website sudah dapat mengunggah JPEG/PNG/JPG maksimal 2 MB.
- API `siswa-account/me` belum mengirim `foto_url`.
- Profil mobile menampilkan logo PKG sebagai avatar pengguna.
- `public/images/icons/pkg-logo-512.png` server dan `assets/branding/pkg-logo.png` mobile identik byte-for-byte; aset trimmed berbeda karena pemangkasan margin untuk tampilan.

## Kontrak profil

Profile API siswa/ortu menambahkan `foto_url` absolut dan cache-busted dari accessor model. `AuthSession` menyimpan field foto dan mampu memperbarui seluruh field profil setelah refresh tanpa kehilangan token/aktor.

Endpoint multipart mobile khusus siswa menerima field `foto` dengan aturan yang sama seperti web:

- JPEG/PNG/JPG;
- maksimal 2 MB;
- authorization token siswa;
- akun orang tua read-only.

Backend memakai penyimpanan/path canonical yang sama dengan website, menghapus berkas lama secara aman hanya setelah berkas baru valid tersimpan, dan mengembalikan profil terbaru.

## UX profil

- Avatar menampilkan foto jaringan bila tersedia; fallback berupa inisial nama.
- Menekan avatar membuka preview ukuran besar.
- Siswa melihat aksi `Ganti foto`: galeri, crop persegi, kompres, preview, konfirmasi, upload.
- Setelah sukses, provider/sesi disegarkan dan URL cache baru langsung tampil tanpa login ulang.
- Orang tua dapat melihat foto anak tetapi tidak melihat aksi edit.
- Galat izin galeri, tipe/ukuran, jaringan, dan upload ditampilkan dalam Bahasa Indonesia.

## Branding

`public/images/icons/pkg-logo-512.png` menjadi acuan canonical. Salinan sumber aplikasi diverifikasi checksum, lalu skrip generator deterministik menghasilkan:

- launcher icon legacy;
- adaptive foreground/background;
- splash logo seluruh density;
- aset logo tampilan/wordmark yang sudah dipangkas secara aman.

Safe area menjaga emblem tidak terpotong oleh mask launcher. Rasio tidak diregangkan. Warna background diambil dari identitas server. File hasil generator yang memang source-controlled diperbarui; folder build tidak dijadikan sumber.

## Pengujian

- PHPUnit: `foto_url` pada login/me, upload valid, tipe/ukuran invalid, ortu ditolak, penggantian aman.
- Flutter unit/widget: serialisasi sesi backward-compatible, avatar jaringan/fallback, preview, action sesuai aktor, refresh setelah upload.
- Script: checksum sumber dan keberadaan seluruh density/aset.
- Emulator: foto akun yang sama terlihat seperti website, ganti foto dan lihat perubahan di kedua klien, launcher/splash tidak crop atau blur.

## Batasan

Tidak menyimpan data gambar di sesi selain URL, tidak membuka edit profil lengkap di luar foto, tidak menampilkan logo sebagai foto pengguna, dan tidak menimpa perubahan lokal asing pada konfigurasi Android/pubspec.