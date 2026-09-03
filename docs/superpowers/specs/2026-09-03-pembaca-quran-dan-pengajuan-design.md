# Pembaca Al-Qur'an dan Pengajuan Bacaan — Design

Tanggal: 2026-09-03
Status: disetujui

## Tujuan

Menggabungkan pembaca Al-Qur'an ke menu Qur'an yang sudah ada, menyimpan posisi terakhir dan bookmark, serta mengajukan rentang bacaan langsung untuk diverifikasi pamong tanpa mewajibkan scan lembar.

## Arsitektur layar

Route `/quran` menjadi container dua tab:

1. `Baca Al-Qur'an` — katalog, pencarian, reader, posisi terakhir, bookmark, dan pengajuan.
2. `Progres & Riwayat` — progres khatam dan entri yang sekarang sudah tersedia.

Tombol `Scan lembar` tetap tersedia sebagai alternatif bagi pengguna mushaf cetak. Tidak dibuat menu Qur'an kedua di Lainnya.

## Dataset bacaan

Teks Al-Qur'an memakai dataset terverifikasi, berlisensi sesuai distribusi, memiliki sumber dan versi yang didokumentasikan, serta checksum. Dataset dibundel lokal (misalnya SQLite/JSON terkompresi) sehingga bacaan tersedia offline. Teks Arab tidak diambil dari API acak saat runtime dan tidak diedit otomatis.

Sebelum implementasi dataset, plan wajib mencatat sumber, versi, lisensi, jumlah 114 surah, jumlah ayat per katalog, checksum artefak, dan test integritas. Bila verifikasi/lisensi belum dapat dipenuhi, pembaca teks tidak boleh dirilis dengan data yang belum tervalidasi.

## Pengalaman membaca

- daftar 114 surah dan pencarian nama/nomor;
- teks Arab RTL, nomor ayat, font yang dapat diperbesar/diperkecil;
- scroll/posisi ayat yang stabil;
- `Lanjutkan bacaan terakhir`;
- bookmark ayat;
- loading tidak bergantung jaringan untuk isi ayat.

Posisi terakhir dan bookmark disimpan lokal per identitas akun, bukan global perangkat. Logout tidak membocorkan posisi antar-akun. Sinkronisasi server untuk bookmark tidak diperlukan pada rilis awal.

## Sesi dan rentang bacaan

Saat reader dibuka dari posisi tertentu, aplikasi mencatat titik awal sesi. Posisi akhir mengikuti ayat terakhir yang secara eksplisit dipilih/dikonfirmasi pengguna, bukan sekadar item yang sempat terlihat ketika scroll cepat.

Tombol `Ajukan bacaan ini` menampilkan preview fail-closed:

- tanggal;
- surat dan ayat awal;
- surat dan ayat akhir;
- halaman mushaf bila mapping terverifikasi tersedia;
- catatan opsional.

Pengguna mengonfirmasi sebelum POST. Endpoint pencatatan mobile yang sudah ada membuat entri `source=mobile`, `submitted_by_type=siswa`, dan status `pending`. Orang tua tetap read-only. Hasil masuk antrean verifikasi pamong yang sudah ada dan muncul pada Progres & Riwayat sebagai pending/verified/rejected.

Retry setelah respons ambigu harus mencegah duplikasi melalui idempotency key klien yang divalidasi/disimpan backend, atau lookup aman terhadap request yang sama. Implementasi tidak boleh menganggap request gagal hanya karena respons terputus.

## Status dan galat

Reader tetap dapat digunakan offline. Pengajuan saat offline disimpan sebagai draft lokal yang terlihat jelas dan baru dikirim setelah pengguna menekan coba lagi; tidak mengklaim sudah diajukan. Validasi mencegah akhir sebelum awal dan ayat melebihi katalog.

## Pengujian

- Integritas dataset: 114 surah, jumlah ayat, karakter Arab, checksum dan versi.
- Unit: pencarian, posisi per akun, bookmark, rentang lintas surah, font preference, draft offline.
- Backend: pengajuan pending, validasi rentang, ortu ditolak, idempotensi, antrean pamong.
- Widget: dua tab, lanjutkan posisi, reader RTL, preview/konfirmasi/status.
- Emulator end-to-end: baca, tutup/restart, lanjutkan, ajukan, lalu verifikasi dari alur pamong dan lihat status berubah.

## Batasan

Tidak mengganti sistem verifikasi, tidak otomatis menandai ayat selesai karena hanya terlihat, tidak menghapus scan tracer, dan tidak merilis dataset yang sumber/lisensi/integritasnya belum terbukti.