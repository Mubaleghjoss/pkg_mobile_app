# Pembaca 29 Karakter dan WhatsApp — Design

Tanggal: 2026-09-03
Status: disetujui

## Tujuan

Menyajikan isi 29 Karakter secara terstruktur dan mudah dibaca, memisahkan Arab dari Indonesia, serta memungkinkan seluruh isi karakter dibagikan melalui WhatsApp.

## Sumber data

Endpoint detail karakter tetap menjadi sumber tunggal. Aplikasi tidak mengubah atau mengarang isi. Struktur tampilan dibentuk dari field definisi, deskripsi, dalil Al-Qur'an, dalil Hadis, hikmah, studi kasus, penerapan, dan tips amal.

## Parser presentasi

Parser murni memecah setiap bagian menjadi blok:

- paragraf;
- teks Arab;
- bullet;
- item bernomor.

Baris kosong menjadi batas paragraf. Awalan angka seperti `1.` atau `1)` menjadi item bernomor; `-`, `*`, dan `•` menjadi bullet. Deteksi Arab menggunakan rentang Unicode Arab dan ambang dominasi karakter, sehingga kutipan Arab dipisahkan dari kalimat Indonesia tanpa memotong konten secara sembarangan.

## Tampilan

- Blok Arab: RTL, rata kanan, font 26–30 sp, tinggi baris longgar.
- Blok Indonesia: LTR, rata kiri, ukuran body yang nyaman.
- Daftar: marker berada di kolom sendiri dengan hanging indent agar teks membungkus ke bawah, bukan memanjang ke samping.
- Paragraf: jarak vertikal jelas.
- Arab dan terjemahan berada dalam blok/kartu terpisah.
- Urutan halaman: definisi, penjelasan, dalil Al-Qur'an, dalil Hadis, hikmah, contoh, penerapan, tips, penutup; bagian kosong dilewati.

## Halaman penutup

Dua aksi independen tersedia:

1. `Tandai sudah dibaca`, memakai penyimpanan progres yang sudah ada.
2. `Bagikan ke WhatsApp`, tidak mensyaratkan penandaan selesai.

Formatter share menghasilkan teks plain-text berisi nomor dan nama karakter, seluruh bagian dari halaman pertama sampai terakhir, heading, paragraf, bullet, serta nomor. Footer harus persis:

`Baca karakter lainnya di aplikasi PKG Panunggangan: https://pkgenerus.my.id/29-karakter`

Aplikasi membuka WhatsApp/pemilih kontak dengan teks sudah terisi. Android tidak boleh diklaim mengirim otomatis: pengguna tetap memilih kontak dan menekan Kirim. Jika WhatsApp tidak tersedia, Android Share Sheet menjadi fallback.

## Penanganan ukuran pesan

Formatter membangun satu teks lengkap sebagaimana diminta. Jika target WhatsApp menolak karena batas panjang, aplikasi menampilkan pesan jujur dan menawarkan Share Sheet/copy sebagai fallback; isi tidak diam-diam dipotong.

## Pengujian

- Unit: deteksi Arab, paragraf, bullet, nomor, teks campuran, urutan bagian, dan footer persis.
- Widget: RTL/LTR, font Arab lebih besar, wrapping/hanging indent, kedua tombol penutup.
- Perangkat: baca karakter panjang sampai akhir, buka WhatsApp, pastikan seluruh bagian dan footer ada, serta fallback ketika WhatsApp tidak tersedia.

## Batasan

Tidak mengubah data karakter di server, tidak mengirim WhatsApp tanpa tindakan pengguna, dan tidak menyertakan identitas siswa/token dalam pesan.