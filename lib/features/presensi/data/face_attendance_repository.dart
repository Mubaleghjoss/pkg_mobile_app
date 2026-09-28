import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';

/// Profil wajah milik akun yang sedang login.
class FaceProfileStatus {
  const FaceProfileStatus({
    required this.configured,
    required this.subjectType,
    this.profileId,
    this.status,
    this.enrolledAt,
    this.lastUsedAt,
  });

  factory FaceProfileStatus.fromJson(Map<String, dynamic> json) =>
      FaceProfileStatus(
        configured: json['configured'] == true,
        subjectType: json['subject_type']?.toString() ?? 'unknown',
        profileId: _int(json['profile_id']),
        status: json['status']?.toString(),
        enrolledAt: json['enrolled_at']?.toString(),
        lastUsedAt: json['last_used_at']?.toString(),
      );

  final bool configured;
  final String subjectType;
  final int? profileId;
  final String? status;
  final String? enrolledAt;
  final String? lastUsedAt;

  static int? _int(Object? value) =>
      value is int ? value : int.tryParse('$value');
}

/// Respons native scan/enroll. Payload descriptor dibuat oleh fitur kamera,
/// repository hanya mengirimkannya tanpa mengubah format server.
class FaceAttendanceResponse {
  const FaceAttendanceResponse({
    required this.success,
    required this.message,
    this.data,
    this.student,
    this.pamong,
    this.statusCode,
  });

  factory FaceAttendanceResponse.fromJson(
    Map<String, dynamic> json, {
    int? statusCode,
  }) => FaceAttendanceResponse(
    success: json['success'] == true,
    message:
        json['message']?.toString() ?? 'Respons server tidak memiliki pesan.',
    data: (json['data'] as Map?)?.cast<String, dynamic>(),
    student: (json['student'] as Map?)?.cast<String, dynamic>(),
    pamong: (json['pamong'] as Map?)?.cast<String, dynamic>(),
    statusCode: statusCode,
  );

  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? student;
  final Map<String, dynamic>? pamong;
  final int? statusCode;
}

class FaceAttendanceRepository {
  FaceAttendanceRepository(this._dio);

  final Dio _dio;

  Future<ApiResult<FaceProfileStatus>> profile() async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>('/presensi-wajah/profile'),
      );
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal memuat status profil wajah.',
          statusCode: mapped.statusCode,
        );
      }
      final data =
          (mapped.data?['data'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      return ApiResult.success(
        FaceProfileStatus.fromJson(data),
        statusCode: mapped.statusCode,
      );
    } catch (error) {
      final mapped = ApiResponseMapper.mapError(error);
      return ApiResult.failure(
        mapped.error ?? 'Gagal memuat status profil wajah.',
        statusCode: mapped.statusCode,
      );
    }
  }

  Future<ApiResult<FaceAttendanceResponse>> enroll({
    required List<num> descriptor,
    required String referenceImage,
    String? clientCapturedAt,
  }) => _send(
    '/presensi-wajah/enroll',
    data: {
      'descriptor': descriptor,
      'reference_image': referenceImage,
      'client_captured_at': ?clientCapturedAt,
    },
    fallback: 'Gagal menyimpan profil wajah.',
  );

  Future<ApiResult<FaceAttendanceResponse>> scan({
    required List<num> descriptor,
    required String proofImage,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    String? clientCapturedAt,
  }) => _send(
    '/presensi-wajah/scan',
    data: {
      'descriptor': descriptor,
      'proof_image': proofImage,
      'location': {
        'lat': latitude,
        'lng': longitude,
        'accuracy_meters': accuracyMeters,
      },
      'client_captured_at': ?clientCapturedAt,
    },
    fallback: 'Gagal memproses scan wajah.',
  );

  Future<ApiResult<FaceAttendanceResponse>> _send(
    String path, {
    required Map<String, dynamic> data,
    required String fallback,
  }) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.post<dynamic>(path, data: data),
      );
      final response = FaceAttendanceResponse.fromJson(
        mapped.data ?? const <String, dynamic>{},
        statusCode: mapped.statusCode,
      );
      if (!mapped.ok || !response.success) {
        return ApiResult.failure(
          response.message.isNotEmpty ? response.message : fallback,
          statusCode: mapped.statusCode,
        );
      }
      return ApiResult.success(response, statusCode: mapped.statusCode);
    } catch (error) {
      final mapped = ApiResponseMapper.mapError(error);
      final body = _errorBody(mapped.data);
      return ApiResult.failure(
        body ?? mapped.error ?? fallback,
        statusCode: mapped.statusCode,
      );
    }
  }

  String? _errorBody(Map<String, dynamic>? data) {
    final message = data?['message']?.toString();
    if (message != null && message.isNotEmpty) return message;
    final errors = data?['errors'];
    return errors is Map ? jsonEncode(errors) : null;
  }
}
