import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_result.dart';
import '../../../core/storage/session_store.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.session,
    this.error,
    this.submitting = false,
  });

  const AuthState.unknown()
      : status = AuthStatus.unknown,
        session = null,
        error = null,
        submitting = false;

  final AuthStatus status;
  final AuthSession? session;
  final String? error;
  final bool submitting;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// Cek permission dari daftar yang dikirim backend (`role.permissions`).
  bool can(String permission) => session?.can(permission) ?? false;

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    String? error,
    bool? submitting,
    bool clearError = false,
    bool clearSession = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      error: clearError ? null : (error ?? this.error),
      submitting: submitting ?? this.submitting,
    );
  }
}

/// Sumber kebenaran status login. Router menonton provider ini.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(restoreSession);
    return const AuthState.unknown();
  }

  /// Dipanggil saat start: pakai token tersimpan, verifikasi ke `/me`.
  Future<void> restoreSession() async {
    final repo = ref.read(authRepositoryProvider);
    final stored = await repo.restore();
    if (stored == null || stored.isExpired) {
      if (stored != null) await repo.logout();
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    // Endpoint verifikasi berbeda: token siswa/ortu ditolak oleh `/me` staff.
    final result =
        stored.actor.isGenerus ? await repo.meGenerus() : await repo.me();
    if (result.ok && result.data != null) {
      state = AuthState(
        status: AuthStatus.authenticated,
        session: result.data,
      );
      return;
    }

    // Token ditolak/putus jaringan. Bila 401 token sudah dibuang interceptor.
    if (result.isNetworkError) {
      // Offline: tetap izinkan masuk dengan sesi tersimpan; layar akan
      // menampilkan error per-request.
      state = AuthState(status: AuthStatus.authenticated, session: stored);
      return;
    }
    state = AuthState(
      status: AuthStatus.unauthenticated,
      error: result.error,
    );
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(submitting: true, clearError: true);
    final result = await ref
        .read(authRepositoryProvider)
        .login(username: username, password: password);
    return _finishLogin(result);
  }

  /// Login siswa dengan NIS.
  Future<bool> loginSiswa({
    required String nis,
    required String password,
  }) async {
    state = state.copyWith(submitting: true, clearError: true);
    final result = await ref
        .read(authRepositoryProvider)
        .loginSiswa(nis: nis, password: password);
    return _finishLogin(result);
  }

  /// Login orang tua dengan username wali.
  Future<bool> loginOrtu({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(submitting: true, clearError: true);
    final result = await ref
        .read(authRepositoryProvider)
        .loginOrtu(username: username, password: password);
    return _finishLogin(result);
  }

  bool _finishLogin(ApiResult<AuthSession> result) {
    if (result.ok && result.data != null) {
      state = AuthState(status: AuthStatus.authenticated, session: result.data);
      return true;
    }

    state = AuthState(
      status: AuthStatus.unauthenticated,
      error: result.error ?? 'Login gagal',
    );
    return false;
  }

  Future<void> logout() async {
    await ref.read(fcmPushServiceProvider).stop();
    await ref.read(authRepositoryProvider).logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Dipanggil interceptor ketika server membalas 401.
  void onServerRejectedToken() {
    if (state.status == AuthStatus.unauthenticated) return;
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      error: 'Sesi berakhir. Silakan masuk kembali.',
    );
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
