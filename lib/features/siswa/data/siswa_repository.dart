import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/paginated.dart';
import '../domain/siswa.dart';

/// Data QR siswa dari `GET /siswa/{id}/qr-code` dan
/// `POST /siswa/{id}/generate-qr`.
///
/// `qr_image_base64` berisi data URL SVG (`data:image/svg+xml;base64,...`),
/// bukan PNG — jadi harus dirender sebagai SVG, bukan `Image.memory`.
class SiswaQr {
  const SiswaQr({
    required this.token,
    required this.svgBase64,
    this.expiresAt,
    this.siswaNama,
    this.siswaNis,
  });

  factory SiswaQr.fromJson(Map<String, dynamic> json) {
    final info = (json['siswa_info'] as Map?)?.cast<String, dynamic>();
    final raw = '${json['qr_image_base64'] ?? ''}';
    final comma = raw.indexOf(',');
    return SiswaQr(
      token: '${json['token'] ?? ''}',
      svgBase64: comma >= 0 ? raw.substring(comma + 1) : raw,
      expiresAt: DateTime.tryParse('${json['expires_at']}'),
      siswaNama: info?['nama'] as String?,
      siswaNis: info?['nis']?.toString(),
    );
  }

  final String token;

  /// Base64 murni (prefix `data:` sudah dipangkas) berisi dokumen SVG.
  final String svgBase64;
  final DateTime? expiresAt;
  final String? siswaNama;
  final String? siswaNis;

  bool get hasImage => svgBase64.isNotEmpty;
}

/// Akses data siswa. Endpoint baca butuh `view_students`, tulis `manage_students`.
class SiswaRepository {
  SiswaRepository(this._dio);

  final Dio _dio;

  Future<ApiResult<Paginated<Siswa>>> list({
    int page = 1,
    String? search,
    String? status,
    String? schoolGrade,
  }) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>('/siswa', queryParameters: {
          'page': page,
          if (search != null && search.isNotEmpty) 'search': search,
          if (status != null && status.isNotEmpty) 'status': status,
          if (schoolGrade != null && schoolGrade.isNotEmpty)
            'school_grade': schoolGrade,
        }),
      );
      if (!mapped.ok) {
        return ApiResult.failure(mapped.error ?? 'Gagal memuat siswa',
            statusCode: mapped.statusCode);
      }
      final items = (mapped.data?['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Siswa.fromJson(e.cast<String, dynamic>()))
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
      return ApiResult.failure(err.error ?? 'Gagal memuat siswa',
          statusCode: err.statusCode);
    }
  }

  Future<ApiResult<SiswaStatistics>> statistics() async {
    try {
      final mapped =
          ApiResponseMapper.map(await _dio.get<dynamic>('/siswa/statistics'));
      if (!mapped.ok) {
        return ApiResult.failure(mapped.error ?? 'Gagal memuat statistik',
            statusCode: mapped.statusCode);
      }
      return ApiResult.success(
        SiswaStatistics.fromJson(
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

  Future<ApiResult<Siswa>> detail(int id) async {
    try {
      final mapped =
          ApiResponseMapper.map(await _dio.get<dynamic>('/siswa/$id'));
      if (!mapped.ok) {
        return ApiResult.failure(mapped.error ?? 'Gagal memuat siswa',
            statusCode: mapped.statusCode);
      }
      final data = (mapped.data?['data'] as Map?)?.cast<String, dynamic>();
      if (data == null) {
        return ApiResult.failure('Respons siswa tidak berisi data.',
            statusCode: mapped.statusCode);
      }
      return ApiResult.success(Siswa.fromJson(data),
          statusCode: mapped.statusCode);
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(err.error ?? 'Gagal memuat siswa',
          statusCode: err.statusCode);
    }
  }

  /// `POST /siswa` — wajib: nis, nama, jenis_kelamin (L/P), school_grade.
  Future<ApiResult<Siswa>> create(Map<String, dynamic> payload) =>
      _write(() => _dio.post<dynamic>('/siswa', data: payload),
          fallback: 'Gagal menyimpan siswa');

  /// `PUT /siswa/{id}` — semua field `sometimes`, kirim hanya yang berubah.
  Future<ApiResult<Siswa>> update(int id, Map<String, dynamic> payload) =>
      _write(() => _dio.put<dynamic>('/siswa/$id', data: payload),
          fallback: 'Gagal memperbarui siswa');

  /// `DELETE /siswa/{id}`.
  ///
  /// Backend menolak (kode `HAS_ATTENDANCE_RECORDS`) bila siswa punya presensi;
  /// pesan penolakan itu diteruskan apa adanya ke UI.
  Future<ApiResult<String>> delete(int id) async {
    try {
      final mapped =
          ApiResponseMapper.map(await _dio.delete<dynamic>('/siswa/$id'));
      if (!mapped.ok) {
        return ApiResult.failure(mapped.error ?? 'Gagal menghapus siswa',
            statusCode: mapped.statusCode);
      }
      return ApiResult.success(
        '${mapped.data?['message'] ?? 'Siswa dihapus.'}',
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(err.error ?? 'Gagal menghapus siswa',
          statusCode: err.statusCode);
    }
  }

  /// QR aktif siswa (`GET`, tidak memutar token).
  Future<ApiResult<SiswaQr>> qrCode(int id) =>
      _qr(() => _dio.get<dynamic>('/siswa/$id/qr-code'));

  /// Buat ulang token QR (`POST`, token lama tidak berlaku lagi).
  Future<ApiResult<SiswaQr>> regenerateQr(int id) =>
      _qr(() => _dio.post<dynamic>('/siswa/$id/generate-qr'));

  Future<ApiResult<SiswaQr>> _qr(
      Future<Response<dynamic>> Function() request) async {
    try {
      final mapped = ApiResponseMapper.map(await request());
      if (!mapped.ok) {
        return ApiResult.failure(mapped.error ?? 'Gagal memuat QR',
            statusCode: mapped.statusCode);
      }
      final data = (mapped.data?['qr_data'] as Map?)?.cast<String, dynamic>();
      if (data == null) {
        return ApiResult.failure('Respons tidak berisi qr_data.',
            statusCode: mapped.statusCode);
      }
      return ApiResult.success(SiswaQr.fromJson(data),
          statusCode: mapped.statusCode);
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(err.error ?? 'Gagal memuat QR',
          statusCode: err.statusCode);
    }
  }

  Future<ApiResult<Siswa>> _write(
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
        return ApiResult.failure('Respons tidak berisi data siswa.',
            statusCode: mapped.statusCode);
      }
      return ApiResult.success(Siswa.fromJson(data),
          statusCode: mapped.statusCode);
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(err.error ?? fallback,
          statusCode: err.statusCode, fieldErrors: err.fieldErrors);
    }
  }
}
