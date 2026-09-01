import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/celebration.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../gamifikasi/application/gamifikasi_providers.dart';
import '../application/game_providers.dart';
import '../data/game_models.dart';

/// Layar Game: pilih mode (Tebak Karakter / Rangkai Kata), mainkan, dapat poin.
///
/// Penilaian dilakukan server (kunci jawaban tidak dikirim ke aplikasi), poin
/// masuk sebagai transaksi `game` sehingga muncul di riwayat poin & leaderboard.
class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameSesiProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Karakter'),
        actions: [
          if (state.fase == GameFase.bermain)
            TextButton(
              onPressed: () => ref.read(gameSesiProvider.notifier).ulangi(),
              child: const Text('Keluar'),
            ),
        ],
      ),
      body: switch (state.fase) {
        GameFase.belumMulai => const _PilihMode(),
        GameFase.memuat => const Center(child: CircularProgressIndicator()),
        GameFase.bermain || GameFase.mengirim => const _Bermain(),
        GameFase.selesai => const _Hasil(),
      },
    );
  }
}

// ─────────────────────────── Pilih mode ───────────────────────────

class _PilihMode extends ConsumerWidget {
  const _PilihMode();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(gameInfoProvider);
    final error = ref.watch(gameSesiProvider).error;

    return info.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorPanel(
        message: '$e'.replaceFirst('Exception: ', ''),
        onRetry: () => ref.invalidate(gameInfoProvider),
      ),
      data: (g) {
        if (!g.siap) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sports_esports_outlined, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    'Game belum bisa dimainkan: data karakter luhur '
                    'masih ${g.jumlahKarakter} item (minimal 4).',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (g.hanyaMemantau)
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: const ListTile(
                  leading: Icon(Icons.visibility_outlined),
                  title: Text('Akun orang tua hanya memantau'),
                  subtitle: Text(
                    'Papan skor bisa dilihat, tetapi bermain hanya untuk '
                    'akun siswa.',
                  ),
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: Text(error),
                  ),
                ),
              ),
            FadeSlideIn(
              index: 0,
              child: _KartuMode(
                mode: GameMode.tebak,
                ikon: Icons.quiz_outlined,
                warna: Colors.indigo,
                deskripsi: 'Pilih arti / dalil yang tepat untuk sebuah '
                    'karakter luhur. 4 pilihan tiap soal.',
                poin: g.poinPerKemenangan,
                ambang: g.ambangLulusPersen,
                aktif: !g.hanyaMemantau,
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 1,
              child: _KartuMode(
                mode: GameMode.rangkai,
                ikon: Icons.abc_outlined,
                warna: Colors.teal,
                deskripsi: 'Susun huruf yang teracak menjadi nama karakter '
                    'luhur sesuai petunjuk artinya.',
                poin: g.poinPerKemenangan,
                ambang: g.ambangLulusPersen,
                aktif: !g.hanyaMemantau,
              ),
            ),
            const SizedBox(height: 20),
            _KartuRekor(info: g),
            const SizedBox(height: 12),
            const _PapanSkorArcade(),
          ],
        );
      },
    );
  }
}

class _KartuMode extends ConsumerWidget {
  const _KartuMode({
    required this.mode,
    required this.ikon,
    required this.warna,
    required this.deskripsi,
    required this.poin,
    required this.ambang,
    required this.aktif,
  });

  final GameMode mode;
  final IconData ikon;
  final Color warna;
  final String deskripsi;
  final int poin;
  final int ambang;
  final bool aktif;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PressableCard(
      onTap: aktif
          ? () => ref.read(gameSesiProvider.notifier).mulai(mode)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: warna.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(ikon, color: warna),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    deskripsi,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('+$poin poin bila lulus'),
                      ),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('min. benar $ambang%'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (aktif) const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _KartuRekor extends StatelessWidget {
  const _KartuRekor({required this.info});

  final GameInfo info;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.military_tech_outlined, color: Colors.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                // Akun ortu tidak pernah bermain: skor yang tampil adalah
                // rekor anaknya, jadi jangan disebut "Anda".
                '${info.hanyaMemantau ? 'Rekor arcade anak' : 'Rekor arcade Anda'}'
                ': ${info.skorTerbaikArcade} '
                '(combo ${info.comboTerbaikArcade})',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PapanSkorArcade extends ConsumerWidget {
  const _PapanSkorArcade();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(arcadeLeaderboardProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Papan skor arcade',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('$e'.replaceFirst('Exception: ', '')),
              data: (list) => list.isEmpty
                  ? Text(
                      'Belum ada skor arcade tercatat.',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  : Column(
                      children: [
                        for (final s in list.take(10))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 26,
                                  child: Text('${s.peringkat}'),
                                ),
                                Expanded(
                                  child: Text(
                                    s.nama,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: s.isSaya
                                        ? const TextStyle(
                                            fontWeight: FontWeight.bold)
                                        : null,
                                  ),
                                ),
                                Text('${s.skor}'),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Bermain ───────────────────────────

class _Bermain extends ConsumerStatefulWidget {
  const _Bermain();

  @override
  ConsumerState<_Bermain> createState() => _BermainState();
}

class _BermainState extends ConsumerState<_Bermain> {
  final _ctrl = TextEditingController();
  int _indeksTerakhir = -1;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameSesiProvider);
    final soal = state.soalAktif;
    if (soal == null) return const Center(child: CircularProgressIndicator());

    // Sinkronkan field teks saat pindah soal (mode rangkai).
    if (_indeksTerakhir != state.indeks) {
      _indeksTerakhir = state.indeks;
      _ctrl.text = state.jawabanAktif;
    }

    final mengirim = state.fase == GameFase.mengirim;

    return Column(
      children: [
        LinearProgressIndicator(
          value: state.totalSoal == 0
              ? 0
              : (state.indeks + 1) / state.totalSoal,
          minHeight: 4,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Soal ${state.indeks + 1} dari ${state.totalSoal}'
                ' • terjawab ${state.terjawab}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        soal.pertanyaan,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (soal.hintArab != null &&
                          soal.hintArab!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          soal.hintArab!,
                          textAlign: TextAlign.right,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(height: 1.8),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (state.sesi!.mode == GameMode.tebak)
                _Pilihan(
                  opsi: soal.options,
                  dipilih: state.jawabanAktif,
                  onPilih: mengirim
                      ? null
                      : (v) => ref.read(gameSesiProvider.notifier).jawab(v),
                )
              else
                _Rangkai(
                  soal: soal,
                  controller: _ctrl,
                  aktif: !mengirim,
                  onUbah: (v) =>
                      ref.read(gameSesiProvider.notifier).jawab(v),
                ),
              if (state.error != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: Text(state.error!),
                  ),
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (state.indeks > 0)
                  OutlinedButton(
                    onPressed: mengirim
                        ? null
                        : () =>
                            ref.read(gameSesiProvider.notifier).sebelumnya(),
                    child: const Text('Sebelumnya'),
                  ),
                const Spacer(),
                if (state.soalTerakhir)
                  FilledButton.icon(
                    onPressed: mengirim
                        ? null
                        : () => ref.read(gameSesiProvider.notifier).kirim(),
                    icon: mengirim
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(mengirim ? 'Menilai...' : 'Selesai & Nilai'),
                  )
                else
                  FilledButton(
                    onPressed: mengirim
                        ? null
                        : () =>
                            ref.read(gameSesiProvider.notifier).berikutnya(),
                    child: const Text('Berikutnya'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Pilihan extends StatelessWidget {
  const _Pilihan({
    required this.opsi,
    required this.dipilih,
    required this.onPilih,
  });

  final List<String> opsi;
  final String dipilih;
  final ValueChanged<String>? onPilih;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final o in opsi)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: o == dipilih
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onPilih == null ? null : () => onPilih!(o),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        o == dipilih
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: o == dipilih ? scheme.primary : scheme.outline,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(o)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Rangkai extends StatelessWidget {
  const _Rangkai({
    required this.soal,
    required this.controller,
    required this.aktif,
    required this.onUbah,
  });

  final GameSoal soal;
  final TextEditingController controller;
  final bool aktif;
  final ValueChanged<String> onUbah;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Huruf teracak', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            soal.scrambled ?? '-',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  letterSpacing: 3,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        if (soal.wordLengths.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Pola jawaban: ${soal.wordLengths.map((n) => '_' * n).join(' ')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          enabled: aktif,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Jawaban Anda',
            border: OutlineInputBorder(),
            helperText: 'Huruf besar/kecil dan spasi tidak masalah',
          ),
          onChanged: onUbah,
        ),
      ],
    );
  }
}

// ─────────────────────────── Hasil ───────────────────────────

class _Hasil extends ConsumerWidget {
  const _Hasil();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasil = ref.watch(gameSesiProvider).hasil;
    if (hasil == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PopIn(
              child: Card(
                color: hasil.lulus
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        hasil.lulus
                            ? Icons.emoji_events
                            : Icons.sentiment_neutral_outlined,
                        size: 46,
                        color: hasil.lulus
                            ? Colors.amber.shade700
                            : scheme.outline,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        hasil.lulus ? 'Lulus!' : 'Belum lulus',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Benar ${hasil.benar} dari ${hasil.total} '
                        '(${hasil.persenBenar}%)',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      if (hasil.poinDidapat > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_circle_outline, size: 18),
                            const SizedBox(width: 6),
                            AnimatedCounter(
                              value: hasil.poinDidapat,
                              suffix: ' poin',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        )
                      else
                        Text(
                          'Tidak ada poin kali ini — coba lagi ya.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      const SizedBox(height: 6),
                      Text(
                        'Total poin sekarang: ${hasil.totalPoinSekarang}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pembahasan',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            for (final r in hasil.rincian)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    r.benar ? Icons.check_circle : Icons.cancel,
                    color: r.benar ? Colors.green : scheme.error,
                  ),
                  title: Text('Soal ${r.nomor}'),
                  subtitle: Text(
                    r.benar
                        ? 'Jawaban Anda: ${r.jawabanSaya}'
                        : 'Jawaban Anda: '
                            '${r.jawabanSaya.isEmpty ? '(kosong)' : r.jawabanSaya}'
                            '\nKunci: ${r.kunci}',
                  ),
                  isThreeLine: !r.benar,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Poin sudah berubah di server → segarkan layar poin.
                      ref.invalidate(gamifikasiRingkasanProvider);
                      ref.invalidate(leaderboardProvider);
                      ref.read(poinHistoryProvider.notifier).muatUlang();
                      ref.read(gameSesiProvider.notifier).ulangi();
                    },
                    child: const Text('Kembali'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => ref
                        .read(gameSesiProvider.notifier)
                        .mulai(hasil.mode),
                    child: const Text('Main lagi'),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (hasil.lulus) const IgnorePointer(child: ConfettiOverlay()),
      ],
    );
  }
}
