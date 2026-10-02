import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import 'chat_models.dart';

class ChatRepository {
  ChatRepository(this._dio);
  final Dio _dio;

  Future<ApiResult<List<ChatContact>>> contacts() async {
    try {
      final mapped = ApiResponseMapper.map(await _dio.get<dynamic>('/mobile/chat/contacts'));
      if (!mapped.ok) return ApiResult.failure(mapped.error ?? 'Gagal memuat kontak', statusCode: mapped.statusCode);
      final data = mapped.data?['data'];
      return ApiResult.success(
        (data is List ? data : const []).whereType<Map>().map((e) => ChatContact.fromJson(e.cast<String, dynamic>())).toList(growable: false),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final mapped = ApiResponseMapper.mapError(e);
      return ApiResult.failure(mapped.error ?? 'Gagal memuat kontak', statusCode: mapped.statusCode);
    }
  }

  Future<ApiResult<List<ChatMessage>>> messages({required String type, required int targetId}) async {
    try {
      final mapped = ApiResponseMapper.map(await _dio.get<dynamic>('/mobile/chat/messages', queryParameters: {'type': type, 'target_id': targetId}));
      if (!mapped.ok) return ApiResult.failure(mapped.error ?? 'Gagal memuat pesan', statusCode: mapped.statusCode);
      final data = mapped.data?['data'];
      return ApiResult.success(
        (data is List ? data : const []).whereType<Map>().map((e) => ChatMessage.fromJson(e.cast<String, dynamic>())).toList(growable: false),
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final mapped = ApiResponseMapper.mapError(e);
      return ApiResult.failure(mapped.error ?? 'Gagal memuat pesan', statusCode: mapped.statusCode);
    }
  }

  Future<ApiResult<ChatMessage>> send({required String type, required int targetId, required String message}) async {
    try {
      final mapped = ApiResponseMapper.map(await _dio.post<dynamic>('/mobile/chat/messages', data: {'type': type, 'target_id': targetId, 'message': message.trim()}));
      if (!mapped.ok) return ApiResult.failure(mapped.error ?? 'Gagal mengirim pesan', statusCode: mapped.statusCode);
      return ApiResult.success(ChatMessage.fromJson((mapped.data?['data'] as Map? ?? const {}).cast<String, dynamic>()), statusCode: mapped.statusCode);
    } catch (e) {
      final mapped = ApiResponseMapper.mapError(e);
      return ApiResult.failure(mapped.error ?? 'Gagal mengirim pesan', statusCode: mapped.statusCode);
    }
  }

  Future<ApiResult<void>> markRead({required String type, required int targetId}) async {
    try {
      final mapped = ApiResponseMapper.map(await _dio.post<dynamic>(
        '/mobile/chat/messages/read',
        data: {'type': type, 'target_id': targetId},
      ));
      if (!mapped.ok) return ApiResult.failure(mapped.error ?? 'Gagal menandai pesan dibaca', statusCode: mapped.statusCode);
      return ApiResult.success(null, statusCode: mapped.statusCode);
    } catch (e) {
      final mapped = ApiResponseMapper.mapError(e);
      return ApiResult.failure(mapped.error ?? 'Gagal menandai pesan dibaca', statusCode: mapped.statusCode);
    }
  }
}
