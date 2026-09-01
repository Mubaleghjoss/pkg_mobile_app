import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/paginated.dart';
import 'tugas_pkg.dart';

/// Akses Tugas PKG untuk akun siswa & orang tua.
///
/// Token siswa boleh submit; token ortu hanya boleh melihat dan berkomentar
/// (backend menegakkan lewat ability token, app hanya menyesuaikan UI).
class TugasRepository {
  TugasRepository(this._dio);

  final Dio _dio;

  /// Daftar tugas + ringkasan untuk satu tanggal (`YYYY-MM-DD`).
  Future<ApiResult<TugasHarian>> harian({String? date}) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>(
          '/tugas-pkg',
          queryParameters: {'date': ?date},
        ),
      );
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal memuat tugas',
          statusCode: mapped.statusCode,
        );
      }
      final items = (mapped.data?['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => TugasPkg.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);
      return ApiResult.success(
        TugasHarian(
          items: items,
          meta: TugasHarianMeta.fromJson(
            (mapped.data?['meta'] as Map?)?.cast<String, dynamic>() ??
                const <String, dynamic>{},
          ),
        ),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? 'Gagal memuat tugas',
        statusCode: err.statusCode,
      );
    }
  }

  /// Riwayat pengerjaan (terpaginasi, termasuk komentar orang tua).
  ///
  /// [onlyUnverified] memetakan query `only_unverified` di backend, dipakai
  /// filter "Belum diverifikasi" pada layar riwayat.
  Future<ApiResult<Paginated<TugasChecklist>>> history({
    int page = 1,
    int perPage = 15,
    bool onlyUnverified = false,
  }) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>('/tugas-pkg/history', queryParameters: {
          'page': page,
          'per_page': perPage,
          if (onlyUnverified) 'only_unverified': 1,
        }),
      );
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal memuat riwayat tugas',
          statusCode: mapped.statusCode,
        );
      }
      final items = (mapped.data?['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => TugasChecklist.fromJson(e.cast<String, dynamic>()))
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
        err.error ?? 'Gagal memuat riwayat tugas',
        statusCode: err.statusCode,
      );
    }
  }

  /// Kerjakan satu tugas. `clickCount` hanya untuk jenis `klik`,
  /// `hasilTeks` wajib untuk jenis `teks`.
  Future<ApiResult<TugasChecklist>> submit(
    int karakterId, {
    String? hasilTeks,
    String? studentNote,
    int? clickCount,
  }) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.post<dynamic>(
          '/tugas-pkg/$karakterId/submit',
          data: {
            if (hasilTeks != null && hasilTeks.trim().isNotEmpty)
              'hasil_teks': hasilTeks.trim(),
            if (studentNote != null && studentNote.trim().isNotEmpty)
              'student_note': studentNote.trim(),
            'click_count': ?clickCount,
          },
          options: Options(headers: {'Content-Type': 'application/json'}),
        ),
      );
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal mengirim tugas',
          statusCode: mapped.statusCode,
          fieldErrors: mapped.fieldErrors,
        );
      }
      final data = (mapped.data?['data'] as Map?)?.cast<String, dynamic>();
      if (data == null) {
        return ApiResult.failure(
          'Respons tidak berisi data pengerjaan.',
          statusCode: mapped.statusCode,
        );
      }
      return ApiResult.success(
        TugasChecklist.fromJson(data),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? 'Gagal mengirim tugas',
        statusCode: err.statusCode,
        fieldErrors: err.fieldErrors,
      );
    }
  }

  /// Komentar orang tua pada satu pengerjaan (hanya token ortu).
  Future<ApiResult<OrtuKomentar>> comment(
    int checklistId,
    String comment,
  ) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.post<dynamic>(
          '/tugas-pkg/checklist/$checklistId/comment',
          data: {'comment': comment.trim()},
          options: Options(headers: {'Content-Type': 'application/json'}),
        ),
      );
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal mengirim komentar',
          statusCode: mapped.statusCode,
          fieldErrors: mapped.fieldErrors,
        );
      }
      return ApiResult.success(
        OrtuKomentar.fromJson(
          (mapped.data?['data'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
        ),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? 'Gagal mengirim komentar',
        statusCode: err.statusCode,
        fieldErrors: err.fieldErrors,
      );
    }
  }

  /// Ringkasan lintas hari untuk dashboard.
  Future<ApiResult<Map<String, dynamic>>> summary() async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>('/tugas-pkg/summary'),
      );
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal memuat ringkasan tugas',
          statusCode: mapped.statusCode,
        );
      }
      return ApiResult.success(
        (mapped.data?['data'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? 'Gagal memuat ringkasan tugas',
        statusCode: err.statusCode,
      );
    }
  }
}
