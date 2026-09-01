import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../siswa/domain/siswa.dart';
import '../domain/binaan.dart';

/// Akses sumber data AKTIF: Binaan Pamong + Kelas Sekolah.
///
/// Menggantikan `/kelas` yang oleh backend sendiri ditandai deprecated
/// ("Gunakan Binaan Pamong dan Kelas Sekolah untuk data aktif").
class BinaanRepository {
  BinaanRepository(this._dio);

  final Dio _dio;

  /// `GET /binaan-pamong` — daftar pamong + jumlah binaan aktif.
  ///
  /// Pamong biasa hanya menerima dirinya sendiri (`meta.scope = sendiri`);
  /// admin menerima seluruh pamong.
  Future<ApiResult<BinaanPamongRingkasan>> daftarPamong({String? search}) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>('/binaan-pamong', queryParameters: {
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        }),
      );
      if (!mapped.ok) {
        return ApiResult.failure(mapped.error ?? 'Gagal memuat binaan pamong',
            statusCode: mapped.statusCode);
      }
      final meta = (mapped.data?['meta'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final items = (mapped.data?['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => BinaanPamong.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);
      return ApiResult.success(
        BinaanPamongRingkasan(
          items: items,
          totalPamong: _int(meta['total_pamong']),
          totalBinaan: _int(meta['total_binaan']),
          scope: '${meta['scope'] ?? ''}',
        ),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(err.error ?? 'Gagal memuat binaan pamong',
          statusCode: err.statusCode);
    }
  }

  /// `GET /binaan-pamong/{id}/siswa` — generus yang dibina pamong tersebut.
  ///
  /// Server menolak 403 bila pamong membuka binaan pamong lain.
  Future<ApiResult<List<Siswa>>> siswaBinaan(int pamongId,
      {String? search}) async {
    return _listSiswa('/binaan-pamong/$pamongId/siswa', {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });
  }

  /// `GET /kelas-sekolah` — sebaran kelas sekolah (SMP 7 … SMA 12).
  ///
  /// `onlyUsed` menyaring kelas yang tidak punya generus, termasuk yang hanya
  /// terisi lewat taksiran level efektif.
  Future<ApiResult<KelasSekolahRingkasan>> daftarKelasSekolah({
    bool onlyUsed = false,
  }) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>('/kelas-sekolah', queryParameters: {
          if (onlyUsed) 'only_used': 1,
        }),
      );
      if (!mapped.ok) {
        return ApiResult.failure(mapped.error ?? 'Gagal memuat kelas sekolah',
            statusCode: mapped.statusCode);
      }
      final meta = (mapped.data?['meta'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final items = (mapped.data?['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => KelasSekolah.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);
      return ApiResult.success(
        KelasSekolahRingkasan(
          items: items,
          totalKelas: _int(meta['total_kelas']),
          totalSiswa: _int(meta['total_siswa']),
          belumDiisi: _int(meta['belum_diisi']),
          totalEfektif: _int(meta['total_efektif']),
        ),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(err.error ?? 'Gagal memuat kelas sekolah',
          statusCode: err.statusCode);
    }
  }

  /// `GET /kelas-sekolah/{kode}/siswa`.
  ///
  /// `effective` mencocokkan level efektif, bukan hanya kolom `school_grade`
  /// yang di banyak biodata masih kosong.
  Future<ApiResult<List<Siswa>>> siswaKelasSekolah(
    String kode, {
    String? search,
    bool effective = true,
  }) async {
    return _listSiswa('/kelas-sekolah/$kode/siswa', {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (effective) 'effective': 1,
    });
  }

  Future<ApiResult<List<Siswa>>> _listSiswa(
    String path,
    Map<String, dynamic> query,
  ) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>(path, queryParameters: query),
      );
      if (!mapped.ok) {
        return ApiResult.failure(mapped.error ?? 'Gagal memuat daftar generus',
            statusCode: mapped.statusCode);
      }
      final items = (mapped.data?['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Siswa.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);
      return ApiResult.success(items, statusCode: mapped.statusCode);
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(err.error ?? 'Gagal memuat daftar generus',
          statusCode: err.statusCode);
    }
  }

  static int _int(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
}
