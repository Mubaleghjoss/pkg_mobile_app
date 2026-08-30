import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../data/presensi_repository.dart';
import 'presensi_screen.dart';

/// Rentang tanggal untuk statistik. `GET /presensi/statistics` MEWAJIBKAN
/// `start_date` dan `end_date` (tanpa keduanya → 422).
class StatistikRange {
  const StatistikRange(this.start, this.end, this.label);

  final DateTime start;
  final DateTime end;
  final String label;

  static StatistikRange bulanIni() {
    final now = DateTime.now();
    return StatistikRange(
      DateTime(now.year, now.month, 1),
      now,
      'Bulan ini',
    );
  }

  static StatistikRange hariIni() {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day);
    return StatistikRange(d, d, 'Hari ini');
  }

  static StatistikRange tujuhHari() {
    final now = DateTime.now();
    return StatistikRange(
      now.subtract(const Duration(days: 6)),
      now,
      '7 hari terakhir',
    );
  }

  static StatistikRange tigaPuluhHari() {
    final now = DateTime.now();
    return StatistikRange(
      now.subtract(const Duration(days: 29)),
      now,
      '30 hari terakhir',
    );
  }
}

/// Rentang aktif untuk layar statistik.
///
/// Riverpod 3 memindahkan `StateProvider` ke `legacy.dart`; dipakai
/// `NotifierProvider` agar tetap di API utama.
class StatistikRangeController extends Notifier<StatistikRange> {
  @override
  StatistikRange build() => StatistikRange.bulanIni();

  void set(StatistikRange range) => state = range;
}

final statistikRangeProvider =
    NotifierProvider<StatistikRangeController, StatistikRange>(
        StatistikRangeController.new);

final presensiStatistikProvider =
    FutureProvider<PresensiStatistics>((ref) async {
  final range = ref.watch(statistikRangeProvider);
  final result = await ref.watch(presensiRepositoryProvider).statistics(
        start: range.start,
        end: range.end,
      );
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat statistik presensi');
  }
  return result.data!;
});

class PresensiStatistikScreen extends ConsumerWidget {
  const PresensiStatistikScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final range = ref.watch(statistikRangeProvider);
    final async = ref.watch(presensiStatistikProvider);

    if (!auth.can('view_attendance')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Statistik presensi')),
        body: const NoPermissionPanel(permission: 'view_attendance'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik presensi'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: () => ref.invalidate(presensiStatistikProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                StatistikRange.hariIni(),
                StatistikRange.tujuhHari(),
                StatistikRange.bulanIni(),
                StatistikRange.tigaPuluhHari(),
              ]
                  .map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(r.label),
                        selected: r.label == range.label,
                        onSelected: (_) => ref
                            .read(statistikRangeProvider.notifier)
                            .set(r),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_ymd(range.start)} s.d. ${_ymd(range.end)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorPanel(
                message: '$e'.replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(presensiStatistikProvider),
              ),
              data: (stat) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FadeSlideIn(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              'Persentase kehadiran',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            AnimatedCounter(
                              value: stat.persentaseKehadiran,
                              decimals: 2,
                              suffix: '%',
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 16),
                            AnimatedBar(
                              value: stat.persentaseKehadiran / 100,
                              height: 10,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${stat.verified} dari ${stat.total} baris '
                              'terverifikasi',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    index: 1,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rincian per status',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            ..._rows(context, stat),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    index: 2,
                    child: Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Total baris',
                            value: '${stat.total}',
                            icon: Icons.list_alt,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            label: 'Terverifikasi',
                            value: '${stat.verified}',
                            icon: Icons.verified_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _rows(BuildContext context, PresensiStatistics stat) {
    final maxValue = stat.breakdown
        .map((e) => e.$2)
        .fold<int>(0, (a, b) => a > b ? a : b);

    // Kunci status untuk mewarnai bar sama seperti ikon di daftar presensi.
    const keys = ['hadir', 'terlambat', 'izin', 'sakit', 'alpha', 'tidak_hadir'];

    return [
      for (var i = 0; i < stat.breakdown.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(stat.breakdown[i].$1)),
                  AnimatedCounter(
                    value: stat.breakdown[i].$2,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              AnimatedBar(
                value: maxValue == 0 ? 0 : stat.breakdown[i].$2 / maxValue,
                color: presensiStatusColor(keys[i]),
              ),
            ],
          ),
        ),
    ];
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
