import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';

/// Ringkasan dashboard dari `GET /api/v1/dashboard/stats`.
class DashboardStats {
  const DashboardStats({
    required this.totalStudents,
    required this.presentToday,
    required this.absentToday,
    required this.lateToday,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
        totalStudents: json['total_students'] as int? ?? 0,
        presentToday: json['present_today'] as int? ?? 0,
        absentToday: json['absent_today'] as int? ?? 0,
        lateToday: json['late_today'] as int? ?? 0,
      );

  final int totalStudents;
  final int presentToday;
  final int absentToday;
  final int lateToday;
}

/// Baris aktivitas dari `GET /api/v1/dashboard/recent-activities`.
class RecentActivity {
  const RecentActivity({
    required this.id,
    required this.studentName,
    required this.action,
    required this.time,
  });

  factory RecentActivity.fromJson(Map<String, dynamic> json) => RecentActivity(
        id: json['id'] as int? ?? 0,
        studentName: '${json['student_name'] ?? '-'}',
        action: '${json['action'] ?? ''}',
        time: '${json['time'] ?? ''}',
      );

  final int id;
  final String studentName;
  final String action;
  final String time;
}

class DashboardRepository {
  DashboardRepository(this._dio);

  final Dio _dio;

  Future<ApiResult<DashboardStats>> stats() async {
    try {
      final mapped =
          ApiResponseMapper.map(await _dio.get<dynamic>('/dashboard/stats'));
      if (!mapped.ok) {
        return ApiResult.failure(mapped.error ?? 'Gagal memuat dashboard',
            statusCode: mapped.statusCode);
      }
      return ApiResult.success(
        DashboardStats.fromJson(
          (mapped.data?['data'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
        ),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(err.error ?? 'Gagal memuat dashboard',
          statusCode: err.statusCode);
    }
  }

  Future<ApiResult<List<RecentActivity>>> recentActivities() async {
    try {
      final mapped = ApiResponseMapper.map(
          await _dio.get<dynamic>('/dashboard/recent-activities'));
      if (!mapped.ok) {
        return ApiResult.failure(mapped.error ?? 'Gagal memuat aktivitas',
            statusCode: mapped.statusCode);
      }
      final items = (mapped.data?['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => RecentActivity.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);
      return ApiResult.success(items, statusCode: mapped.statusCode);
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(err.error ?? 'Gagal memuat aktivitas',
          statusCode: err.statusCode);
    }
  }
}
