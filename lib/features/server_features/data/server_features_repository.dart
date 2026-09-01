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
}
