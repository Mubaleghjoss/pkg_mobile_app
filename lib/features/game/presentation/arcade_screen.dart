import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/celebration.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../application/game_providers.dart';
import '../data/game_models.dart';

/// Arcade "Rangkai Kata" bertempo.
///
/// Aturan: 60 detik, tiap kata benar menambah skor dan combo; salah/lewat
/// memutus combo. Skor akhir dikirim ke `POST /game/arcade/skor` (server hanya
/// menyimpan bila melampaui rekor pribadi), lalu papan skor dimuat ulang.
///
/// Kata diambil dari `GET /game/arcade/kata` (40 kata), pengacakan huruf
/// dilakukan di klien — tidak ada kunci jawaban rahasia di sini karena kata
/// asli memang dikirim server sebagai bahan permainan.
class ArcadeScreen extends ConsumerStatefulWidget {
  const ArcadeScreen({super.key});

  @override
  ConsumerState<ArcadeScreen> createState() => _ArcadeScreenState();
}

enum _Fase { siap, memuat, bermain, selesai }

class _ArcadeScreenState extends ConsumerState<ArcadeScreen> {
  static const _durasiDetik = 60;

  /// Poin dasar per kata benar; bonus combo ditambahkan terpisah.
  static const _skorPerKata = 100;

  final _rng = Random();

  _Fase _fase = _Fase.siap;
  String? _error;

  List<String> _bank = const [];
  int _bankIndex = 0;

  String _target = '';
  List<String> _huruf = const [];
  final List<int> _dipilih = [];

  int _skor = 0;
  int _combo = 0;
  int _comboTerbaik = 0;
  int _benar = 0;
  int _lewat = 0;
  int _sisaDetik = _durasiDetik;

  Timer? _timer;
  bool _menyimpan = false;
  String? _hasilSimpan;
  bool _rekorBaru = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _mulai() async {
    setState(() {
      _fase = _Fase.memuat;
      _error = null;
    });

    final result = await ref.read(gameRepositoryProvider).arcadeKata();
    if (!mounted) return;

    if (!result.ok || result.data == null || result.data!.length < 4) {
      setState(() {
        _fase = _Fase.siap;
        _error =
            result.error ??
            'Kata arcade belum cukup. Minta pamong menambah data karakter.';
      });
      return;
    }

    final bank = [...result.data!]..shuffle(_rng);
    setState(() {
      _bank = bank;
      _bankIndex = 0;
      _skor = 0;
      _combo = 0;
      _comboTerbaik = 0;
      _benar = 0;
      _lewat = 0;
      _sisaDetik = _durasiDetik;
      _hasilSimpan = null;
      _rekorBaru = false;
      _fase = _Fase.bermain;
    });
    _kataBerikut();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_sisaDetik <= 1) {
        setState(() => _sisaDetik = 0);
        _selesai();
        return;
      }
      setState(() => _sisaDetik -= 1);
    });
  }

  void _kataBerikut() {
    if (_bank.isEmpty) return;
    // Bank berputar bila kata habis sebelum waktu berakhir.
    final kata = _bank[_bankIndex % _bank.length].toUpperCase();
    _bankIndex++;

    final huruf = kata.replaceAll(' ', '').split('');
    List<String> acak;
    var percobaan = 0;
    do {
      acak = [...huruf]..shuffle(_rng);
      percobaan++;
      // Hindari susunan yang kebetulan sudah benar (kecuali kata 1 huruf).
    } while (percobaan < 8 && acak.join() == huruf.join() && huruf.length > 1);

    setState(() {
      _target = huruf.join();
      _huruf = acak;
      _dipilih.clear();
    });
  }

  String get _jawaban => _dipilih.map((i) => _huruf[i]).join();

  void _tapHuruf(int i) {
    if (_fase != _Fase.bermain || _dipilih.contains(i)) return;
    setState(() => _dipilih.add(i));
    if (_jawaban.length == _target.length) _periksa();
  }

  void _hapus() {
    if (_dipilih.isEmpty) return;
    setState(() => _dipilih.removeLast());
  }

  void _periksa() {
    if (_jawaban == _target) {
      HapticFeedback.lightImpact();
      setState(() {
        _benar++;
        _combo++;
        _comboTerbaik = max(_comboTerbaik, _combo);
        // Bonus combo: 20 poin per rantai, dibatasi 200 agar tidak meledak.
        _skor += _skorPerKata + min(_combo * 20, 200);
        // Bonus waktu kecil sebagai imbalan kecepatan.
        _sisaDetik = min(_durasiDetik, _sisaDetik + 2);
      });
      _kataBerikut();
    } else {
      HapticFeedback.selectionClick();
      setState(() {
        _combo = 0;
        _dipilih.clear();
      });
    }
  }

  void _lewati() {
    if (_fase != _Fase.bermain) return;
    setState(() {
      _lewat++;
      _combo = 0;
      _sisaDetik = max(0, _sisaDetik - 3);
    });
    _kataBerikut();
  }

  Future<void> _selesai() async {
    _timer?.cancel();
    setState(() => _fase = _Fase.selesai);

    if (_skor <= 0) return;

    setState(() => _menyimpan = true);
    final result = await ref
        .read(gameRepositoryProvider)
        .simpanSkorArcade(skor: _skor, combo: _comboTerbaik);
    if (!mounted) return;

    setState(() {
      _menyimpan = false;
      if (result.ok) {
        _rekorBaru = result.data == true;
        _hasilSimpan = _rekorBaru ? 'Rekor baru tersimpan.' : 'Skor tersimpan.';
      } else {
        _hasilSimpan = result.error ?? 'Skor gagal disimpan.';
      }
    });

    if (result.ok) {
      ref.invalidate(arcadeLeaderboardProvider);
      ref.invalidate(gameInfoProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(gameInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arcade Rangkai Kata'),
        actions: [
          if (_fase == _Fase.bermain)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '$_sisaDetik s',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _sisaDetik <= 10 ? Colors.red : null,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (_fase) {
          _Fase.memuat => const Center(child: CircularProgressIndicator()),
          _Fase.siap => _panelSiap(info),
          _Fase.bermain => _panelBermain(),
          _Fase.selesai => _panelSelesai(),
        },
      ),
    );
  }

  Widget _panelSiap(AsyncValue<GameInfo> info) {
    final data = info.asData?.value;
    final hanyaMemantau = data?.hanyaMemantau ?? false;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FadeSlideIn(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Susun kata karakter secepat mungkin',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Waktu 60 detik. Tiap kata benar menambah skor, combo, dan '
                    '+2 detik. Melewati kata memotong 3 detik dan memutus '
                    'combo. Hanya skor tertinggi yang disimpan.',
                  ),
                  if (data != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Rekor skor',
                            value: '${data.skorTerbaikArcade}',
                            icon: Icons.emoji_events_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            label: 'Combo terbaik',
                            value: '${data.comboTerbaikArcade}',
                            icon: Icons.bolt_outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          ErrorPanel(message: _error!),
        ],
        const SizedBox(height: 16),
        if (hanyaMemantau)
          const ErrorPanel(
            message: 'Akun orang tua hanya memantau, tidak bisa bermain.',
          )
        else
          FilledButton.icon(
            onPressed: _mulai,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Mulai 60 detik'),
          ),
        const SizedBox(height: 24),
        _PapanSkorRingkas(),
      ],
    );
  }

  Widget _panelBermain() {
    final theme = Theme.of(context);
    final jawaban = _jawaban;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBar(value: _sisaDetik / _durasiDetik),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Skor',
                        value: '$_skor',
                        icon: Icons.star_outline,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: 'Combo',
                        value: 'x$_combo',
                        icon: Icons.bolt_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Kotak jawaban: satu slot per huruf target.
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < _target.length; i++)
                      Container(
                        width: 34,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: i < jawaban.length
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Text(
                          i < jawaban.length ? jawaban[i] : '',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_target.length} huruf',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _huruf.length; i++)
                      _TombolHuruf(
                        huruf: _huruf[i],
                        terpakai: _dipilih.contains(i),
                        onTap: () => _tapHuruf(i),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _dipilih.isEmpty ? null : _hapus,
                        icon: const Icon(Icons.backspace_outlined),
                        label: const Text('Hapus'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _lewati,
                        icon: const Icon(Icons.skip_next_outlined),
                        label: const Text('Lewati (-3s)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _selesai,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Akhiri sekarang'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _panelSelesai() {
    final theme = Theme.of(context);

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FadeSlideIn(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        _rekorBaru
                            ? Icons.emoji_events
                            : Icons.sports_score_outlined,
                        size: 44,
                        color: _rekorBaru ? Colors.amber.shade700 : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$_skor',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('skor akhir', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'Kata benar',
                              value: '$_benar',
                              icon: Icons.check_circle_outline,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              label: 'Combo terbaik',
                              value: 'x$_comboTerbaik',
                              icon: Icons.bolt_outlined,
                            ),
                          ),
                        ],
                      ),
                      if (_lewat > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          '$_lewat kata dilewati',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_menyimpan)
                        const LinearProgressIndicator()
                      else if (_hasilSimpan != null)
                        Text(
                          _hasilSimpan!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _rekorBaru ? Colors.green.shade700 : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _menyimpan ? null : _mulai,
              icon: const Icon(Icons.replay),
              label: const Text('Main lagi'),
            ),
            const SizedBox(height: 24),
            _PapanSkorRingkas(),
          ],
        ),
        if (_rekorBaru) const IgnorePointer(child: ConfettiOverlay()),
      ],
    );
  }
}

class _TombolHuruf extends StatelessWidget {
  const _TombolHuruf({
    required this.huruf,
    required this.terpakai,
    required this.onTap,
  });

  final String huruf;
  final bool terpakai;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: !terpakai,
      label: 'Huruf $huruf',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: terpakai ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 44,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: terpakai
                ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
                : scheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: terpakai ? scheme.outlineVariant : scheme.primary,
            ),
          ),
          child: Text(
            terpakai ? '' : huruf,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// Papan skor arcade ringkas (5 teratas + posisi saya bila di luar 5).
class _PapanSkorRingkas extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(arcadeLeaderboardProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorPanel(
        message: '$e'.replaceFirst('Exception: ', ''),
        onRetry: () => ref.invalidate(arcadeLeaderboardProvider),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const ErrorPanel(message: 'Belum ada skor arcade.');
        }
        final teratas = rows.take(5).toList();
        final saya = rows.where((r) => r.isSaya).firstOrNull;
        final sayaDiLuar = saya != null && !teratas.any((r) => r.isSaya)
            ? saya
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Papan skor',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...teratas.map((r) => _BarisSkor(skor: r)),
            if (sayaDiLuar != null) ...[
              const Divider(),
              _BarisSkor(skor: sayaDiLuar),
            ],
          ],
        );
      },
    );
  }
}

class _BarisSkor extends StatelessWidget {
  const _BarisSkor({required this.skor});

  final ArcadeSkor skor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: skor.isSaya
            ? scheme.primaryContainer.withValues(alpha: 0.5)
            : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: skor.isSaya ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${skor.peringkat}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              skor.nama,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: skor.isSaya ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '${skor.skor}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (skor.combo > 0) ...[
            const SizedBox(width: 8),
            Text(
              'x${skor.combo}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
