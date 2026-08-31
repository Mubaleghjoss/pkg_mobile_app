import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/paginated.dart';
import 'gamifikasi_models.dart';

/// Gamifikasi: poin, level, peringkat, riwayat poin, badge.
///
/// Semua endpoint memakai token model Siswa (siswa penuh; orang tua boleh
/// membaca). Token staf ditolak backend dengan 403 `STAFF_TOKEN_NOT_ALLOWED`.
///
/// Endpoint (terverifikasi lewat curl pada backend lokal):
/// - `GET /gamifikasi/ringkasan`
/// - `GET /gamifikasi/leaderboard?periode=all|daily|weekly|monthly&limit=`
/// - `GET /gamifikasi/history?sumber=&per_page=&page=`
/// - `GET /gamifikasi/badges`
class GamifikasiRepository {
  GamifikasiRepository(this._dio);

  final Dio _dio;

  Future<ApiResult<GamifikasiRingkasan>> ringkasan() async {
    return _get(
      '/gamifikasi/ringkasan',
      gagal: 'Gagal memuat ringkasan poin',
      parse: (body) => GamifikasiRingkasan.fromJson(
        (body['data'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
    );
  }

  Future<ApiResult<LeaderboardHalaman>> leaderboard({
    String periode = 'all',
    int limit = 20,
  }) async {
    return _get(
      '/gamifikasi/leaderboard',
      query: {'periode': periode, 'limit': limit},
      gagal: 'Gagal memuat papan peringkat',
      parse: (body) => LeaderboardHalaman.fromJson(
        (body['data'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
    );
  }

  /// Riwayat poin. [sumber] null = semua sumber.
  Future<ApiResult<Paginated<PoinTransaksi>>> history({
    String? sumber,
    int page = 1,
    int perPage = 20,
  }) async {
    return _get(
      '/gamifikasi/history',
      query: {
        if (sumber != null && sumber.isNotEmpty) 'sumber': sumber,
        'page': page,
        'per_page': perPage,
      },
      gagal: 'Gagal memuat riwayat poin',
      parse: (body) {
        final items = (body['data'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => PoinTransaksi.fromJson(e.cast<String, dynamic>()))
            .toList(growable: false);
        return Paginated<PoinTransaksi>(
          items: items,
          meta: PageMeta.fromResponse(body, itemCount: items.length),
        );
      },
    );
  }

  Future<ApiResult<List<BadgeItem>>> badges() async {
    return _get(
      '/gamifikasi/badges',
      gagal: 'Gagal memuat badge',
      parse: (body) => (body['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => BadgeItem.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }

  /// Pembungkus GET: memetakan error jaringan/HTTP ke [ApiResult] tanpa throw.
  Future<ApiResult<T>> _get<T>(
    String path, {
    required String gagal,
    required T Function(Map<String, dynamic> body) parse,
    Map<String, dynamic>? query,
  }) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>(path, queryParameters: query),
      );
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? gagal,
          statusCode: mapped.statusCode,
        );
      }
      return ApiResult.success(
        parse(mapped.data ?? const <String, dynamic>{}),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? gagal,
        statusCode: err.statusCode,
      );
    }
  }
}
