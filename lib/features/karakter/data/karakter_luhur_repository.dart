import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import 'karakter_luhur.dart';

/// Akses `GET /api/v1/karakter-luhur` dan `/karakter-luhur/{slug}`.
///
/// Endpoint read-only dan tidak butuh token (berada di grup publik API v1),
/// sehingga daftar 29 karakter tetap bisa dibaca sebelum login.
class KarakterLuhurRepository {
  KarakterLuhurRepository(this._dio);

  final Dio _dio;

  /// Daftar ringkas 29 karakter. `kategori` opsional untuk memfilter.
  Future<ApiResult<List<KarakterLuhur>>> list({String? kategori}) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>(
          '/karakter-luhur',
          queryParameters: {'kategori': ?kategori},
        ),
      );
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal memuat 29 karakter',
          statusCode: mapped.statusCode,
        );
      }
      final items = (mapped.data?['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => KarakterLuhur.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);
      return ApiResult.success(items, statusCode: mapped.statusCode);
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? 'Gagal memuat 29 karakter',
        statusCode: err.statusCode,
      );
    }
  }

  /// Detail lengkap satu karakter. Backend menerima slug maupun nomor urut.
  Future<ApiResult<KarakterLuhur>> detail(String slugOrNomor) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>('/karakter-luhur/$slugOrNomor'),
      );
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal memuat materi karakter',
          statusCode: mapped.statusCode,
        );
      }
      final data = (mapped.data?['data'] as Map?)?.cast<String, dynamic>();
      if (data == null) {
        return ApiResult.failure(
          'Respons tidak berisi data karakter.',
          statusCode: mapped.statusCode,
        );
      }
      return ApiResult.success(
        KarakterLuhur.fromJson(data),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? 'Gagal memuat materi karakter',
        statusCode: err.statusCode,
      );
    }
  }
}
