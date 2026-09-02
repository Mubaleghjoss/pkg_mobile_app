import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import 'server_features_models.dart';

class ServerFeaturesRepository {
  ServerFeaturesRepository(this._dio);

  final Dio _dio;

  Future<ApiResult<ServerFeaturesDashboard>> list() async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>('/mobile/fitur-server'),
      );
      if (!mapped.ok || mapped.data == null) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal memuat fitur server',
          statusCode: mapped.statusCode,
          fieldErrors: mapped.fieldErrors,
        );
      }
      return ApiResult.success(
        ServerFeaturesDashboard.fromJson(mapped.data!),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? 'Gagal memuat fitur server',
        statusCode: err.statusCode,
        fieldErrors: err.fieldErrors,
      );
    }
  }

  /// Detail satu fitur: item lebih banyak + daftar aksi yang bisa dibuka.
  Future<ApiResult<ServerFeature>> detail(String kode, {int limit = 20}) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>(
          '/mobile/fitur-server',
          queryParameters: {'fitur': kode, 'limit': limit},
        ),
      );
      if (!mapped.ok || mapped.data == null) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal memuat detail fitur',
          statusCode: mapped.statusCode,
          fieldErrors: mapped.fieldErrors,
        );
      }
      final data = mapped.data!['data'];
      if (data is! Map) {
        return ApiResult.failure(
          'Format detail fitur tidak dikenali.',
          statusCode: mapped.statusCode,
        );
      }
      return ApiResult.success(
        ServerFeature.fromJson(data.cast<String, dynamic>()),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? 'Gagal memuat detail fitur',
        statusCode: err.statusCode,
        fieldErrors: err.fieldErrors,
      );
    }
  }

  /// Tukar token Sanctum dengan URL sesi web sekali pakai (umur 120 detik).
  ///
  /// Dipakai sebelum membuka halaman server ber-sesi di WebView; tanpa ini
  /// WebView hanya melihat halaman login.
  Future<ApiResult<WebBridgeTicket>> webBridge(String target) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.post<dynamic>(
          '/mobile/web-bridge',
          data: {'target': target},
        ),
      );
      if (!mapped.ok || mapped.data == null) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal membuka sesi halaman server',
          statusCode: mapped.statusCode,
          fieldErrors: mapped.fieldErrors,
        );
      }
      final data = mapped.data!['data'];
      if (data is! Map) {
        return ApiResult.failure(
          'Server tidak mengirim tautan sesi.',
          statusCode: mapped.statusCode,
        );
      }
      return ApiResult.success(
        WebBridgeTicket.fromJson(data.cast<String, dynamic>()),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        err.error ?? 'Gagal membuka sesi halaman server',
        statusCode: err.statusCode,
        fieldErrors: err.fieldErrors,
      );
    }
  }
}
