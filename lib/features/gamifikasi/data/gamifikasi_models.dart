/// Model gamifikasi: poin, level, peringkat, riwayat poin, badge.
///
/// Field mengikuti respons nyata endpoint API v1 (diverifikasi lewat curl pada
/// backend lokal, bukan asumsi):
/// - `GET /gamifikasi/ringkasan`   → `{siswa, poin, level, peringkat, streak,
///   total_badge, periode_aktif, poin_periode_aktif, rekap_sumber}`
/// - `GET /gamifikasi/leaderboard` → `{periode, entries[], saya}`
/// - `GET /gamifikasi/history`     → `data[]` + `meta{...paginasi,
///   filter_sumber, rekap_sumber}`
/// - `GET /gamifikasi/badges`      → `data[]` + `meta{total, sudah_didapat}`
library;

int _int(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;

DateTime? _date(Object? v) {
  if (v is! String || v.isEmpty) return null;
  return DateTime.tryParse(v)?.toLocal();
}

/// Rincian poin per kantong (sesuai kolom tabel `siswa_points`).
class PoinRincian {
  const PoinRincian({
    required this.total,
    required this.kehadiran,
    required this.karakter,
    required this.bonus,
    required this.terpakai,
  });

  factory PoinRincian.fromJson(Map<String, dynamic> json) => PoinRincian(
        total: _int(json['total']),
        kehadiran: _int(json['kehadiran']),
        karakter: _int(json['karakter']),
        bonus: _int(json['bonus']),
        terpakai: _int(json['terpakai']),
      );

  final int total;
  final int kehadiran;
  final int karakter;
  final int bonus;
  final int terpakai;
}

/// Level dan progres menuju level berikutnya.
class LevelInfo {
  const LevelInfo({
    required this.angka,
    required this.progresPersen,
    required this.poinKeBerikutnya,
    this.nama,
    this.warna,
    this.levelBerikutnya,
    this.namaBerikutnya,
  });

  factory LevelInfo.fromJson(Map<String, dynamic> json) => LevelInfo(
        angka: _int(json['angka']),
        progresPersen: _int(json['progres_persen']).clamp(0, 100),
        poinKeBerikutnya: _int(json['poin_ke_berikutnya']),
        nama: json['nama'] as String?,
        warna: json['warna'] as String?,
        levelBerikutnya:
            json['level_berikutnya'] == null ? null : _int(json['level_berikutnya']),
        namaBerikutnya: json['nama_berikutnya'] as String?,
      );

  final int angka;
  final int progresPersen;
  final int poinKeBerikutnya;
  final String? nama;
  final String? warna;
  final int? levelBerikutnya;
  final String? namaBerikutnya;

  bool get sudahMaksimal => levelBerikutnya == null;
}

/// Jumlah aktivitas berpoin, dihitung dari sumber datanya (tugas & presensi),
/// bukan dari transaksi poin — jadi tetap benar walau ada transaksi gagal.
class RekapSumber {
  const RekapSumber({
    required this.tugasTerverifikasi,
    required this.hadir,
    required this.terlambat,
    required this.izin,
    required this.sakit,
    required this.alpha,
  });

  factory RekapSumber.fromJson(Map<String, dynamic> json) => RekapSumber(
        tugasTerverifikasi: _int(json['tugas_terverifikasi']),
        hadir: _int(json['hadir']),
        terlambat: _int(json['terlambat']),
        izin: _int(json['izin']),
        sakit: _int(json['sakit']),
        alpha: _int(json['alpha']),
      );

  final int tugasTerverifikasi;
  final int hadir;
  final int terlambat;
  final int izin;
  final int sakit;
  final int alpha;

  /// Kehadiran tanpa keterlambatan — dasar poin `attendance` di backend.
  int get hadirTepatWaktu => hadir;

  int get totalCatatanPresensi => hadir + terlambat + izin + sakit + alpha;
}

/// Ringkasan gamifikasi satu siswa.
class GamifikasiRingkasan {
  const GamifikasiRingkasan({
    required this.siswaId,
    required this.nama,
    required this.isOrtuView,
    required this.poin,
    required this.level,
    required this.peringkat,
    required this.streakKehadiran,
    required this.streakKarakter,
    required this.totalBadge,
    required this.poinPeriodeAktif,
    required this.rekap,
    this.nis,
    this.namaPeriodeAktif,
  });

  factory GamifikasiRingkasan.fromJson(Map<String, dynamic> json) {
    final siswa = (json['siswa'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final streak = (json['streak'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final periode = (json['periode_aktif'] as Map?)?.cast<String, dynamic>();

    return GamifikasiRingkasan(
      siswaId: _int(siswa['id']),
      nama: '${siswa['nama'] ?? '-'}',
      nis: siswa['nis'] as String?,
      isOrtuView: siswa['is_ortu_view'] == true,
      poin: PoinRincian.fromJson(
        (json['poin'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      level: LevelInfo.fromJson(
        (json['level'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      peringkat: _int(json['peringkat']),
      streakKehadiran: _int(streak['kehadiran']),
      streakKarakter: _int(streak['karakter']),
      totalBadge: _int(json['total_badge']),
      poinPeriodeAktif: _int(json['poin_periode_aktif']),
      namaPeriodeAktif: periode?['name'] as String?,
      rekap: RekapSumber.fromJson(
        (json['rekap_sumber'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
    );
  }

  final int siswaId;
  final String nama;
  final String? nis;
  final bool isOrtuView;
  final PoinRincian poin;
  final LevelInfo level;
  final int peringkat;
  final int streakKehadiran;
  final int streakKarakter;
  final int totalBadge;
  final int poinPeriodeAktif;
  final String? namaPeriodeAktif;
  final RekapSumber rekap;
}

/// Satu baris papan peringkat.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.peringkat,
    required this.siswaId,
    required this.nama,
    required this.totalPoin,
    required this.level,
    required this.isSaya,
    this.kelas,
    this.namaLevel,
    this.poinPeriode,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        peringkat: _int(json['peringkat']),
        siswaId: _int(json['siswa_id']),
        nama: '${json['nama'] ?? '-'}',
        totalPoin: _int(json['total_poin']),
        level: _int(json['level']),
        isSaya: json['is_saya'] == true,
        kelas: json['kelas'] as String?,
        namaLevel: json['nama_level'] as String?,
        poinPeriode:
            json['poin_periode'] == null ? null : _int(json['poin_periode']),
      );

  final int peringkat;
  final int siswaId;
  final String nama;
  final int totalPoin;
  final int level;
  final bool isSaya;
  final String? kelas;
  final String? namaLevel;
  final int? poinPeriode;
}

/// Papan peringkat + posisi siswa sendiri (walau di luar daftar teratas).
class LeaderboardHalaman {
  const LeaderboardHalaman({
    required this.periode,
    required this.entries,
    required this.peringkatSaya,
    required this.poinSaya,
    required this.masukDaftar,
    required this.namaSaya,
  });

  factory LeaderboardHalaman.fromJson(Map<String, dynamic> json) {
    final saya =
        (json['saya'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    return LeaderboardHalaman(
      periode: '${json['periode'] ?? 'all'}',
      entries: (json['entries'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => LeaderboardEntry.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
      peringkatSaya: _int(saya['peringkat']),
      poinSaya: _int(saya['total_poin']),
      namaSaya: '${saya['nama'] ?? '-'}',
      masukDaftar: saya['masuk_daftar'] == true,
    );
  }

  final String periode;
  final List<LeaderboardEntry> entries;
  final int peringkatSaya;
  final int poinSaya;
  final String namaSaya;
  final bool masukDaftar;
}

/// Satu transaksi poin pada riwayat siswa.
class PoinTransaksi {
  const PoinTransaksi({
    required this.id,
    required this.tipe,
    required this.sumber,
    required this.sumberLabel,
    required this.poin,
    this.keterangan,
    this.tanggal,
  });

  factory PoinTransaksi.fromJson(Map<String, dynamic> json) => PoinTransaksi(
        id: _int(json['id']),
        tipe: '${json['tipe'] ?? ''}',
        sumber: '${json['sumber'] ?? ''}',
        sumberLabel: '${json['sumber_label'] ?? json['sumber'] ?? '-'}',
        poin: _int(json['poin']),
        keterangan: json['keterangan'] as String?,
        tanggal: _date(json['tanggal']),
      );

  final int id;
  final String tipe;
  final String sumber;
  final String sumberLabel;
  final int poin;
  final String? keterangan;
  final DateTime? tanggal;

  bool get bertambah => poin >= 0;
}

/// Badge beserta progres pencapaiannya.
class BadgeItem {
  const BadgeItem({
    required this.id,
    required this.nama,
    required this.poinReward,
    required this.sudahDidapat,
    required this.progresPersen,
    this.deskripsi,
    this.kategori,
    this.warna,
    this.didapatPada,
  });

  factory BadgeItem.fromJson(Map<String, dynamic> json) => BadgeItem(
        id: _int(json['id']),
        nama: '${json['nama'] ?? '-'}',
        poinReward: _int(json['poin_reward']),
        sudahDidapat: json['sudah_didapat'] == true,
        progresPersen: _int(json['progres_persen']).clamp(0, 100),
        deskripsi: json['deskripsi'] as String?,
        kategori: json['kategori'] as String?,
        warna: json['warna'] as String?,
        didapatPada: _date(json['didapat_pada']),
      );

  final int id;
  final String nama;
  final int poinReward;
  final bool sudahDidapat;
  final int progresPersen;
  final String? deskripsi;
  final String? kategori;
  final String? warna;
  final DateTime? didapatPada;
}
