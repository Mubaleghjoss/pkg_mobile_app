import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/paginated.dart';
import 'materi.dart';

/// Akses materi pembinaan (read-only untuk mobile).
///
/// Pembuatan/pengeditan materi tetap di web admin karena melibatkan unggah
/// PDF multi-berkas dan konfigurasi RPP; app hanya konsumen.
class MateriRepository {
  MateriRepository(this._dio);

  final Dio _dio;

  Future<ApiResult<Paginated<Materi>>> list({
    int page = 1,
    int perPage = 15,
    String? search,
    int? folderId,
    String? bulan,
  }) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>('/materi', queryParameters: {
          'page': page,
          'per_page': perPage,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          'folder_id': ?folderId,
          'bulan': ?bulan,
        }),
      );
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal memuat materi',
          statusCode: mapped.statusCode,
        );
      }
      final items = (mapped.data?['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Materi.fromJson(e.cast<String, dynamic>()))
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
      return ApiResult.failure(
        err.error ?? 'Gagal memuat materi',
        statusCode: err.statusCode,
      );
    }
  }

  Future<ApiResult<Materi>> detail(int id) async {
    try {
      final mapped =
          ApiResponseMapper.map(await _dio.get<dynamic>('/materi/$id'));
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal memuat materi',
          statusCode: mapped.statusCode,
        );
      }
      final data = (mapped.data?['data'] as Map?)?.cast<String, dynamic>();
      if (data == null) {
        return ApiResult.failure(
          'Respons materi tidak berisi data.',
          statusCode: mapped.statusCode,
        );
      }
      return ApiResult.success(
        Materi.fromJson(data),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? 'Gagal memuat materi',
        statusCode: err.statusCode,
      );
    }
  }

  /// Daftar folder materi untuk filter.
  Future<ApiResult<List<MateriFolder>>> folders() async {
    try {
      final mapped =
          ApiResponseMapper.map(await _dio.get<dynamic>('/materi/folders'));
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal memuat folder materi',
          statusCode: mapped.statusCode,
        );
      }
      final items = (mapped.data?['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => MateriFolder.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);
      return ApiResult.success(items, statusCode: mapped.statusCode);
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? 'Gagal memuat folder materi',
        statusCode: err.statusCode,
      );
    }
  }
}
