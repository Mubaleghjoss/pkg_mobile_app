import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/paginated.dart';
import 'qr_payload.dart';

/// Status kehadiran yang diterima backend (`Rule::in` pada StorePresensiRequest).
enum StatusPresensi {
  hadir('hadir', 'Hadir'),
  terlambat('terlambat', 'Terlambat'),
  izin('izin', 'Izin'),
  sakit('sakit', 'Sakit'),
  alpha('alpha', 'Alpha'),
  tidakHadir('tidak_hadir', 'Tidak hadir');

  const StatusPresensi(this.value, this.label);

  final String value;
  final String label;

  static StatusPresensi? tryParse(String? raw) {
    for (final s in values) {
      if (s.value == raw) return s;
    }
    return null;
  }
}

/// Satu baris presensi dari `GET /api/v1/presensi`.
class Presensi {
  const Presensi({
    required this.id,
    required this.tanggal,
    required this.status,
    required this.siswaNama,
    this.siswaId,
    this.siswaNis,
    this.jamMasuk,
    this.jamKeluar,
    this.keterangan,
    this.isVerified,
    this.durationMinutes,
  });

  factory Presensi.fromJson(Map<String, dynamic> json) {
    final siswa = (json['siswa'] as Map?)?.cast<String, dynamic>();
    return Presensi(
      id: json['id'] as int,
      tanggal: json['tanggal']?.toString() ?? '',
      status: json['status']?.toString() ?? '-',
      siswaNama: '${siswa?['nama'] ?? '-'}',
      siswaId: json['siswa_id'] as int? ?? siswa?['id'] as int?,
      siswaNis: siswa?['nis']?.toString(),
      jamMasuk: json['jam_masuk'] as String?,
      jamKeluar: json['jam_keluar'] as String?,
      keterangan: json['keterangan'] as String?,
      isVerified: json['is_verified'] as bool?,
      durationMinutes: json['duration_minutes'] as int?,
    );
  }

  final int id;
  final String tanggal;
  final String status;
  final String siswaNama;
  final int? siswaId;
  final String? siswaNis;
  final String? jamMasuk;
  final String? jamKeluar;
  final String? keterangan;
  final bool? isVerified;
  final int? durationMinutes;

  String get statusLabel => StatusPresensi.tryParse(status)?.label ?? status;

  /// Tanggal ringkas `YYYY-MM-DD` (backend bisa mengirim ISO penuh).
  String get tanggalRingkas =>
      tanggal.length >= 10 ? tanggal.substring(0, 10) : tanggal;
}

/// Rekap dari `GET /api/v1/presensi/statistics` (wajib start_date & end_date).
class PresensiStatistics {
  const PresensiStatistics({
    required this.total,
    required this.hadir,
    required this.terlambat,
    required this.izin,
    required this.sakit,
    required this.tidakHadir,
    required this.alpha,
    required this.verified,
    required this.persentaseKehadiran,
  });

  factory PresensiStatistics.fromJson(Map<String, dynamic> json) =>
      PresensiStatistics(
        total: _int(json['total']),
        hadir: _int(json['hadir']),
        terlambat: _int(json['terlambat']),
        izin: _int(json['izin']),
        sakit: _int(json['sakit']),
        tidakHadir: _int(json['tidak_hadir']),
        alpha: _int(json['alpha']),
        verified: _int(json['verified']),
        persentaseKehadiran:
            (json['persentase_kehadiran'] as num?)?.toDouble() ?? 0,
      );

  final int total;
  final int hadir;
  final int terlambat;
  final int izin;
  final int sakit;
  final int tidakHadir;
  final int alpha;
  final int verified;
  /// Dari backend: `(hadir + terlambat) / total` — terlambat dihitung masuk.
  final double persentaseKehadiran;

  /// Persentase datang tepat waktu (terlambat tidak dihitung), dihitung di
  /// klien dari rincian status supaya keterlambatan tetap terlihat meski
  /// kehadiran tercatat 100%.
  double get persentaseTepatWaktu =>
      total == 0 ? 0 : (hadir / total) * 100;

  bool get adaKeterlambatan => terlambat > 0;

  static int _int(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;

  /// Pasangan (label, jumlah) untuk grafik batang.
  List<(String, int)> get breakdown => [
        ('Hadir', hadir),
        ('Terlambat', terlambat),
        ('Izin', izin),
        ('Sakit', sakit),
        ('Alpha', alpha),
        ('Tidak hadir', tidakHadir),
      ];
}

/// Akses presensi. Baca butuh `view_attendance`, tulis `manage_attendance`.
class PresensiRepository {
  PresensiRepository(this._dio);

  final Dio _dio;

  Future<ApiResult<Paginated<Presensi>>> list({
    int page = 1,
    String? tanggal,
    String? status,
    int? siswaId,
    bool? verified,
    int? perPage,
  }) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>('/presensi', queryParameters: {
          'page': page,
          'per_page': ?perPage,
          if (tanggal != null && tanggal.isNotEmpty) 'tanggal': tanggal,
          if (status != null && status.isNotEmpty) 'status': status,
          'siswa_id': ?siswaId,
          if (verified != null) 'verified': verified ? 1 : 0,
        }),
      );
      if (!mapped.ok) {
        return ApiResult.failure(mapped.error ?? 'Gagal memuat presensi',
            statusCode: mapped.statusCode);
      }
      final items = (mapped.data?['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Presensi.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);
      return ApiResult.success(
        Paginated(
          items: items,
          meta: PageMeta.fromResponse(mapped.data, itemCount: items.length),
        ),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(err.error ?? 'Gagal memuat presensi',
          statusCode: err.statusCode);
    }
  }

  /// Rekap periode. Backend MEWAJIBKAN kedua tanggal (HTTP 422 bila kosong).
  Future<ApiResult<PresensiStatistics>> statistics({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>('/presensi/statistics', queryParameters: {
          'start_date': _ymd(start),
          'end_date': _ymd(end),
        }),
      );
      if (!mapped.ok) {
        return ApiResult.failure(mapped.error ?? 'Gagal memuat statistik',
            statusCode: mapped.statusCode);
      }
      return ApiResult.success(
        PresensiStatistics.fromJson(
          (mapped.data?['data'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
        ),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(err.error ?? 'Gagal memuat statistik',
          statusCode: err.statusCode);
    }
  }

  /// Presensi manual: `POST /presensi`.
  /// Wajib `siswa_id`, `tanggal` (Y-m-d), `status`; jam format `H:i`.
  Future<ApiResult<Presensi>> create({
    required int siswaId,
    required DateTime tanggal,
    required StatusPresensi status,
    String? jamMasuk,
    String? jamKeluar,
    String? keterangan,
  }) =>
      _write(
        () => _dio.post<dynamic>('/presensi', data: {
          'siswa_id': siswaId,
          'tanggal': _ymd(tanggal),
          'status': status.value,
          if (jamMasuk != null && jamMasuk.isNotEmpty) 'jam_masuk': jamMasuk,
          if (jamKeluar != null && jamKeluar.isNotEmpty) 'jam_keluar': jamKeluar,
          if (keterangan != null && keterangan.isNotEmpty)
            'keterangan': keterangan,
        }),
        fallback: 'Gagal menyimpan presensi',
      );

  /// `PUT /presensi/{id}` — kirim hanya field yang diubah.
  Future<ApiResult<Presensi>> update(
    int id, {
    StatusPresensi? status,
    String? jamMasuk,
    String? jamKeluar,
    String? keterangan,
  }) =>
      _write(
        () => _dio.put<dynamic>('/presensi/$id', data: {
          if (status != null) 'status': status.value,
          'jam_masuk': ?jamMasuk,
          'jam_keluar': ?jamKeluar,
          'keterangan': ?keterangan,
        }),
        fallback: 'Gagal memperbarui presensi',
      );

  /// `POST /presensi/{id}/verify` — menandai baris terverifikasi.
  Future<ApiResult<Presensi>> verify(int id) => _write(
        () => _dio.post<dynamic>('/presensi/$id/verify'),
        fallback: 'Gagal memverifikasi presensi',
      );

  /// Scan QR siswa. Endpoint ini PUBLIK di backend (tanpa Sanctum) dan
  /// dibatasi 30 request/menit (`throttle:qr-scan`).
  Future<ApiResult<Map<String, dynamic>>> scanQr({
    required QrPayload payload,
    String? location,
  }) async {
    try {
      return ApiResponseMapper.map(
        await _dio.post<dynamic>(
          '/presensi/scan-qr',
          data: payload.toRequestBody(location: location),
          options: Options(headers: {'Content-Type': 'application/json'}),
        ),
      );
    } catch (e) {
      return ApiResponseMapper.mapError(e);
    }
  }

  Future<ApiResult<Presensi>> _write(
    Future<Response<dynamic>> Function() request, {
    required String fallback,
  }) async {
    try {
      final mapped = ApiResponseMapper.map(await request());
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? fallback,
          statusCode: mapped.statusCode,
          fieldErrors: mapped.fieldErrors,
        );
      }
      final data = (mapped.data?['data'] as Map?)?.cast<String, dynamic>();
      if (data == null) {
        return ApiResult.failure('Respons tidak berisi data presensi.',
            statusCode: mapped.statusCode);
      }
      return ApiResult.success(Presensi.fromJson(data),
          statusCode: mapped.statusCode);
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(err.error ?? fallback,
          statusCode: err.statusCode, fieldErrors: err.fieldErrors);
    }
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Format tanggal `Y-m-d` yang dipakai seluruh fitur presensi.
String ymd(DateTime d) => PresensiRepository._ymd(d);
