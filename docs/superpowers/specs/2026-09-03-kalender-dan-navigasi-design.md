# Kalender Interaktif dan Navigasi — Design

Tanggal: 2026-09-03
Status: disetujui

## Tujuan

Kalender harus muncul pada klik pertama dari menu Lainnya, dan setiap kegiatan dapat ditekan untuk menampilkan detail seperti pengalaman PWA.

## Temuan terverifikasi

- Kalender adalah route di dalam shell dan berada pada daftar menu `extrasFor`.
- `AnimatedSwitcher` menggunakan key indeks tab utama. Route ekstra mendapat fallback indeks 0, sehingga widget lama dapat dipertahankan walaupun lokasi route berubah.
- Model `CalendarEvent` sudah menerima map `details`, tetapi tile hanya menampilkan judul dan waktu tanpa handler tap.
- API kalender sudah menyaring scope berdasarkan aktor dan membuang URL admin.

## Navigasi

Identitas konten dan animasi shell memakai `matchedLocation`, bukan hanya indeks tab utama. Indeks tab tetap dipakai untuk arah animasi dan NavigationBar, tetapi route ekstra memiliki key route unik.

Ketika Kalender dipilih:

- floating menu ditutup;
- `context.go('/kalender')` dilakukan;
- `CalendarScreen` dirender pada interaksi pertama;
- slot `Lainnya` tetap tersorot;
- Back kembali ke tab utama pertama tanpa menutup aplikasi.

Perpindahan berulang Kalender → Materi → Kalender tidak boleh menampilkan child lama atau membutuhkan klik kedua.

## Interaksi kalender

Menekan tanggal memilih tanggal dan menampilkan agenda pada tanggal tersebut. Setiap tile pada `Agenda tanggal terpilih` dan `Agenda terdekat` dapat ditekan untuk membuka modal bottom sheet/detail pop-up.

Detail selalu menampilkan:

- judul;
- tanggal dan rentang waktu;
- status sepanjang hari;
- kategori kegiatan.

Map `details` dirender melalui formatter per jenis, dengan label Indonesia dan urutan stabil:

- presensi: status, masuk, keluar;
- tugas PKG: deadline, status pengumpulan, kategori, total bila diizinkan;
- karakter: jumlah dan daftar karakter;
- jadwal/materi RPP: `description` sebagai Deskripsi, `location` sebagai Lokasi, `contact_name` sebagai Narahubung, `contact_phone` sebagai Telepon, serta `materi_title` sebagai Materi.

Hanya key yang tercantum di atas yang boleh dirender. Key internal tidak ditampilkan mentah. URL admin, journal internal, token, ID sensitif, nilai null/kosong, dan struktur yang tidak dikenal tidak ditampilkan. Navigasi menuju materi/tugas bukan bagian rilis ini karena kontrak API saat ini tidak menyediakan target mobile yang terdefinisi.

## Penanganan galat

Loading/error kalender tetap memenuhi seluruh layar. Refresh tidak menghapus pilihan tanggal/filter. Modal detail tetap aman jika sebagian detail kosong. Event multi-hari ditampilkan dengan rentang mulai–selesai yang benar.

## Pengujian

- Widget/router: klik Kalender sekali langsung merender kalender, slot Lainnya tersorot, Back kembali dengan benar, navigasi berulang tidak stale.
- Unit: label/format detail tiap tipe, nilai null, key tidak dikenal, waktu dan all-day.
- Widget: tile tanggal terpilih dan terdekat membuka modal yang sama.
- Emulator: uji akun siswa pada bulan yang memiliki kegiatan nyata dan bandingkan detail dengan PWA.

## Batasan

Kalender tetap di menu Lainnya, bersifat read-only, dan backend tetap menentukan scope data setiap aktor.