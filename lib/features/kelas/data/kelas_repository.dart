import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../domain/kelas.dart';

/// Akses data kelas. `GET /kelas` pada backend bersifat publik (tanpa token),
/// tetap dipanggil lewat Dio yang sama supaya header konsisten.
class KelasRepository {
  KelasRepository(this._dio);

  final Dio _dio;

  Future<ApiResult<List<Kelas>>> list() async {
    try {
      final mapped = ApiResponseMapper.map(await _dio.get<dynamic>('/kelas'));
      if (!mapped.ok) {
        return ApiResult.failure(mapped.error ?? 'Gagal memuat kelas',
            statusCode: mapped.statusCode);
      }
      final items = (mapped.data?['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Kelas.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);
      return ApiResult.success(items, statusCode: mapped.statusCode);
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(err.error ?? 'Gagal memuat kelas',
          statusCode: err.statusCode);
    }
  }

  /// `GET /kelas/{id}` — termasuk daftar siswa di kelas tersebut.
  Future<ApiResult<Kelas>> detail(int id) async {
    try {
      final mapped =
          ApiResponseMapper.map(await _dio.get<dynamic>('/kelas/$id'));
      if (!mapped.ok) {
        return ApiResult.failure(mapped.error ?? 'Gagal memuat kelas',
            statusCode: mapped.statusCode);
      }
      final data = (mapped.data?['data'] as Map?)?.cast<String, dynamic>();
      if (data == null) {
        return ApiResult.failure('Respons kelas tidak berisi data.',
            statusCode: mapped.statusCode);
      }
      return ApiResult.success(Kelas.fromJson(data),
          statusCode: mapped.statusCode);
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(err.error ?? 'Gagal memuat kelas',
          statusCode: err.statusCode);
    }
  }

  /// `GET /kelas/stats`.
  Future<ApiResult<KelasStats>> stats() async {
    try {
      final mapped =
          ApiResponseMapper.map(await _dio.get<dynamic>('/kelas/stats'));
      if (!mapped.ok) {
        return ApiResult.failure(mapped.error ?? 'Gagal memuat statistik kelas',
            statusCode: mapped.statusCode);
      }
      return ApiResult.success(
        KelasStats.fromJson(
          (mapped.data?['data'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
        ),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(err.error ?? 'Gagal memuat statistik kelas',
          statusCode: err.statusCode);
    }
  }

  /// `GET /kelas/tingkat-options` → map kode → label (mis. `X` → `Kelas X`).
  Future<ApiResult<Map<String, String>>> tingkatOptions() async {
    try {
      final mapped = ApiResponseMapper.map(
          await _dio.get<dynamic>('/kelas/tingkat-options'));
      if (!mapped.ok) {
        return ApiResult.failure(mapped.error ?? 'Gagal memuat opsi tingkat',
            statusCode: mapped.statusCode);
      }
      final data = (mapped.data?['data'] as Map?) ?? const {};
      return ApiResult.success(
        data.map((k, v) => MapEntry('$k', '$v')),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(err.error ?? 'Gagal memuat opsi tingkat',
          statusCode: err.statusCode);
    }
  }
}
