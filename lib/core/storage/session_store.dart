import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sesi login yang dipersist di perangkat.
/// Jenis pemilik token. Backend punya dua tabel akun berbeda:
/// `users` (admin/pamong, endpoint `/login`) dan `siswa` (siswa & orang tua,
/// endpoint `/siswa/login` dan `/ortu/login`). Token keduanya sama-sama
/// Sanctum, tetapi endpoint yang boleh diakses berbeda — karena itu jenis
/// aktor harus ikut dipersist, bukan disimpulkan dari `role`.
enum AuthActor {
  staff,
  siswa,
  ortu;

  static AuthActor parse(Object? raw) => switch ('$raw') {
        'siswa' => AuthActor.siswa,
        'ortu' => AuthActor.ortu,
        _ => AuthActor.staff,
      };

  /// Siswa & ortu memakai antarmuka pembinaan (tugas, quran, materi),
  /// bukan antarmuka administrasi.
  bool get isGenerus => this != AuthActor.staff;
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.expiresAt,
    required this.username,
    required this.role,
    required this.permissions,
    this.actor = AuthActor.staff,
    this.userId,
    this.email,
    this.phone,
    this.lastLoginAt,
    this.displayName,
  });

  final String token;
  final DateTime? expiresAt;
  final String username;
  final String? role;
  final List<String> permissions;

  /// Pemilik token: staff (users) vs siswa/ortu (tabel siswa).
  final AuthActor actor;

  /// Nama yang enak dibaca di AppBar (nama siswa / nama staff).
  final String? displayName;

  /// Field profil dari `GET /me` — dipakai layar Profil. Null bila sesi dibuat
  /// dari respons login yang tidak mengirimkannya.
  final int? userId;
  final String? email;
  final String? phone;
  final DateTime? lastLoginAt;

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool can(String permission) => permissions.contains(permission);

  Map<String, dynamic> toJson() => {
        'token': token,
        'expires_at': expiresAt?.toIso8601String(),
        'username': username,
        'role': role,
        'permissions': permissions,
        'actor': actor.name,
        'display_name': displayName,
        'user_id': userId,
        'email': email,
        'phone': phone,
        'last_login_at': lastLoginAt?.toIso8601String(),
      };

  static AuthSession? fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    if (token is! String || token.isEmpty) return null;
    return AuthSession(
      token: token,
      expiresAt: DateTime.tryParse('${json['expires_at']}'),
      username: '${json['username'] ?? ''}',
      role: json['role'] as String?,
      permissions: (json['permissions'] as List?)
              ?.map((e) => '$e')
              .toList(growable: false) ??
          const <String>[],
      actor: AuthActor.parse(json['actor']),
      displayName: json['display_name'] as String?,
      userId: json['user_id'] as int?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      lastLoginAt: DateTime.tryParse('${json['last_login_at']}'),
    );
  }

  AuthSession copyWith({String? token, DateTime? expiresAt}) => AuthSession(
        token: token ?? this.token,
        expiresAt: expiresAt ?? this.expiresAt,
        username: username,
        role: role,
        permissions: permissions,
        actor: actor,
        displayName: displayName,
        userId: userId,
        email: email,
        phone: phone,
        lastLoginAt: lastLoginAt,
      );
}

/// Penyimpanan sesi.
///
/// Token adalah kredensial, jadi target utamanya `flutter_secure_storage`
/// (Keystore di Android). Di platform yang tidak mendukungnya (mis. web, atau
/// Android tanpa Keystore yang sehat) otomatis jatuh ke `shared_preferences`
/// supaya aplikasi tidak mati — status fallback diekspos via [usingFallback]
/// agar bisa ditampilkan di layar debug.
abstract class SessionStore {
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  // flutter_secure_storage 11.x: EncryptedSharedPreferences sudah menjadi
  // implementasi default di Android, opsi `encryptedSharedPreferences` dihapus.
  SecureSessionStore({FlutterSecureStorage? storage})
      : _secure = storage ?? const FlutterSecureStorage();

  static const _key = 'pkg_auth_session_v1';

  final FlutterSecureStorage _secure;
  bool _fallback = false;

  bool get usingFallback => _fallback;

  @override
  Future<AuthSession?> read() async {
    final raw = await _guard(
      () => _secure.read(key: _key),
      fallback: () async =>
          (await SharedPreferences.getInstance()).getString(_key),
    );
    if (raw == null || raw.isEmpty) return null;
    try {
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) async {
    final raw = jsonEncode(session.toJson());
    await _guard(
      () => _secure.write(key: _key, value: raw),
      fallback: () async =>
          (await SharedPreferences.getInstance()).setString(_key, raw),
    );
  }

  @override
  Future<void> clear() async {
    await _guard(
      () => _secure.delete(key: _key),
      fallback: () async =>
          (await SharedPreferences.getInstance()).remove(_key),
    );
  }

  Future<T?> _guard<T>(
    Future<T?> Function() primary, {
    required Future<T?> Function() fallback,
  }) async {
    if (_fallback) return fallback();
    try {
      return await primary();
    } catch (_) {
      _fallback = true;
      return fallback();
    }
  }
}

/// Store in-memory untuk test.
class MemorySessionStore implements SessionStore {
  AuthSession? _session;

  @override
  Future<void> clear() async => _session = null;

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> write(AuthSession session) async => _session = session;
}
