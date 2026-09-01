/// Model untuk sumber data AKTIF pengganti `/kelas` yang ditandai deprecated:
/// Binaan Pamong (`GET /binaan-pamong`) dan Kelas Sekolah (`GET /kelas-sekolah`).
library;

/// Satu pamong beserta jumlah generus yang dibina saat ini.
class BinaanPamong {
  const BinaanPamong({
    required this.pamongId,
    required this.nama,
    required this.username,
    required this.isActive,
    required this.jumlahBinaan,
  });

  factory BinaanPamong.fromJson(Map<String, dynamic> json) => BinaanPamong(
        pamongId: _int(json['pamong_id']),
        nama: '${json['nama'] ?? ''}',
        username: '${json['username'] ?? ''}',
        isActive: json['is_active'] == true,
        jumlahBinaan: _int(json['jumlah_binaan']),
      );

  final int pamongId;
  final String nama;
  final String username;
  final bool isActive;
  final int jumlahBinaan;

  static int _int(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
}

/// `meta` dari `GET /binaan-pamong`. `scope` bernilai `sendiri` untuk pamong
/// biasa dan `semua` untuk admin/pamong yang dikecualikan — dipakai untuk
/// menjelaskan ke pengguna mengapa daftarnya hanya berisi dirinya sendiri.
class BinaanPamongRingkasan {
  const BinaanPamongRingkasan({
    required this.items,
    required this.totalPamong,
    required this.totalBinaan,
    required this.scope,
  });

  final List<BinaanPamong> items;
  final int totalPamong;
  final int totalBinaan;
  final String scope;

  bool get hanyaSendiri => scope == 'sendiri';
}

/// Satu kelas sekolah (SMP 7 … SMA 12) beserta dua cara hitung.
///
/// `jumlahSiswa` = kolom `school_grade` yang benar-benar terisi.
/// `jumlahEfektif` = level efektif (override → school_grade → taksiran tanggal
/// lahir), sama seperti `effective_pkg_level`. Di data nyata `school_grade`
/// banyak yang kosong, jadi angka efektif yang dipakai untuk tampilan.
class KelasSekolah {
  const KelasSekolah({
    required this.kode,
    required this.label,
    required this.labelSingkat,
    required this.jumlahSiswa,
    required this.jumlahEfektif,
  });

  factory KelasSekolah.fromJson(Map<String, dynamic> json) => KelasSekolah(
        kode: '${json['kode'] ?? ''}',
        label: '${json['label'] ?? ''}',
        labelSingkat: '${json['label_singkat'] ?? json['label'] ?? ''}',
        jumlahSiswa: _int(json['jumlah_siswa']),
        jumlahEfektif: _int(json['jumlah_efektif']),
      );

  final String kode;
  final String label;
  final String labelSingkat;
  final int jumlahSiswa;
  final int jumlahEfektif;

  /// Angka yang layak ditampilkan: pakai kolom bila terisi, kalau tidak pakai
  /// hasil taksiran level efektif.
  int get jumlahTampil => jumlahSiswa > 0 ? jumlahSiswa : jumlahEfektif;

  /// True bila jumlah hanya berasal dari taksiran, bukan biodata terisi.
  bool get dariTaksiran => jumlahSiswa == 0 && jumlahEfektif > 0;

  static int _int(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
}

/// `meta` dari `GET /kelas-sekolah`.
class KelasSekolahRingkasan {
  const KelasSekolahRingkasan({
    required this.items,
    required this.totalKelas,
    required this.totalSiswa,
    required this.belumDiisi,
    required this.totalEfektif,
  });

  final List<KelasSekolah> items;
  final int totalKelas;
  final int totalSiswa;
  final int belumDiisi;
  final int totalEfektif;
}
