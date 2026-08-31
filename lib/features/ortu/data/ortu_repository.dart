import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/paginated.dart';
import 'ortu_models.dart';

/// Monitoring orang tua (token ortu, read-only).
///
/// Endpoint (terverifikasi lewat curl pada backend lokal):
/// - `GET /ortu/ringkasan` — rekap tugas + presensi + Quran dalam satu panggilan
/// - `GET /ortu/tugas?status=all|verified|unverified&page=`
/// - `GET /ortu/presensi?page=&per_page=`
/// - `GET /ortu/quran`
///
/// Token siswa TIDAK boleh memakai endpoint ini (backend menolak 403
/// `ORTU_ONLY`); sebaliknya ortu ditolak pada submit tugas (`ORTU_READ_ONLY`).
class OrtuRepository {
  OrtuRepository(this._dio);

  final Dio _dio;

  Future<ApiResult<OrtuRingkasan>> ringkasan() async {
    try {
      final mapped =
          ApiResponseMapper.map(await _dio.get<dynamic>('/ortu/ringkasan'));
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal memuat ringkasan',
          statusCode: mapped.statusCode,
        );
      }
      final data = (mapped.data?['data'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      return ApiResult.success(
        OrtuRingkasan.fromJson(data),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? 'Gagal memuat ringkasan',
        statusCode: err.statusCode,
      );
    }
  }

  Future<ApiResult<OrtuTugasHalaman>> tugas({
    String status = 'all',
    int page = 1,
    int perPage = 15,
  }) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>(
          '/ortu/tugas',
          queryParameters: {
            'status': status,
            'page': page,
            'per_page': perPage,
          },
        ),
      );
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal memuat tugas anak',
          statusCode: mapped.statusCode,
        );
      }
      final items = (mapped.data?['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => OrtuTugasItem.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);
      final metaMap =
          (mapped.data?['meta'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
      return ApiResult.success(
        OrtuTugasHalaman(
          page: Paginated(
            items: items,
            meta: PageMeta.fromResponse(mapped.data, itemCount: items.length),
          ),
          rekap: OrtuTugasRekap.fromJson(metaMap),
        ),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? 'Gagal memuat tugas anak',
        statusCode: err.statusCode,
      );
    }
  }

  Future<ApiResult<OrtuPresensiHalaman>> presensi({
    int page = 1,
    int perPage = 15,
  }) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>(
          '/ortu/presensi',
          queryParameters: {'page': page, 'per_page': perPage},
        ),
      );
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal memuat presensi anak',
          statusCode: mapped.statusCode,
        );
      }
      final items = (mapped.data?['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => OrtuPresensiItem.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);
      final metaMap =
          (mapped.data?['meta'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
      return ApiResult.success(
        OrtuPresensiHalaman(
          page: Paginated(
            items: items,
            meta: PageMeta.fromResponse(mapped.data, itemCount: items.length),
          ),
          totals: PresensiTotals.fromJson(
            (metaMap['totals'] as Map?)?.cast<String, dynamic>() ??
                const <String, dynamic>{},
          ),
          bulanan: (metaMap['bulanan'] as List? ?? const [])
              .whereType<Map>()
              .map((e) => PresensiBulanan.fromJson(e.cast<String, dynamic>()))
              .toList(growable: false),
        ),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? 'Gagal memuat presensi anak',
        statusCode: err.statusCode,
      );
    }
  }

  Future<ApiResult<OrtuQuranRekap>> quran() async {
    try {
      final mapped =
          ApiResponseMapper.map(await _dio.get<dynamic>('/ortu/quran'));
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal memuat progres Quran anak',
          statusCode: mapped.statusCode,
        );
      }
      final data = (mapped.data?['data'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      return ApiResult.success(
        OrtuQuranRekap.fromJson(data),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? 'Gagal memuat progres Quran anak',
        statusCode: err.statusCode,
      );
    }
  }
}

class OrtuTugasHalaman {
  const OrtuTugasHalaman({required this.page, required this.rekap});

  final Paginated<OrtuTugasItem> page;
  final OrtuTugasRekap rekap;
}

class OrtuPresensiHalaman {
  const OrtuPresensiHalaman({
    required this.page,
    required this.totals,
    required this.bulanan,
  });

  final Paginated<OrtuPresensiItem> page;
  final PresensiTotals totals;
  final List<PresensiBulanan> bulanan;
}
