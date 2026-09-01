import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../domain/calendar_event.dart';

/// Akses read-only event kalender yang cakupannya sudah dibatasi server.
class CalendarRepository {
  CalendarRepository(this._dio);

  final Dio _dio;

  Future<ApiResult<List<CalendarEvent>>> events({
    required DateTime start,
    required DateTime end,
  }) async {
    final format = DateFormat('yyyy-MM-dd');
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>(
          '/calendar/events',
          queryParameters: <String, dynamic>{
            'start': format.format(start),
            'end': format.format(end),
          },
        ),
      );
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal memuat kalender',
          statusCode: mapped.statusCode,
        );
      }
      final events = (mapped.data?['data'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) => CalendarEvent.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false);
      return ApiResult.success(events, statusCode: mapped.statusCode);
    } catch (error) {
      final mapped = ApiResponseMapper.mapError(error);
      return ApiResult.failure(
        mapped.error ?? 'Gagal memuat kalender',
        statusCode: mapped.statusCode,
      );
    }
  }
}
