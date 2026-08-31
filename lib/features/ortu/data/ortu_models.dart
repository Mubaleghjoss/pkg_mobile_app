/// Model monitoring orang tua: rekap tugas, presensi, dan bacaan Quran anak.
///
/// Field mengikuti respons nyata (diverifikasi lewat curl):
/// - `GET /ortu/tugas`      → item `{id, karakter_nama, kategori, poin,
///   checked_at, hasil_teks, is_verified, verified_at, verified_by, notes}`
///   + meta `{status, total_tugas_aktif, terverifikasi, menunggu_verifikasi,
///   poin_terverifikasi, persentase, ...paginasi}`
/// - `GET /ortu/presensi`   → item `{id, tanggal, status, jam_masuk, jam_keluar,
///   is_verified, verified_at, keterangan}` + meta `{totals, bulanan[]}`
/// - `GET /ortu/quran`      → `{terverifikasi_total, terverifikasi_bulan_ini,
///   menunggu_verifikasi, ditolak, terakhir_membaca}`
/// - `GET /ortu/ringkasan`  → `{siswa, tugas, presensi, quran}`
library;

int _int(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;

double _double(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

DateTime? _date(Object? v) {
  if (v is! String || v.isEmpty) return null;
  return DateTime.tryParse(v)?.toLocal();
}

/// Satu baris tugas anak yang dilihat orang tua (read-only).
class OrtuTugasItem {
  const OrtuTugasItem({
    required this.id,
    required this.karakterNama,
    required this.poin,
    required this.isVerified,
    this.kategori,
    this.checkedAt,
    this.hasilTeks,
    this.verifiedAt,
    this.verifiedBy,
    this.notes,
  });

  factory OrtuTugasItem.fromJson(Map<String, dynamic> json) => OrtuTugasItem(
        id: _int(json['id']),
        karakterNama: '${json['karakter_nama'] ?? '-'}',
        poin: _int(json['poin']),
        isVerified: json['is_verified'] == true,
        kategori: json['kategori'] as String?,
        checkedAt: _date(json['checked_at']),
        hasilTeks: json['hasil_teks'] as String?,
        verifiedAt: _date(json['verified_at']),
        verifiedBy: json['verified_by'] as String?,
        notes: json['notes'] as String?,
      );

  final int id;
  final String karakterNama;
  final int poin;
  final bool isVerified;
  final String? kategori;
  final DateTime? checkedAt;
  final String? hasilTeks;
  final DateTime? verifiedAt;

  /// Nama pamong yang memverifikasi — inilah bukti alur siswa → pamong → ortu.
  final String? verifiedBy;
  final String? notes;
}

/// Rekap tugas pada `meta` endpoint ortu.
class OrtuTugasRekap {
  const OrtuTugasRekap({
    required this.totalTugasAktif,
    required this.terverifikasi,
    required this.menungguVerifikasi,
    required this.poinTerverifikasi,
    required this.persentase,
  });

  factory OrtuTugasRekap.fromJson(Map<String, dynamic> json) => OrtuTugasRekap(
        totalTugasAktif: _int(json['total_tugas_aktif']),
        terverifikasi: _int(json['terverifikasi']),
        menungguVerifikasi: _int(json['menunggu_verifikasi']),
        poinTerverifikasi: _int(json['poin_terverifikasi']),
        persentase: _double(json['persentase']),
      );

  final int totalTugasAktif;
  final int terverifikasi;
  final int menungguVerifikasi;
  final int poinTerverifikasi;
  final double persentase;
}

/// Satu baris presensi anak.
class OrtuPresensiItem {
  const OrtuPresensiItem({
    required this.id,
    required this.status,
    required this.isVerified,
    this.tanggal,
    this.jamMasuk,
    this.jamKeluar,
    this.verifiedAt,
    this.keterangan,
  });

  factory OrtuPresensiItem.fromJson(Map<String, dynamic> json) =>
      OrtuPresensiItem(
        id: _int(json['id']),
        status: '${json['status'] ?? '-'}',
        isVerified: json['is_verified'] == true,
        tanggal: _date(json['tanggal']),
        jamMasuk: _date(json['jam_masuk']),
        jamKeluar: _date(json['jam_keluar']),
        verifiedAt: _date(json['verified_at']),
        keterangan: json['keterangan'] as String?,
      );

  final int id;
  final String status;
  final bool isVerified;
  final DateTime? tanggal;
  final DateTime? jamMasuk;
  final DateTime? jamKeluar;
  final DateTime? verifiedAt;
  final String? keterangan;
}

/// Hitungan presensi per status.
class PresensiTotals {
  const PresensiTotals({
    required this.hadir,
    required this.terlambat,
    required this.izin,
    required this.sakit,
    required this.alpha,
    required this.total,
  });

  factory PresensiTotals.fromJson(Map<String, dynamic> json) => PresensiTotals(
        hadir: _int(json['hadir']),
        terlambat: _int(json['terlambat']),
        izin: _int(json['izin']),
        sakit: _int(json['sakit']),
        alpha: _int(json['alpha']),
        total: _int(json['total']),
      );

  final int hadir;
  final int terlambat;
  final int izin;
  final int sakit;
  final int alpha;
  final int total;

  /// Jumlah yang dihitung "masuk": hadir penuh + terlambat.
  ///
  /// Keputusan produk: terlambat TETAP dihitung hadir (anak memang datang),
  /// tetapi angka keterlambatannya tidak boleh hilang — lihat
  /// [jumlahTerlambat] dan [persentaseTepatWaktu] yang dipakai UI untuk
  /// menampilkan "termasuk N terlambat".
  int get jumlahMasuk => hadir + terlambat;

  /// Keterlambatan yang tetap tercatat walau dihitung hadir.
  int get jumlahTerlambat => terlambat;

  bool get adaKeterlambatan => terlambat > 0;

  /// Persentase kehadiran (hadir + terlambat dihitung masuk).
  double get persentaseKehadiran =>
      total == 0 ? 0 : (jumlahMasuk / total) * 100;

  /// Persentase datang tepat waktu (terlambat TIDAK dihitung).
  ///
  /// Dipakai sebagai angka pendamping supaya orang tua tetap melihat bahwa
  /// kehadiran 100% bisa berisi keterlambatan.
  double get persentaseTepatWaktu =>
      total == 0 ? 0 : (hadir / total) * 100;
}

/// Rekap presensi per bulan (`meta.bulanan`).
class PresensiBulanan {
  const PresensiBulanan({required this.periode, required this.totals});

  factory PresensiBulanan.fromJson(Map<String, dynamic> json) =>
      PresensiBulanan(
        periode: '${json['periode'] ?? '-'}',
        totals: PresensiTotals.fromJson(json),
      );

  final String periode;
  final PresensiTotals totals;
}

/// Ringkasan bacaan Quran anak.
class OrtuQuranRekap {
  const OrtuQuranRekap({
    required this.terverifikasiTotal,
    required this.terverifikasiBulanIni,
    required this.menungguVerifikasi,
    required this.ditolak,
    this.terakhirMembaca,
  });

  factory OrtuQuranRekap.fromJson(Map<String, dynamic> json) => OrtuQuranRekap(
        terverifikasiTotal: _int(json['terverifikasi_total']),
        terverifikasiBulanIni: _int(json['terverifikasi_bulan_ini']),
        menungguVerifikasi: _int(json['menunggu_verifikasi']),
        ditolak: _int(json['ditolak']),
        terakhirMembaca: json['terakhir_membaca'] as String?,
      );

  final int terverifikasiTotal;
  final int terverifikasiBulanIni;
  final int menungguVerifikasi;
  final int ditolak;
  final String? terakhirMembaca;
}

/// Identitas anak pada respons ringkasan.
class OrtuSiswaInfo {
  const OrtuSiswaInfo({
    required this.id,
    required this.nama,
    required this.nis,
    this.kelas,
  });

  factory OrtuSiswaInfo.fromJson(Map<String, dynamic> json) => OrtuSiswaInfo(
        id: _int(json['id']),
        nama: '${json['nama'] ?? '-'}',
        nis: '${json['nis'] ?? '-'}',
        kelas: json['kelas'] as String?,
      );

  final int id;
  final String nama;
  final String nis;
  final String? kelas;
}

/// Gabungan `GET /ortu/ringkasan` — satu panggilan untuk dasbor monitoring.
class OrtuRingkasan {
  const OrtuRingkasan({
    required this.siswa,
    required this.tugas,
    required this.presensi,
    required this.quran,
  });

  factory OrtuRingkasan.fromJson(Map<String, dynamic> json) => OrtuRingkasan(
        siswa: OrtuSiswaInfo.fromJson(
          (json['siswa'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
        ),
        tugas: OrtuTugasRekap.fromJson(
          (json['tugas'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
        ),
        presensi: PresensiTotals.fromJson(
          (json['presensi'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
        ),
        quran: OrtuQuranRekap.fromJson(
          (json['quran'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
        ),
      );

  final OrtuSiswaInfo siswa;
  final OrtuTugasRekap tugas;
  final PresensiTotals presensi;
  final OrtuQuranRekap quran;
}
