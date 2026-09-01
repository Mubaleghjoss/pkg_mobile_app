import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/notifications/local_notifications.dart';
import '../core/notifications/verifikasi_watcher.dart';
import '../core/storage/session_store.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/calendar/data/calendar_repository.dart';
import '../features/dashboard/data/dashboard_repository.dart';
import '../features/gamifikasi/data/gamifikasi_repository.dart';
import '../features/game/data/game_repository.dart';
import '../features/karakter/data/karakter_luhur_repository.dart';
import '../features/kelas/data/binaan_repository.dart';
import '../features/materi/data/materi_repository.dart';
import '../features/ortu/data/ortu_repository.dart';
import '../features/presensi/data/presensi_repository.dart';
import '../features/quran/data/quran_repository.dart';
import '../features/siswa/data/siswa_repository.dart';
import '../features/tugas/data/tugas_repository.dart';
import '../features/verifikasi/data/verifikasi_repository.dart';

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

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(ref.watch(dioProvider));
});

final siswaRepositoryProvider = Provider<SiswaRepository>((ref) {
  return SiswaRepository(ref.watch(dioProvider));
});

/// Sumber data AKTIF (Binaan Pamong + Kelas Sekolah) — pengganti `/kelas`
/// yang ditandai deprecated oleh backend.
final binaanRepositoryProvider = Provider<BinaanRepository>((ref) {
  return BinaanRepository(ref.watch(dioProvider));
});

final presensiRepositoryProvider = Provider<PresensiRepository>((ref) {
  return PresensiRepository(ref.watch(dioProvider));
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(dioProvider));
});

final karakterLuhurRepositoryProvider =
    Provider<KarakterLuhurRepository>((ref) {
  return KarakterLuhurRepository(ref.watch(dioProvider));
});

final materiRepositoryProvider = Provider<MateriRepository>((ref) {
  return MateriRepository(ref.watch(dioProvider));
});

final tugasRepositoryProvider = Provider<TugasRepository>((ref) {
  return TugasRepository(ref.watch(dioProvider));
});

final quranRepositoryProvider = Provider<QuranRepository>((ref) {
  return QuranRepository(ref.watch(dioProvider));
});

/// Antrean verifikasi tugas PKG — hanya bermakna untuk token pamong/admin.
final verifikasiRepositoryProvider = Provider<VerifikasiRepository>((ref) {
  return VerifikasiRepository(ref.watch(dioProvider));
});

/// Monitoring orang tua — hanya bermakna untuk token ortu.
final ortuRepositoryProvider = Provider<OrtuRepository>((ref) {
  return OrtuRepository(ref.watch(dioProvider));
});

/// Gamifikasi (poin, level, peringkat, riwayat, badge) — token siswa/ortu.
final gamifikasiRepositoryProvider = Provider<GamifikasiRepository>((ref) {
  return GamifikasiRepository(ref.watch(dioProvider));
});

/// Game karakter luhur — siswa bermain, ortu hanya melihat papan skor.
final gameRepositoryProvider = Provider<GameRepository>((ref) {
  return GameRepository(ref.watch(dioProvider));
});

/// Notifikasi lokal perangkat. Di-override dengan [NotifikasiLokalNoop] pada
/// test widget supaya tidak menyentuh plugin platform.
final notifikasiLokalProvider = Provider<NotifikasiLokal>((ref) {
  return FlutterLocalNotifikasi();
});

/// Pengawas tugas yang baru diverifikasi pamong (pemicu notifikasi lokal).
final verifikasiWatcherProvider = Provider<VerifikasiWatcher>((ref) {
  return VerifikasiWatcher(notifikasi: ref.watch(notifikasiLokalProvider));
});
