import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/game_models.dart';

/// Info ketersediaan game (jumlah karakter, poin per kemenangan, rekor arcade).
final gameInfoProvider = FutureProvider<GameInfo>((ref) async {
  final result = await ref.watch(gameRepositoryProvider).info();
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat info game');
  }
  return result.data!;
});

/// Papan skor arcade (rekor tertinggi tiap siswa).
final arcadeLeaderboardProvider = FutureProvider<List<ArcadeSkor>>((ref) async {
  final result = await ref.watch(gameRepositoryProvider).arcadeLeaderboard();
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat papan skor');
  }
  return result.data!;
});

/// Tahap permainan pada satu layar sesi.
enum GameFase { belumMulai, memuat, bermain, mengirim, selesai }

/// State satu sesi game solo.
class GameSesiState {
  const GameSesiState({
    this.fase = GameFase.belumMulai,
    this.sesi,
    this.jawaban = const [],
    this.indeks = 0,
    this.hasil,
    this.error,
  });

  final GameFase fase;
  final GameSesi? sesi;

  /// Jawaban per soal, indeks sejajar dengan `sesi.soal`.
  final List<String> jawaban;
  final int indeks;
  final GameHasil? hasil;
  final String? error;

  GameSoal? get soalAktif {
    final s = sesi;
    if (s == null || indeks >= s.soal.length) return null;
    return s.soal[indeks];
  }

  int get totalSoal => sesi?.soal.length ?? 0;
  bool get soalTerakhir => totalSoal > 0 && indeks == totalSoal - 1;
  String get jawabanAktif =>
      indeks < jawaban.length ? jawaban[indeks] : '';
  int get terjawab => jawaban.where((e) => e.trim().isNotEmpty).length;

  GameSesiState copyWith({
    GameFase? fase,
    GameSesi? sesi,
    List<String>? jawaban,
    int? indeks,
    GameHasil? hasil,
    String? error,
    bool hapusError = false,
  }) =>
      GameSesiState(
        fase: fase ?? this.fase,
        sesi: sesi ?? this.sesi,
        jawaban: jawaban ?? this.jawaban,
        indeks: indeks ?? this.indeks,
        hasil: hasil ?? this.hasil,
        error: hapusError ? null : (error ?? this.error),
      );
}

/// Pengendali sesi game solo: mulai, jawab, navigasi soal, submit.
///
/// Kunci jawaban tidak ada di klien — penilaian dilakukan server memakai
/// token sesi, sehingga skor tidak bisa dimanipulasi dari aplikasi.
class GameSesiController extends Notifier<GameSesiState> {
  @override
  GameSesiState build() => const GameSesiState();

  Future<void> mulai(GameMode mode, {int jumlah = 5}) async {
    state = const GameSesiState(fase: GameFase.memuat);
    final result = await ref
        .read(gameRepositoryProvider)
        .mulaiSolo(mode: mode, jumlah: jumlah);
    if (!result.ok || result.data == null) {
      state = GameSesiState(
        fase: GameFase.belumMulai,
        error: result.error ?? 'Gagal memulai game',
      );
      return;
    }
    final sesi = result.data!;
    state = GameSesiState(
      fase: GameFase.bermain,
      sesi: sesi,
      jawaban: List<String>.filled(sesi.soal.length, ''),
    );
  }

  void jawab(String nilai) {
    final list = [...state.jawaban];
    if (state.indeks >= list.length) return;
    list[state.indeks] = nilai;
    state = state.copyWith(jawaban: list, hapusError: true);
  }

  void keSoal(int i) {
    if (i < 0 || i >= state.totalSoal) return;
    state = state.copyWith(indeks: i);
  }

  void berikutnya() => keSoal(state.indeks + 1);
  void sebelumnya() => keSoal(state.indeks - 1);

  Future<void> kirim() async {
    final sesi = state.sesi;
    if (sesi == null || state.fase == GameFase.mengirim) return;

    state = state.copyWith(fase: GameFase.mengirim, hapusError: true);
    final result = await ref.read(gameRepositoryProvider).submitSolo(
          token: sesi.token,
          jawaban: state.jawaban,
        );
    if (!result.ok || result.data == null) {
      state = state.copyWith(
        fase: GameFase.bermain,
        error: result.error ?? 'Gagal mengirim jawaban',
      );
      return;
    }
    state = state.copyWith(fase: GameFase.selesai, hasil: result.data);

    // Poin berubah → ringkasan, riwayat, dan peringkat perlu dimuat ulang.
    ref.invalidate(gameInfoProvider);
  }

  void ulangi() => state = const GameSesiState();
}

final gameSesiProvider =
    NotifierProvider<GameSesiController, GameSesiState>(GameSesiController.new);
