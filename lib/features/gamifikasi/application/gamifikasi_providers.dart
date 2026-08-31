import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/paginated.dart';
import '../data/gamifikasi_models.dart';

/// Ringkasan poin & level siswa yang sedang login (ortu: data anaknya).
final gamifikasiRingkasanProvider =
    FutureProvider<GamifikasiRingkasan>((ref) async {
  final result = await ref.watch(gamifikasiRepositoryProvider).ringkasan();
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat ringkasan poin');
  }
  return result.data!;
});

/// Periode papan peringkat yang dipilih user: all | daily | weekly | monthly.
///
/// Riverpod 3 tidak lagi mengekspor `StateProvider` di API utama, jadi state
/// sederhana seperti ini memakai [Notifier].
class LeaderboardPeriode extends Notifier<String> {
  @override
  String build() => 'all';

  void pilih(String periode) => state = periode;
}

final leaderboardPeriodeProvider =
    NotifierProvider<LeaderboardPeriode, String>(LeaderboardPeriode.new);

/// Papan peringkat mengikuti [leaderboardPeriodeProvider].
final leaderboardProvider = FutureProvider<LeaderboardHalaman>((ref) async {
  final periode = ref.watch(leaderboardPeriodeProvider);
  final result = await ref
      .watch(gamifikasiRepositoryProvider)
      .leaderboard(periode: periode, limit: 30);
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat papan peringkat');
  }
  return result.data!;
});

/// Filter sumber pada riwayat poin (null = semua).
class HistorySumber extends Notifier<String?> {
  @override
  String? build() => null;

  void pilih(String? sumber) => state = sumber;
}

final historySumberProvider =
    NotifierProvider<HistorySumber, String?>(HistorySumber.new);

/// State riwayat poin dengan muat-lebih (infinite scroll).
class PoinHistoryState {
  const PoinHistoryState({
    this.items = const [],
    this.meta = const PageMeta(
      currentPage: 1,
      lastPage: 1,
      perPage: 20,
      total: 0,
    ),
    this.memuat = false,
    this.memuatLagi = false,
    this.error,
  });

  final List<PoinTransaksi> items;
  final PageMeta meta;
  final bool memuat;
  final bool memuatLagi;
  final String? error;

  bool get kosong => items.isEmpty && !memuat && error == null;
  bool get bisaMuatLagi => meta.hasMore && !memuatLagi && !memuat;

  PoinHistoryState copyWith({
    List<PoinTransaksi>? items,
    PageMeta? meta,
    bool? memuat,
    bool? memuatLagi,
    String? error,
    bool hapusError = false,
  }) =>
      PoinHistoryState(
        items: items ?? this.items,
        meta: meta ?? this.meta,
        memuat: memuat ?? this.memuat,
        memuatLagi: memuatLagi ?? this.memuatLagi,
        error: hapusError ? null : (error ?? this.error),
      );
}

/// Pengendali riwayat poin: muat halaman pertama, muat lebih, ganti filter.
class PoinHistoryController extends Notifier<PoinHistoryState> {
  @override
  PoinHistoryState build() {
    // Filter diawasi supaya perubahan sumber memuat ulang dari halaman 1.
    ref.listen(historySumberProvider, (_, _) => muatUlang());
    Future.microtask(muatUlang);
    return const PoinHistoryState(memuat: true);
  }

  Future<void> muatUlang() async {
    state = state.copyWith(memuat: true, hapusError: true);
    final result = await ref.read(gamifikasiRepositoryProvider).history(
          sumber: ref.read(historySumberProvider),
          page: 1,
        );
    if (!result.ok || result.data == null) {
      state = state.copyWith(
        memuat: false,
        error: result.error ?? 'Gagal memuat riwayat poin',
      );
      return;
    }
    state = PoinHistoryState(
      items: result.data!.items,
      meta: result.data!.meta,
    );
  }

  Future<void> muatLagi() async {
    if (!state.bisaMuatLagi) return;
    state = state.copyWith(memuatLagi: true);
    final result = await ref.read(gamifikasiRepositoryProvider).history(
          sumber: ref.read(historySumberProvider),
          page: state.meta.currentPage + 1,
        );
    if (!result.ok || result.data == null) {
      state = state.copyWith(
        memuatLagi: false,
        error: result.error ?? 'Gagal memuat halaman berikutnya',
      );
      return;
    }
    state = state.copyWith(
      items: [...state.items, ...result.data!.items],
      meta: result.data!.meta,
      memuatLagi: false,
      hapusError: true,
    );
  }
}

final poinHistoryProvider =
    NotifierProvider<PoinHistoryController, PoinHistoryState>(
  PoinHistoryController.new,
);

/// Koleksi badge + progres.
final badgesProvider = FutureProvider<List<BadgeItem>>((ref) async {
  final result = await ref.watch(gamifikasiRepositoryProvider).badges();
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat badge');
  }
  return result.data!;
});
