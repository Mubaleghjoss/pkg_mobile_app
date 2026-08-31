/// Model 29 Karakter Luhur.
///
/// Field diverifikasi langsung dari respons `GET /api/v1/karakter-luhur`
/// (ringkasan) dan `/karakter-luhur/{slug}` (lengkap). Endpoint ringkas TIDAK
/// mengirim `deskripsi`/`dalil_*`, jadi field tersebut nullable dan hanya
/// terisi setelah detail dimuat.
class KarakterLuhur {
  const KarakterLuhur({
    required this.id,
    required this.nomor,
    required this.slug,
    required this.nama,
    this.namaArab,
    this.kategori,
    this.ringkas,
    this.deskripsi,
    this.definisi,
    this.dalilQuran,
    this.dalilHadits,
    this.hikmah,
    this.studiKasus,
    this.penerapan,
    this.tipsAmal,
    this.hasPenerapan = false,
  });

  final int id;

  /// Nomor urut 1..29 yang ditampilkan sebagai badge.
  final int nomor;
  final String slug;
  final String nama;
  final String? namaArab;
  final String? kategori;

  /// Kalimat pembuka singkat untuk kartu daftar.
  final String? ringkas;

  final String? deskripsi;
  final String? definisi;
  final String? dalilQuran;
  final String? dalilHadits;
  final String? hikmah;
  final String? studiKasus;
  final String? penerapan;
  final String? tipsAmal;
  final bool hasPenerapan;

  /// True bila objek ini sudah berisi detail (bukan hanya ringkasan daftar).
  bool get isDetailed =>
      deskripsi != null ||
      definisi != null ||
      dalilQuran != null ||
      hikmah != null;

  static String? _str(Object? v) {
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }

  factory KarakterLuhur.fromJson(Map<String, dynamic> json) {
    return KarakterLuhur(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nomor: (json['nomor'] as num?)?.toInt() ?? 0,
      slug: '${json['slug'] ?? ''}',
      nama: '${json['nama'] ?? ''}',
      namaArab: _str(json['nama_arab']),
      kategori: _str(json['kategori']),
      ringkas: _str(json['ringkas']),
      deskripsi: _str(json['deskripsi']),
      definisi: _str(json['definisi']),
      dalilQuran: _str(json['dalil_quran']),
      dalilHadits: _str(json['dalil_hadits']),
      hikmah: _str(json['hikmah']),
      studiKasus: _str(json['studi_kasus']),
      penerapan: _str(json['penerapan']),
      tipsAmal: _str(json['tips_amal']),
      hasPenerapan: json['has_penerapan'] == true,
    );
  }

  /// Bagian isi yang tersedia, dipakai pembaca untuk membangun halaman
  /// berurutan. Bagian kosong dilewati supaya tidak ada halaman hampa.
  List<KarakterSection> get sections {
    final out = <KarakterSection>[];
    void add(String title, String? body, String icon) {
      if (body != null) out.add(KarakterSection(title, body, icon));
    }

    add('Apa itu $nama?', definisi ?? deskripsi, 'lightbulb');
    if (definisi != null && deskripsi != null && definisi != deskripsi) {
      add('Penjelasan', deskripsi, 'menu_book');
    }
    add('Dalil Al-Quran', dalilQuran, 'quran');
    add('Dalil Hadits', dalilHadits, 'hadits');
    add('Hikmahnya', hikmah, 'favorite');
    add('Contoh nyata', studiKasus, 'groups');
    add('Cara menerapkan', penerapan, 'checklist');
    add('Tips amal harian', tipsAmal, 'tips');
    return out;
  }
}

/// Satu halaman bacaan di dalam materi karakter.
class KarakterSection {
  const KarakterSection(this.title, this.body, this.iconKey);

  final String title;
  final String body;

  /// Kunci ikon; dipetakan ke `IconData` di lapisan UI supaya model tetap
  /// bebas dependensi Flutter.
  final String iconKey;
}
