import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/celebration.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../application/karakter_providers.dart';
import '../data/karakter_luhur.dart';

/// Pembaca materi satu karakter: satu bagian per halaman, dengan progres,
/// tutorial sekali-tampil, dan perayaan saat tuntas.
class KarakterReaderScreen extends ConsumerStatefulWidget {
  const KarakterReaderScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<KarakterReaderScreen> createState() =>
      _KarakterReaderScreenState();
}

class _KarakterReaderScreenState extends ConsumerState<KarakterReaderScreen> {
  final _pageController = PageController();
  int _page = 0;
  bool _tutorialDitampilkan = false;
  bool _selesaiDitangani = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Tutorial 3 langkah, muncul sekali. Tombol "Lewati" langsung menutup dan
  /// menandai selesai supaya tidak mengganggu lagi.
  Future<void> _mungkinTampilkanTutorial() async {
    if (_tutorialDitampilkan) return;
    _tutorialDitampilkan = true;

    final sudah = ref.read(tutorialSelesaiProvider);
    if (sudah) return;

    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _TutorialDialog(),
    );
    if (mounted) {
      await ref.read(tutorialSelesaiProvider.notifier).selesai();
    }
  }

  Future<void> _selesaikan(KarakterLuhur k, List<KarakterLuhur> semua) async {
    if (_selesaiDitangani) return;
    _selesaiDitangani = true;

    await ref.read(bacaProgressProvider.notifier).tandaiSelesai(k.slug);
    if (!mounted) return;

    final dibaca = ref.read(bacaProgressProvider);
    final berikutnya = semua.where((e) => !dibaca.contains(e.slug)).toList();
    final next = berikutnya.isEmpty ? null : berikutnya.first;

    final lanjut = await showMateriSelesaiDialog(
      context,
      judul: '${k.nomor}. ${k.nama}',
      poin: dibaca.length,
      nextLabel: next == null ? 'Selesai semua' : 'Materi ${next.nomor}',
    );

    if (!mounted) return;
    _selesaiDitangani = false;

    if (lanjut && next != null) {
      // Ganti rute supaya tombol kembali tidak menumpuk halaman pembaca.
      context.pushReplacement('/karakter/${next.slug}');
    } else if (lanjut && next == null) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(karakterDetailProvider(widget.slug));
    final listAsync = ref.watch(karakterListProvider);
    final theme = Theme.of(context);

    return detail.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Materi karakter')),
        body: ErrorPanel(
          message: '$e'.replaceFirst('Exception: ', ''),
          onRetry: () =>
              ref.invalidate(karakterDetailProvider(widget.slug)),
        ),
      ),
      data: (k) {
        final sections = k.sections;
        if (sections.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(k.nama)),
            body: const ErrorPanel(
              message: 'Materi ini belum berisi uraian.',
            ),
          );
        }

        // Halaman terakhir = ringkasan + tombol selesai.
        final totalHalaman = sections.length + 1;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _mungkinTampilkanTutorial());

        final semua = listAsync.value ?? const <KarakterLuhur>[];

        return Scaffold(
          appBar: AppBar(
            title: Text('${k.nomor}. ${k.nama}'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0,
                  end: (_page + 1) / totalHalaman,
                ),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 4,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Text(
                      'Halaman ${_page + 1} dari $totalHalaman',
                      style: theme.textTheme.labelMedium,
                    ),
                    const Spacer(),
                    if (k.kategori != null)
                      Chip(
                        label: Text(k.kategori!),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: totalHalaman,
                  itemBuilder: (context, i) {
                    if (i == sections.length) {
                      return _HalamanPenutup(
                        karakter: k,
                        onSelesai: () => _selesaikan(k, semua),
                      );
                    }
                    return _HalamanSection(
                      key: ValueKey('${k.slug}-$i'),
                      section: sections[i],
                      nomorHalaman: i + 1,
                      totalHalaman: sections.length,
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: _page == 0
                            ? null
                            : () => _pageController.previousPage(
                                  duration: PkgMotion.page,
                                  curve: PkgMotion.curve,
                                ),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _page >= totalHalaman - 1
                              ? () => _selesaikan(k, semua)
                              : () => _pageController.nextPage(
                                    duration: PkgMotion.page,
                                    curve: PkgMotion.curve,
                                  ),
                          icon: Icon(
                            _page >= totalHalaman - 1
                                ? Icons.emoji_events_outlined
                                : Icons.arrow_forward,
                            size: 18,
                          ),
                          label: Text(
                            _page >= totalHalaman - 1
                                ? 'Saya sudah membaca'
                                : 'Lanjut',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Satu bagian materi, muncul dengan animasi bertingkat.
class _HalamanSection extends StatelessWidget {
  const _HalamanSection({
    super.key,
    required this.section,
    required this.nomorHalaman,
    required this.totalHalaman,
  });

  final KarakterSection section;
  final int nomorHalaman;
  final int totalHalaman;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PopIn(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                iconForSection(section.iconKey),
                size: 30,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            index: 1,
            child: Text(
              section.title,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            index: 2,
            child: Text(
              section.body,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.65),
            ),
          ),
          const SizedBox(height: 28),
          FadeSlideIn(
            index: 3,
            child: Row(
              children: List.generate(
                totalHalaman,
                (i) => Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: i == nomorHalaman - 1 ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: i < nomorHalaman
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Halaman terakhir: ajakan praktik + tombol selesai.
class _HalamanPenutup extends StatelessWidget {
  const _HalamanPenutup({required this.karakter, required this.onSelesai});

  final KarakterLuhur karakter;
  final VoidCallback onSelesai;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: PopIn(child: const PulsingBadge(size: 68))),
          const SizedBox(height: 20),
          FadeSlideIn(
            index: 1,
            child: Text(
              'Sudah selesai membaca?',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          FadeSlideIn(
            index: 2,
            child: Text(
              'Tekan tombol di bawah untuk menandai materi '
              '"${karakter.nama}" sebagai sudah dibaca.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 24),
          if (karakter.tipsAmal != null)
            FadeSlideIn(
              index: 3,
              child: Card(
                color: theme.colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.volunteer_activism_outlined,
                              size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Praktikkan hari ini',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        karakter.tipsAmal!,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          FadeSlideIn(
            index: 4,
            child: FilledButton.icon(
              onPressed: onSelesai,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Tandai sudah dibaca'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tutorial singkat 3 poin untuk pembaca pertama kali.
class _TutorialDialog extends StatefulWidget {
  const _TutorialDialog();

  @override
  State<_TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<_TutorialDialog> {
  int _step = 0;

  static const _steps = <_TutorialStep>[
    _TutorialStep(
      icon: Icons.swipe_left_outlined,
      title: 'Geser untuk membaca',
      body: 'Materi dibagi per halaman kecil: pengertian, dalil Al-Quran, '
          'hadits, hikmah, sampai cara menerapkannya. Geser ke kiri atau '
          'tekan "Lanjut" untuk pindah halaman.',
    ),
    _TutorialStep(
      icon: Icons.timeline_outlined,
      title: 'Pantau progresmu',
      body: 'Bar tipis di atas menunjukkan seberapa jauh kamu membaca. '
          'Titik-titik di bawah teks menandai halaman yang sudah dilewati.',
    ),
    _TutorialStep(
      icon: Icons.emoji_events_outlined,
      title: 'Selesaikan & rayakan',
      body: 'Di halaman terakhir tekan "Tandai sudah dibaca". Kamu akan '
          'mendapat ucapan selamat dan bisa langsung lanjut ke karakter '
          'berikutnya. Jangan lupa dipraktikkan ya!',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = _steps[_step];
    final terakhir = _step == _steps.length - 1;

    return AlertDialog(
      icon: PopIn(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primaryContainer,
          ),
          child: Icon(step.icon,
              size: 28, color: theme.colorScheme.onPrimaryContainer),
        ),
      ),
      title: Text(step.title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            step.body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _steps.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _step ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: i == _step
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Lewati'),
        ),
        FilledButton(
          onPressed: terakhir
              ? () => Navigator.of(context).pop()
              : () => setState(() => _step++),
          child: Text(terakhir ? 'Mulai membaca' : 'Lanjut'),
        ),
      ],
    );
  }
}

class _TutorialStep {
  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}
