import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/paginated.dart';
import 'quran_models.dart';

/// Akses tracer bacaan Al-Quran.
///
/// App hanya menangani entri manual dan menampilkan progres; alur scan lembar
/// (barcode) tetap di web karena melibatkan verifikasi pamong.
class QuranRepository {
  QuranRepository(this._dio);

  final Dio _dio;

  Future<ApiResult<Paginated<QuranEntry>>> entries({
    int page = 1,
    int perPage = 15,
    String? status,
  }) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>('/quran/entries', queryParameters: {
          'page': page,
          'per_page': perPage,
          'status': ?status,
        }),
      );
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal memuat catatan bacaan',
          statusCode: mapped.statusCode,
        );
      }
      final items = (mapped.data?['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => QuranEntry.fromJson(e.cast<String, dynamic>()))
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
        err.error ?? 'Gagal memuat catatan bacaan',
        statusCode: err.statusCode,
      );
    }
  }

  Future<ApiResult<QuranProgress>> progress() async {
    try {
      final mapped =
          ApiResponseMapper.map(await _dio.get<dynamic>('/quran/progress'));
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal memuat progres bacaan',
          statusCode: mapped.statusCode,
        );
      }
      return ApiResult.success(
        QuranProgress.fromJson(
          (mapped.data?['data'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
        ),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? 'Gagal memuat progres bacaan',
        statusCode: err.statusCode,
      );
    }
  }

  /// Katalog 114 surah (`nomor`, `nama`, `ayah_count`).
  Future<ApiResult<List<QuranSurah>>> surahs() async {
    try {
      final mapped =
          ApiResponseMapper.map(await _dio.get<dynamic>('/quran/surahs'));
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal memuat daftar surah',
          statusCode: mapped.statusCode,
        );
      }
      final items = (mapped.data?['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => QuranSurah.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);
      return ApiResult.success(items, statusCode: mapped.statusCode);
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? 'Gagal memuat daftar surah',
        statusCode: err.statusCode,
      );
    }
  }

  /// Catat bacaan baru. Backend mewajibkan minimal satu dari rentang halaman
  /// atau rentang surah/ayah.
  Future<ApiResult<QuranEntry>> store({
    required String readingDate,
    int? pageStart,
    int? pageEnd,
    int? surahStart,
    int? ayahStart,
    int? surahEnd,
    int? ayahEnd,
    String? mushafLabel,
    String? notes,
  }) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.post<dynamic>(
          '/quran/entries',
          data: {
            'reading_date': readingDate,
            'page_start': ?pageStart,
            'page_end': ?pageEnd,
            'surah_start': ?surahStart,
            'ayah_start': ?ayahStart,
            'surah_end': ?surahEnd,
            'ayah_end': ?ayahEnd,
            if (mushafLabel != null && mushafLabel.trim().isNotEmpty)
              'mushaf_label': mushafLabel.trim(),
            if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          },
          options: Options(headers: {'Content-Type': 'application/json'}),
        ),
      );
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal menyimpan catatan bacaan',
          statusCode: mapped.statusCode,
          fieldErrors: mapped.fieldErrors,
        );
      }
      final data = (mapped.data?['data'] as Map?)?.cast<String, dynamic>();
      if (data == null) {
        return ApiResult.failure(
          'Respons tidak berisi data catatan.',
          statusCode: mapped.statusCode,
        );
      }
      return ApiResult.success(
        QuranEntry.fromJson(data),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? 'Gagal menyimpan catatan bacaan',
        statusCode: err.statusCode,
        fieldErrors: err.fieldErrors,
      );
    }
  }

  /// Hapus entri manual yang masih pending.
  Future<ApiResult<bool>> destroy(int id) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.delete<dynamic>('/quran/entries/$id'),
      );
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal menghapus catatan',
          statusCode: mapped.statusCode,
        );
      }
      return ApiResult.success(true, statusCode: mapped.statusCode);
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? 'Gagal menghapus catatan',
        statusCode: err.statusCode,
      );
    }
  }
}
