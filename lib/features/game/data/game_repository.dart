import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import 'game_models.dart';

/// Game karakter luhur: sesi solo (tebak/rangkai) dan skor arcade.
///
/// Kunci jawaban tidak pernah dikirim ke klien: server menyimpannya di cache
/// dengan token acak (berlaku 30 menit, sekali pakai). Klien mengirim token +
/// daftar jawaban, server menilai dan memberi poin (source `game`).
///
/// Endpoint (terverifikasi lewat curl pada backend lokal):
/// - `GET  /game/info`
/// - `POST /game/solo/mulai`   body `{mode, jumlah}`
/// - `POST /game/solo/submit`  body `{token, jawaban[]}`
/// - `GET  /game/arcade/kata`
/// - `POST /game/arcade/skor`  body `{skor, combo}`
/// - `GET  /game/arcade/leaderboard`
///
/// Akun orang tua ditolak 403 `ORTU_READ_ONLY` untuk semua aksi bermain.
class GameRepository {
  GameRepository(this._dio);

  final Dio _dio;

  Future<ApiResult<GameInfo>> info() => _call(
        () => _dio.get<dynamic>('/game/info'),
        gagal: 'Gagal memuat info game',
        parse: (body) => GameInfo.fromJson(_dataMap(body)),
      );

  /// Mulai sesi solo. [jumlah] dibatasi backend ke 3..10.
  Future<ApiResult<GameSesi>> mulaiSolo({
    required GameMode mode,
    int jumlah = 5,
  }) =>
      _call(
        () => _dio.post<dynamic>(
          '/game/solo/mulai',
          data: {'mode': mode.kode, 'jumlah': jumlah},
        ),
        gagal: 'Gagal memulai game',
        parse: (body) => GameSesi.fromJson(_dataMap(body)),
      );

  /// Kirim jawaban. Urutan [jawaban] harus sama dengan urutan soal.
  Future<ApiResult<GameHasil>> submitSolo({
    required String token,
    required List<String> jawaban,
  }) =>
      _call(
        () => _dio.post<dynamic>(
          '/game/solo/submit',
          data: {'token': token, 'jawaban': jawaban},
        ),
        gagal: 'Gagal mengirim jawaban',
        parse: (body) => GameHasil.fromJson(_dataMap(body)),
      );

  Future<ApiResult<List<String>>> arcadeKata() => _call(
        () => _dio.get<dynamic>('/game/arcade/kata'),
        gagal: 'Gagal memuat kata arcade',
        parse: (body) => (_dataMap(body)['kata'] as List? ?? const [])
            .map((e) => '$e')
            .toList(growable: false),
      );

  /// Simpan skor arcade. Server hanya menyimpan bila lebih tinggi dari rekor.
  Future<ApiResult<bool>> simpanSkorArcade({
    required int skor,
    required int combo,
  }) =>
      _call(
        () => _dio.post<dynamic>(
          '/game/arcade/skor',
          data: {'skor': skor, 'combo': combo},
        ),
        gagal: 'Gagal menyimpan skor',
        parse: (body) => _dataMap(body)['rekor_baru'] == true,
      );

  Future<ApiResult<List<ArcadeSkor>>> arcadeLeaderboard() => _call(
        () => _dio.get<dynamic>('/game/arcade/leaderboard'),
        gagal: 'Gagal memuat papan skor',
        parse: (body) => (body['data'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => ArcadeSkor.fromJson(e.cast<String, dynamic>()))
            .toList(growable: false),
      );

  static Map<String, dynamic> _dataMap(Map<String, dynamic> body) =>
      (body['data'] as Map?)?.cast<String, dynamic>() ??
      const <String, dynamic>{};

  Future<ApiResult<T>> _call<T>(
    Future<Response<dynamic>> Function() request, {
    required String gagal,
    required T Function(Map<String, dynamic> body) parse,
  }) async {
    try {
      final mapped = ApiResponseMapper.map(await request());
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
