import 'package:dio/dio.dart';

import '../api_config.dart';
import '../storage/session_store.dart';
import 'api_result.dart';

/// Dipanggil ketika server menolak token (401) sehingga sesi harus dibuang.
typedef UnauthorizedCallback = Future<void> Function();

/// Factory `Dio` terpusat untuk seluruh aplikasi.
///
/// Interceptor melakukan:
/// - menyisipkan `Authorization: Bearer <token>` dari [SessionStore];
/// - menormalkan header `Accept: application/json` (wajib agar Laravel
///   mengembalikan JSON, bukan redirect HTML ke halaman login);
/// - memanggil [onUnauthorized] saat 401 supaya router bisa melempar ke login.
class ApiClientFactory {
  ApiClientFactory({
    required SessionStore sessionStore,
    UnauthorizedCallback? onUnauthorized,
    Dio? dio,
  })  : _sessionStore = sessionStore,
        _onUnauthorized = onUnauthorized,
        dio = dio ?? Dio() {
    this.dio
      ..options.baseUrl = ApiConfig.apiV1
      ..options.connectTimeout = ApiConfig.connectTimeout
      ..options.receiveTimeout = ApiConfig.receiveTimeout
      ..options.headers['Accept'] = 'application/json'
      // Semua status ditangani manual; jangan lempar exception untuk 4xx.
      ..options.validateStatus = (_) => true;

    this.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final session = await _sessionStore.read();
              if (session != null) {
                options.headers['Authorization'] = 'Bearer ${session.token}';
              }
              handler.next(options);
            },
            onResponse: (response, handler) async {
              if (response.statusCode == 401) {
                await _sessionStore.clear();
                await _onUnauthorized?.call();
              }
              handler.next(response);
            },
          ),
        );
  }

  final SessionStore _sessionStore;
  final UnauthorizedCallback? _onUnauthorized;
  final Dio dio;
}

/// Helper konversi `Response`/`DioException` menjadi [ApiResult].
class ApiResponseMapper {
  const ApiResponseMapper._();

  static ApiResult<Map<String, dynamic>> map(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    final body = response.data;
    final map = body is Map
        ? body.map((k, v) => MapEntry('$k', v))
        : <String, dynamic>{'data': body};

    if (status >= 200 && status < 300) {
      return ApiResult.success(map, statusCode: status);
    }

    return ApiResult.failure(
      _messageOf(map, status),
      statusCode: status,
      fieldErrors: _fieldErrorsOf(map),
    );
  }

  static ApiResult<Map<String, dynamic>> mapError(Object error) {
    if (error is DioException) {
      final response = error.response;
      if (response != null) return map(response);
      return ApiResult.failure(
        switch (error.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout =>
            'Koneksi ke server timeout. Periksa jaringan atau alamat server.',
          DioExceptionType.connectionError =>
            'Tidak dapat menghubungi server (${ApiConfig.baseUrl}).',
          _ => error.message ?? 'Kesalahan jaringan.',
        },
      );
    }
    return ApiResult.failure('$error');
  }

  static String _messageOf(Map<String, dynamic> map, int status) {
    final raw = map['message'] ?? map['error'];
    if (raw is String && raw.isNotEmpty) return raw;
    return switch (status) {
      401 => 'Sesi berakhir. Silakan masuk kembali.',
      403 => 'Akun Anda tidak punya izin untuk data ini.',
      404 => 'Data tidak ditemukan.',
      422 => 'Data yang dikirim tidak valid.',
      429 => 'Terlalu banyak percobaan. Coba lagi beberapa saat.',
      _ => 'Server mengembalikan HTTP $status.',
    };
  }

  static Map<String, List<String>>? _fieldErrorsOf(Map<String, dynamic> map) {
    final errors = map['errors'];
    if (errors is! Map) return null;
    return errors.map(
      (key, value) => MapEntry(
        '$key',
        value is List
            ? value.map((e) => '$e').toList(growable: false)
            : <String>['$value'],
      ),
    );
  }
}
