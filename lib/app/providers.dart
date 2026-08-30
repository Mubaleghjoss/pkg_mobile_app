import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/storage/session_store.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/dashboard/data/dashboard_repository.dart';
import '../features/kelas/data/kelas_repository.dart';
import '../features/presensi/data/presensi_repository.dart';
import '../features/siswa/data/siswa_repository.dart';

/// Penyimpanan sesi (secure storage + fallback shared_preferences).
final sessionStoreProvider = Provider<SessionStore>((ref) {
  return SecureSessionStore();
});

/// `Dio` tunggal untuk seluruh aplikasi.
///
/// Saat server menjawab 401, sesi lokal dibersihkan dan `authControllerProvider`
/// dipaksa ke status unauthenticated sehingga router memindahkan user ke login.
final dioProvider = Provider<Dio>((ref) {
  final factory = ApiClientFactory(
    sessionStore: ref.watch(sessionStoreProvider),
    onUnauthorized: () async {
      ref.read(authControllerProvider.notifier).onServerRejectedToken();
    },
  );
  ref.onDispose(factory.dio.close);
  return factory.dio;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio: ref.watch(dioProvider),
    sessionStore: ref.watch(sessionStoreProvider),
  );
});

final siswaRepositoryProvider = Provider<SiswaRepository>((ref) {
  return SiswaRepository(ref.watch(dioProvider));
});

final kelasRepositoryProvider = Provider<KelasRepository>((ref) {
  return KelasRepository(ref.watch(dioProvider));
});

final presensiRepositoryProvider = Provider<PresensiRepository>((ref) {
  return PresensiRepository(ref.watch(dioProvider));
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(dioProvider));
});
