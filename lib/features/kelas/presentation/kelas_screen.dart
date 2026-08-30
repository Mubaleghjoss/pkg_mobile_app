import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../domain/kelas.dart';

final kelasListProvider = FutureProvider<List<Kelas>>((ref) async {
  final result = await ref.watch(kelasRepositoryProvider).list();
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat kelas');
  }
  return result.data!;
});

/// `GET /api/v1/kelas/stats` — ringkasan jumlah kelas/pamong/siswa.
final kelasStatsProvider = FutureProvider<KelasStats>((ref) async {
  final result = await ref.watch(kelasRepositoryProvider).stats();
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat ringkasan kelas');
  }
  return result.data!;
});

class KelasScreen extends ConsumerWidget {
  const KelasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kelas = ref.watch(kelasListProvider);
    final stats = ref.watch(kelasStatsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(kelasListProvider);
        ref.invalidate(kelasStatsProvider);
        await ref.read(kelasListProvider.future);
      },
      child: kelas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorPanel(
          message: '$e'.replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(kelasListProvider),
        ),
        data: (items) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Endpoint /kelas ditandai deprecated oleh backend. Data ini '
                  'arsip; menu Binaan Pamong / Kelas Sekolah belum punya API v1.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Ringkasan dari /kelas/stats — dibiarkan diam kalau endpoint gagal
            // supaya daftar kelas tetap terpakai.
            stats.maybeWhen(
              data: (s) => FadeSlideIn(
                child: Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Kelas aktif',
                        value: '${s.activeKelas}/${s.totalKelas}',
                        icon: Icons.class_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        label: 'Pamong',
                        value: '${s.totalPamong}',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            ...List.generate(items.length, (i) {
              final k = items[i];
              return FadeSlideIn(
                index: i < 12 ? i : 0,
                child: PressableCard(
                  onTap: () => context.push('/kelas/${k.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                k.nama,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Text('${(k.okupansi * 100).round()}%'),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 20),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tingkat ${k.tingkat ?? '-'} · '
                          '${k.siswaCount ?? 0}/${k.kapasitas ?? 0} siswa',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        AnimatedBar(value: k.okupansi.clamp(0, 1).toDouble()),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
