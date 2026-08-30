/// Model kelas dari `GET /api/v1/kelas`.
///
/// CATATAN backend: endpoint ini menandai dirinya `deprecated: true` dan
/// menyarankan Binaan Pamong / Kelas Sekolah. Tetap dipakai sebagai data
/// referensi sampai API penggantinya tersedia.
class Kelas {
  const Kelas({
    required this.id,
    required this.nama,
    this.tingkat,
    this.kodeKelas,
    this.kapasitas,
    this.siswaCount,
    this.isActive,
    this.deskripsi,
    this.pamongNama,
    this.siswa = const [],
  });

  factory Kelas.fromJson(Map<String, dynamic> json) {
    // `pamong` bisa berupa objek user, list kosong (dari relasi tak terisi),
    // atau null — jadi jangan pernah cast langsung ke Map.
    final pamongRaw = json['pamong'];
    final pamong = pamongRaw is Map ? pamongRaw.cast<String, dynamic>() : null;

    return Kelas(
      id: json['id'] as int,
      nama: '${json['nama'] ?? ''}',
      tingkat: json['tingkat']?.toString(),
      kodeKelas: json['kode_kelas'] as String?,
      kapasitas: json['kapasitas'] as int?,
      siswaCount: json['siswa_count'] as int?,
      isActive: json['is_active'] as bool?,
      deskripsi: json['deskripsi'] as String?,
      pamongNama: (pamong?['name'] ?? pamong?['username']) as String?,
      siswa: (json['siswa'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => KelasSiswa.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }

  final int id;
  final String nama;
  final String? tingkat;
  final String? kodeKelas;
  final int? kapasitas;
  final int? siswaCount;
  final bool? isActive;
  final String? deskripsi;
  final String? pamongNama;

  /// Hanya terisi pada `GET /kelas/{id}`.
  final List<KelasSiswa> siswa;

  double get okupansi =>
      (kapasitas ?? 0) == 0 ? 0 : (siswaCount ?? 0) / kapasitas!;

  int get jumlahSiswa => siswaCount ?? siswa.length;
}

/// Baris siswa di dalam payload `GET /kelas/{id}`.
///
/// Bentuknya adalah model Eloquent mentah (bukan resource ringkas seperti
/// `/siswa`), jadi hanya field yang benar-benar dipakai UI yang dibaca.
class KelasSiswa {
  const KelasSiswa({
    required this.id,
    required this.nis,
    required this.nama,
    this.jenisKelamin,
    this.status,
  });

  factory KelasSiswa.fromJson(Map<String, dynamic> json) => KelasSiswa(
        id: json['id'] as int,
        nis: '${json['nis'] ?? ''}',
        nama: '${json['nama'] ?? ''}',
        jenisKelamin: json['jenis_kelamin'] as String?,
        status: json['status'] as String?,
      );

  final int id;
  final String nis;
  final String nama;
  final String? jenisKelamin;
  final String? status;
}

/// Ringkasan dari `GET /api/v1/kelas/stats`.
class KelasStats {
  const KelasStats({
    required this.totalKelas,
    required this.activeKelas,
    required this.totalPamong,
    required this.totalSiswa,
  });

  factory KelasStats.fromJson(Map<String, dynamic> json) => KelasStats(
        totalKelas: _int(json['total_kelas']),
        activeKelas: _int(json['active_kelas']),
        totalPamong: _int(json['total_pamong']),
        totalSiswa: _int(json['total_siswa']),
      );

  final int totalKelas;
  final int activeKelas;
  final int totalPamong;
  final int totalSiswa;

  static int _int(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
}
