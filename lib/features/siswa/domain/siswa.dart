/// Model siswa dari `GET /api/v1/siswa`.
///
/// Field diambil dari respons nyata backend; banyak field bernilai null pada
/// payload ringkas (mis. yang di-nest di dalam presensi), jadi semua opsional
/// kecuali `id`, `nis`, `nama`.
class Siswa {
  const Siswa({
    required this.id,
    required this.nis,
    required this.nama,
    this.jenisKelamin,
    this.kelompok,
    this.kelompokLabel,
    this.schoolGrade,
    this.schoolGradeLabel,
    this.effectivePkgLevelLabel,
    this.fotoUrl,
    this.status,
    this.isActive,
    this.namaWali,
    this.phoneWali,
    this.age,
    this.kelasNama,
    this.tanggalLahir,
    this.fullIdentity,
    this.biometricStatus,
    this.isAlumni,
    this.isBiodataComplete,
    this.presensiCount,
    this.pamong = const [],
    this.missingBiodataFields = const [],
  });

  factory Siswa.fromJson(Map<String, dynamic> json) {
    final kelas = (json['kelas'] as Map?)?.cast<String, dynamic>();
    return Siswa(
      id: json['id'] as int,
      nis: '${json['nis'] ?? ''}',
      nama: '${json['nama'] ?? ''}',
      jenisKelamin: json['jenis_kelamin'] as String?,
      kelompok: json['kelompok'] as String?,
      kelompokLabel: json['kelompok_label'] as String?,
      schoolGrade: json['school_grade'] as String?,
      schoolGradeLabel: json['school_grade_label'] as String?,
      effectivePkgLevelLabel: json['effective_pkg_level_label'] as String?,
      fotoUrl: json['foto_url'] as String?,
      status: json['status'] as String?,
      isActive: json['is_active'] as bool?,
      namaWali: json['nama_wali'] as String?,
      phoneWali: json['phone_wali'] as String?,
      age: json['age'] as int?,
      kelasNama: kelas?['nama'] as String?,
      tanggalLahir: json['tanggal_lahir'] as String?,
      fullIdentity: json['full_identity'] as String?,
      biometricStatus: json['biometric_status'] as String?,
      isAlumni: json['is_alumni'] as bool?,
      isBiodataComplete: json['is_biodata_complete'] as bool?,
      presensiCount: json['presensi_count'] as int?,
      pamong: (json['pamong'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => '${e['name'] ?? e['username'] ?? ''}')
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
      missingBiodataFields: (json['missing_biodata_fields'] as List? ?? const [])
          .map((e) => '$e')
          .toList(growable: false),
    );
  }

  final int id;
  final String nis;
  final String nama;
  final String? jenisKelamin;

  /// Kode mentah `kelompok` (mis. `sawah dalam 1`) — dipakai form edit.
  final String? kelompok;
  final String? kelompokLabel;

  /// Kode mentah `school_grade` (mis. `sma_10`) — dipakai form edit.
  final String? schoolGrade;
  final String? schoolGradeLabel;
  final String? effectivePkgLevelLabel;
  final String? fotoUrl;
  final String? status;
  final bool? isActive;
  final String? namaWali;
  final String? phoneWali;
  final int? age;
  final String? kelasNama;
  final String? tanggalLahir;
  final String? fullIdentity;
  final String? biometricStatus;
  final bool? isAlumni;

  /// Hanya terisi bila backend meng-`withCount` relasi presensi.
  final int? presensiCount;

  /// Nama pamong pembina (hanya saat relasi dimuat backend).
  final List<String> pamong;

  /// Hanya terisi pada `GET /siswa/{id}`; payload daftar tidak mengirim ini.
  final bool? isBiodataComplete;
  final List<String> missingBiodataFields;

  String get jenjangLabel =>
      effectivePkgLevelLabel ?? schoolGradeLabel ?? kelasNama ?? '-';
}

/// Ringkasan statistik dari `GET /api/v1/siswa/statistics`.
class SiswaStatistics {
  const SiswaStatistics({
    required this.total,
    required this.aktif,
    required this.nonAktif,
    required this.perJenisKelamin,
  });

  factory SiswaStatistics.fromJson(Map<String, dynamic> json) {
    final jk = (json['per_jenis_kelamin'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return SiswaStatistics(
      total: json['total'] as int? ?? 0,
      aktif: json['aktif'] as int? ?? 0,
      nonAktif: json['non_aktif'] as int? ?? 0,
      perJenisKelamin: jk.map((k, v) => MapEntry(k, v is int ? v : 0)),
    );
  }

  final int total;
  final int aktif;
  final int nonAktif;
  final Map<String, int> perJenisKelamin;
}
