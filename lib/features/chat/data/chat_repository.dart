import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';

class ChatContact {
  const ChatContact({required this.id, required this.type, required this.name, this.subtitle});
  final int id;
  final String type;
  final String name;
  final String? subtitle;

  factory ChatContact.fromJson(Map<String, dynamic> json) => ChatContact(
    id: int.tryParse('${json['id']}') ?? 0,
    type: '${json['type'] ?? ''}',
    name: '${json['name'] ?? ''}',
    subtitle: json['subtitle'] as String?,
  );
}

class ChatMessage {
  const ChatMessage({required this.id, required this.message, required this.isMine, required this.createdAt});
  final int id;
  final String message;
  final bool isMine;
  final DateTime? createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: int.tryParse('${json['id']}') ?? 0,
    message: '${json['message'] ?? ''}',
    isMine: json['is_mine'] == true,
    createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
  );
}

class ChatRepository {
  ChatRepository(this._dio);
  final Dio _dio;

  Future<ApiResult<List<ChatContact>>> contacts() async {
    try {
      final mapped = ApiResponseMapper.map(await _dio.get<dynamic>('/mobile/chat/contacts'));
      if (!mapped.ok) return ApiResult.failure(mapped.error ?? 'Gagal memuat kontak', statusCode: mapped.statusCode);
      final rows = (mapped.data?['data'] as List? ?? const []).whereType<Map>().map((e) => ChatContact.fromJson(e.cast<String, dynamic>())).toList();
      return ApiResult.success(rows, statusCode: mapped.statusCode);
    } catch (e) {
      final mapped = ApiResponseMapper.mapError(e);
      return ApiResult.failure(mapped.error ?? 'Gagal memuat kontak', statusCode: mapped.statusCode);
    }
  }

  Future<ApiResult<List<ChatMessage>>> messages(ChatContact contact) async {
    try {
      final mapped = ApiResponseMapper.map(await _dio.get<dynamic>('/mobile/chat/messages', queryParameters: {'type': contact.type, 'target_id': contact.id}));
      if (!mapped.ok) return ApiResult.failure(mapped.error ?? 'Gagal memuat pesan', statusCode: mapped.statusCode);
      final rows = (mapped.data?['data'] as List? ?? const []).whereType<Map>().map((e) => ChatMessage.fromJson(e.cast<String, dynamic>())).toList();
      return ApiResult.success(rows, statusCode: mapped.statusCode);
    } catch (e) {
      final mapped = ApiResponseMapper.mapError(e);
      return ApiResult.failure(mapped.error ?? 'Gagal memuat pesan', statusCode: mapped.statusCode);
    }
  }

  Future<ApiResult<ChatMessage>> send(ChatContact contact, String text) async {
    try {
      final mapped = ApiResponseMapper.map(await _dio.post<dynamic>('/mobile/chat/messages', data: {'type': contact.type, 'target_id': contact.id, 'message': text.trim()}));
      if (!mapped.ok) return ApiResult.failure(mapped.error ?? 'Pesan gagal dikirim', statusCode: mapped.statusCode);
      return ApiResult.success(ChatMessage.fromJson((mapped.data?['data'] as Map?)?.cast<String, dynamic>() ?? const {}), statusCode: mapped.statusCode);
    } catch (e) {
      final mapped = ApiResponseMapper.mapError(e);
      return ApiResult.failure(mapped.error ?? 'Pesan gagal dikirim', statusCode: mapped.statusCode);
    }
  }

  Future<void> markRead(ChatContact contact) async {
    await _dio.post<dynamic>('/mobile/chat/messages/read', data: {'type': contact.type, 'target_id': contact.id});
  }
}
