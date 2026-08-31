import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/storage/session_store.dart';

/// Repository autentikasi terhadap `POST /api/v1/login`, `/me`, `/logout`.
///
/// Kontrak backend yang WAJIB dipatuhi (diverifikasi pada API v1 lokal):
/// - field login bernama `username` (boleh berisi email), BUKAN `email`;
/// - respons login: `{user: {...}, token: "...", expires_at: "..."}`;
/// - rate limit login 5 percobaan / 5 menit per IP → HTTP 429;
/// - akun terkunci → HTTP 423, akun non-aktif → HTTP 403.
class AuthRepository {
  AuthRepository({required Dio dio, required SessionStore sessionStore})
      : _dio = dio,
        _store = sessionStore;

  final Dio _dio;
  final SessionStore _store;

  Future<ApiResult<AuthSession>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/login',
        data: {'username': username, 'password': password},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      final mapped = ApiResponseMapper.map(response);
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Login gagal',
          statusCode: mapped.statusCode,
          fieldErrors: mapped.fieldErrors,
        );
      }

      final body = mapped.data ?? const <String, dynamic>{};
      final user = (body['user'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final token = '${body['token'] ?? ''}';
      if (token.isEmpty) {
        return ApiResult.failure(
          'Server tidak mengirim token.',
          statusCode: mapped.statusCode,
        );
      }

      final session = AuthSession(
        token: token,
        expiresAt: DateTime.tryParse('${body['expires_at']}'),
        username: '${user['username'] ?? username}',
        role: user['role'] as String?,
        permissions: (user['permissions'] as List?)
                ?.map((e) => '$e')
                .toList(growable: false) ??
            const <String>[],
        userId: user['id'] as int?,
        email: user['email'] as String?,
        phone: user['phone'] as String?,
        lastLoginAt: DateTime.tryParse('${user['last_login_at']}'),
      );
      await _store.write(session);
      return ApiResult.success(session, statusCode: mapped.statusCode);
    } catch (e) {
      final mapped = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        mapped.error ?? 'Login gagal',
        statusCode: mapped.statusCode,
      );
    }
  }

  /// Login siswa: `POST /api/v1/siswa/login` dengan field `nis` + `password`.
  ///
  /// Respons dibungkus `{success, data: {token, user: {...}}}` — berbeda dari
  /// `/login` staff yang menaruh token di akar body.
  Future<ApiResult<AuthSession>> loginSiswa({
    required String nis,
    required String password,
  }) =>
      _loginGenerus(
        path: '/siswa/login',
        body: {'nis': nis, 'password': password},
        actor: AuthActor.siswa,
        fallbackUsername: nis,
      );

  /// Login orang tua: `POST /api/v1/ortu/login` (`username` + `password`).
  Future<ApiResult<AuthSession>> loginOrtu({
    required String username,
    required String password,
  }) =>
      _loginGenerus(
        path: '/ortu/login',
        body: {'username': username, 'password': password},
        actor: AuthActor.ortu,
        fallbackUsername: username,
      );

  Future<ApiResult<AuthSession>> _loginGenerus({
    required String path,
    required Map<String, String> body,
    required AuthActor actor,
    required String fallbackUsername,
  }) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.post<dynamic>(
          path,
          data: body,
          options: Options(headers: {'Content-Type': 'application/json'}),
        ),
      );
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Login gagal',
          statusCode: mapped.statusCode,
          fieldErrors: mapped.fieldErrors,
        );
      }

      final data = (mapped.data?['data'] as Map?)?.cast<String, dynamic>() ??
          mapped.data ??
          const <String, dynamic>{};
      final token = '${data['token'] ?? ''}';
      if (token.isEmpty) {
        return ApiResult.failure(
          'Server tidak mengirim token.',
          statusCode: mapped.statusCode,
        );
      }
      final user = (data['user'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};

      final session = AuthSession(
        token: token,
        // Backend memberi masa berlaku dalam hari (`expires_in_days`).
        expiresAt: _expiryFromDays(data['expires_in_days']),
        username: '${user['nis'] ?? fallbackUsername}',
        role: user['role'] as String? ?? actor.name,
        // Siswa & ortu tidak memakai sistem permission `users`; pembatasan
        // aksi ditegakkan backend lewat ability token.
        permissions: const <String>[],
        actor: actor,
        displayName: user['nama'] as String?,
        userId: user['id'] as int?,
      );
      await _store.write(session);
      return ApiResult.success(session, statusCode: mapped.statusCode);
    } catch (e) {
      final mapped = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        mapped.error ?? 'Login gagal',
        statusCode: mapped.statusCode,
        fieldErrors: mapped.fieldErrors,
      );
    }
  }

  static DateTime? _expiryFromDays(Object? raw) {
    final days = raw is int ? raw : int.tryParse('$raw');
    if (days == null) return null;
    return DateTime.now().add(Duration(days: days));
  }

  /// Validasi token siswa/ortu lewat `GET /api/v1/siswa-account/me`.
  Future<ApiResult<AuthSession>> meGenerus() async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.get<dynamic>('/siswa-account/me'),
      );
      final stored = await _store.read();
      if (!mapped.ok || stored == null) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal memuat profil',
          statusCode: stored == null ? 401 : mapped.statusCode,
        );
      }
      final user = (mapped.data?['data'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final refreshed = AuthSession(
        token: stored.token,
        expiresAt: stored.expiresAt,
        username: '${user['nis'] ?? stored.username}',
        role: user['role'] as String? ?? stored.role,
        permissions: const <String>[],
        actor: AuthActor.parse(user['role'] ?? stored.actor.name),
        displayName: user['nama'] as String? ?? stored.displayName,
        userId: user['id'] as int? ?? stored.userId,
      );
      await _store.write(refreshed);
      return ApiResult.success(refreshed, statusCode: mapped.statusCode);
    } catch (e) {
      final mapped = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        mapped.error ?? 'Gagal memuat profil',
        statusCode: mapped.statusCode,
      );
    }
  }

  /// Ambil ulang profil + permission (dipakai saat app start untuk validasi token).
  Future<ApiResult<AuthSession>> me() async {
    try {
      final mapped = ApiResponseMapper.map(await _dio.get<dynamic>('/me'));
      if (!mapped.ok) {
        return ApiResult.failure(mapped.error ?? 'Gagal memuat profil',
            statusCode: mapped.statusCode);
      }
      final stored = await _store.read();
      if (stored == null) {
        return ApiResult.failure('Sesi tidak ditemukan.', statusCode: 401);
      }
      final user = ((mapped.data?['user'] as Map?)?.cast<String, dynamic>()) ??
          const <String, dynamic>{};
      final refreshed = AuthSession(
        token: stored.token,
        expiresAt: stored.expiresAt,
        username: '${user['username'] ?? stored.username}',
        role: user['role'] as String? ?? stored.role,
        permissions: (user['permissions'] as List?)
                ?.map((e) => '$e')
                .toList(growable: false) ??
            stored.permissions,
        userId: user['id'] as int? ?? stored.userId,
        email: user['email'] as String? ?? stored.email,
        phone: user['phone'] as String? ?? stored.phone,
        lastLoginAt:
            DateTime.tryParse('${user['last_login_at']}') ?? stored.lastLoginAt,
      );
      await _store.write(refreshed);
      return ApiResult.success(refreshed, statusCode: mapped.statusCode);
    } catch (e) {
      final mapped = ApiResponseMapper.mapError(e);
      return ApiResult.failure(
        mapped.error ?? 'Gagal memuat profil',
        statusCode: mapped.statusCode,
      );
    }
  }

  /// Perpanjang token via `POST /api/v1/refresh` (token lama dicabut server).
  Future<ApiResult<AuthSession>> refresh() async {
    try {
      final mapped = ApiResponseMapper.map(await _dio.post<dynamic>('/refresh'));
      final stored = await _store.read();
      if (!mapped.ok || stored == null) {
        return ApiResult.failure(mapped.error ?? 'Refresh token gagal',
            statusCode: mapped.statusCode);
      }
      final token = '${mapped.data?['token'] ?? ''}';
      if (token.isEmpty) {
        return ApiResult.failure('Server tidak mengirim token baru.',
            statusCode: mapped.statusCode);
      }
      final next = stored.copyWith(
        token: token,
        expiresAt: DateTime.tryParse('${mapped.data?['expires_at']}'),
      );
      await _store.write(next);
      return ApiResult.success(next, statusCode: mapped.statusCode);
    } catch (e) {
      return ApiResult.failure(
        ApiResponseMapper.mapError(e).error ?? 'Refresh token gagal',
      );
    }
  }

  /// Ganti password: `POST /api/v1/change-password`.
  ///
  /// Kontrak backend: `current_password`, `new_password`, dan
  /// `new_password_confirmation` (aturan `confirmed`, minimal 8 karakter).
  /// Password lama salah → HTTP 400. Sukses mencabut SEMUA token lain,
  /// token milik sesi ini tetap berlaku.
  Future<ApiResult<String>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final mapped = ApiResponseMapper.map(
        await _dio.post<dynamic>('/change-password', data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'new_password_confirmation': newPassword,
        }),
      );
      if (!mapped.ok) {
        return ApiResult.failure(
          mapped.error ?? 'Gagal mengganti password',
          statusCode: mapped.statusCode,
          fieldErrors: mapped.fieldErrors,
        );
      }
      return ApiResult.success(
        '${mapped.data?['message'] ?? 'Password berhasil diganti.'}',
        statusCode: mapped.statusCode,
      );
    } catch (e) {
      final err = ApiResponseMapper.mapError(e);
      return ApiResult.failure(err.error ?? 'Gagal mengganti password',
          statusCode: err.statusCode, fieldErrors: err.fieldErrors);
    }
  }

  /// Logout: cabut token di server lalu bersihkan penyimpanan lokal.
  /// Sesi lokal SELALU dibersihkan, bahkan bila panggilan server gagal.
  ///
  /// Endpoint berbeda per jenis token: staff memakai `/logout`, sedangkan
  /// siswa/ortu memakai `/siswa-account/logout` (guard `auth:sanctum` sama,
  /// tetapi controller staff menolak token milik model Siswa).
  Future<void> logout() async {
    final stored = await _store.read();
    final path = (stored?.actor.isGenerus ?? false)
        ? '/siswa-account/logout'
        : '/logout';
    try {
      await _dio.post<dynamic>(path);
    } catch (_) {
      // diabaikan: token lokal tetap dibuang
    } finally {
      await _store.clear();
    }
  }

  Future<AuthSession?> restore() => _store.read();
}
