# Materi PDF dan QR Tracer — Design

Tanggal: 2026-09-03
Status: disetujui
Repo aplikasi: `E:/hermes/pkgenerus_app`
Repo backend: `E:/hermes/pkgenerus`

## Tujuan

Memastikan materi yang memiliki video dan PDF menampilkan keduanya, PDF dapat dibaca langsung di aplikasi, dan QR lembar tracer Al-Qur'an mengikuti alur identifikasi serta pencatatan yang sudah bekerja di PWA.

## Temuan terverifikasi

- API produksi untuk akun siswa melaporkan 20 materi mempunyai PDF melalui `pdf_count`, tetapi detail materi mengembalikan `pdfs: []`.
- Data lama `materi.pdf_path` berbentuk objek seperti `{path, ...}`, sedangkan serializer `Api/MateriController::detail()` hanya menerima string.
- Flutter sudah memodelkan daftar PDF tetapi belum memiliki pembaca; tindakan yang ada hanya menyalin URL.
- PWA menerima payload langsung dan URL `/sq/<public-code>`, sedangkan Android hanya menerima payload langsung.

## Desain PDF

Backend menormalisasi setiap item `pdf_path` tanpa memigrasikan data secara destruktif:

- string diperlakukan sebagai path;
- objek mengambil `path` dan metadata nama bila tersedia;
- item invalid dilewati;
- URL absolut, nama dokumen, indeks, dan `exists` dikirim ke klien;
- video dan PDF merupakan koleksi independen sehingga salah satunya tidak menyembunyikan yang lain.

Flutter menampilkan bagian `Video` dan `Dokumen PDF` secara terpisah. Menekan dokumen membuka layar pembaca in-app dengan loading, retry, nomor halaman, navigasi halaman, dan zoom. Berkas boleh dicache sementara. Browser eksternal hanya fallback eksplisit jika reader gagal.

## Desain QR tracer

Normalizer Dart menerima tiga bentuk input:

1. payload `PKGQURAN`, `PKGQ`, `PKGQMB`, atau `PKGQM` yang valid;
2. URL absolut dengan path `/sq/<kode-44-karakter>`;
3. path relatif `/sq/<kode-44-karakter>`.

Kode publik 44 karakter didekode menggunakan algoritme yang sama dengan `resources/js/quran-scan.js`: byte pertama menentukan prefix, 16 byte berikutnya UUID, dan 16 byte terakhir token. Input lain ditolak sebelum dikirim ke API.

Setelah `identifyBarcode` berhasil, layar menampilkan:

- status `Identitas sesuai`;
- nama siswa, NIS tersamarkan, kelas, dan kelompok;
- form surat/ayat awal-akhir, halaman opsional, dan catatan;
- preview sebelum simpan.

Siswa hanya boleh memakai lembar sendiri; pamong hanya siswa binaan. Simpan siswa tetap `pending`, sedangkan aturan verifikasi staff mengikuti backend. `flow_id` dan perilaku backend yang sudah idempoten dipertahankan agar tap ganda tidak membuat entri kedua.

## Penanganan galat

Pesan UI dibedakan untuk QR tidak dikenali, lembar kedaluwarsa/tidak aktif, lembar milik akun lain, jaringan gagal, dan validasi rentang ayat. PDF membedakan metadata kosong, berkas tidak ada, unduhan gagal, dan dokumen gagal dirender.

## Pengujian

- PHPUnit: format PDF string dan objek lama, URL/nama/exists, video+PDF bersamaan, item invalid.
- Flutter unit/widget: normalizer payload/URL/relative URL, QR invalid, identitas dan form, PDF dan video tampil bersamaan, navigasi reader dan galat.
- Emulator: login siswa, buka materi nyata yang memiliki video+PDF, baca PDF, scan QR lembar nyata, simpan lalu pastikan satu entri pending.

## Batasan

Tidak mengubah isi materi, tidak memigrasikan `pdf_path` secara massal, tidak menaruh kredensial pada test/commit, dan tidak menghapus alur scan lama.