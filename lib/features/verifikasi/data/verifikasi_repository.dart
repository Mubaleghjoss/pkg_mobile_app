import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/paginated.dart';
import 'verifikasi_models.dart';

/// Antrean verifikasi tugas PKG untuk akun pamong/admin (token model `User`).
///
/// Endpoint (terverifikasi lewat curl pada backend lokal):
/// - `GET    /pamong/verifikasi?status=unverified|verified|all&siswa_id=&q=&page=`
/// - `POST   /pamong/verifikasi/{checklist}`      body `{notes?}`
/// - `DELETE /pamong/verifikasi/{checklist}`      body `{reason?}`
/// - `POST   /pamong/verifikasi/bulk`             body `{ids: [], notes?}`
///
/// Pamong hanya melihat/menyentuh siswa binaan (`meta.scope == 'assigned'`);
/// admin memperoleh `scope == 'all'`. Percobaan menyentuh siswa non-binaan
/// ditolak backend dengan 403 `SISWA_NOT_ASSIGNED`.
class VerifikasiRepository {
  VerifikasiRepository(this._dio);

  final Dio _dio;

  Future<ApiResult<AntreanVerifikasi>> list({
    String status = 'unverified',
    int page = 1,
    int perPage = 15,
    int? siswaId,
    String? q,
  }) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>(
          '/pamong/verifikasi',
          queryParameters: {
            'status': status,
            'page': page,
            'per_page': perPage,
            'siswa_id': ?siswaId,
            if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          },
        ),
      );
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal memuat antrean verifikasi',
          statusCode: mapped.statusCode,
        );
      }
      final items = (mapped.data?['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => VerifikasiItem.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);
      final metaMap =
          (mapped.data?['meta'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
      return ApiResult.success(
        AntreanVerifikasi(
          page: Paginated(
            items: items,
            meta: PageMeta.fromResponse(mapped.data, itemCount: items.length),
          ),
          ringkasan: VerifikasiMeta.fromJson(metaMap),
        ),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? 'Gagal memuat antrean verifikasi',
        statusCode: err.statusCode,
      );
    }
  }

  /// Verifikasi satu checklist. Mengembalikan item terbaru + poin yang diberikan.
  Future<ApiResult<HasilVerifikasi>> verify(int checklistId,
      {String? notes}) async {
    return _mutate(
      () => _dio.post<dynamic>(
        '/pamong/verifikasi/$checklistId',
        data: {if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim()},
      ),
      poinKey: 'poin_diberikan',
      fallbackError: 'Gagal memverifikasi tugas',
    );
  }

  /// Batalkan verifikasi; backend menarik kembali poin yang sudah diberikan.
  Future<ApiResult<HasilVerifikasi>> unverify(int checklistId,
      {String? reason}) async {
    return _mutate(
      () => _dio.delete<dynamic>(
        '/pamong/verifikasi/$checklistId',
        data: {
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        },
      ),
      poinKey: 'poin_ditarik',
      fallbackError: 'Gagal membatalkan verifikasi',
    );
  }

  /// Verifikasi massal (maks 50 id). Item yang gagal dilaporkan per id,
  /// bukan membatalkan seluruh batch.
  Future<ApiResult<BulkVerifikasiHasil>> bulkVerify(
    List<int> ids, {
    String? notes,
  }) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.post<dynamic>(
          '/pamong/verifikasi/bulk',
          data: {
            'ids': ids,
            if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          },
        ),
      );
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal verifikasi massal',
          statusCode: mapped.statusCode,
        );
      }
      return ApiResult.success(
        BulkVerifikasiHasil.fromJson(mapped.data ?? const <String, dynamic>{}),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? 'Gagal verifikasi massal',
        statusCode: err.statusCode,
      );
    }
  }

  Future<ApiResult<HasilVerifikasi>> _mutate(
    Future<Response<dynamic>> Function() call, {
    required String poinKey,
    required String fallbackError,
  }) async {
    try {
      final mapped = ApiResponseMapper.map(await call());
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? fallbackError,
          statusCode: mapped.statusCode,
        );
      }
      final body = mapped.data ?? const <String, dynamic>{};
      final data = (body['data'] as Map?)?.cast<String, dynamic>();
      final meta = (body['meta'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      return ApiResult.success(
        HasilVerifikasi(
          item: data == null ? null : VerifikasiItem.fromJson(data),
          poin: meta[poinKey] is int
              ? meta[poinKey] as int
              : int.tryParse('${meta[poinKey]}') ?? 0,
          pesan: '${body['message'] ?? ''}',
        ),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? fallbackError,
        statusCode: err.statusCode,
      );
    }
  }
}

class AntreanVerifikasi {
  const AntreanVerifikasi({required this.page, required this.ringkasan});

  final Paginated<VerifikasiItem> page;
  final VerifikasiMeta ringkasan;
}

class HasilVerifikasi {
  const HasilVerifikasi({
    required this.item,
    required this.poin,
    required this.pesan,
  });

  final VerifikasiItem? item;
  final int poin;
  final String pesan;
}
