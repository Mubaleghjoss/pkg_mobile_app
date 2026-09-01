import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/network/paginated.dart';
import '../../../core/storage/session_store.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../data/tugas_pkg.dart';

/// Filter riwayat: semua pengerjaan atau hanya yang belum diverifikasi.
class TugasRiwayatFilterController extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool onlyUnverified) => state = onlyUnverified;
}

final tugasRiwayatFilterProvider =
    NotifierProvider<TugasRiwayatFilterController, bool>(
  TugasRiwayatFilterController.new,
);

/// Halaman riwayat yang sedang dilihat (1-based).
class TugasRiwayatHalamanController extends Notifier<int> {
  @override
  int build() => 1;

  void set(int page) => state = page;
}

final tugasRiwayatHalamanProvider =
    NotifierProvider<TugasRiwayatHalamanController, int>(
  TugasRiwayatHalamanController.new,
);

final tugasRiwayatProvider =
    FutureProvider<Paginated<TugasChecklist>>((ref) async {
  final onlyUnverified = ref.watch(tugasRiwayatFilterProvider);
  final page = ref.watch(tugasRiwayatHalamanProvider);
  final result = await ref.watch(tugasRepositoryProvider).history(
        page: page,
        perPage: 20,
        onlyUnverified: onlyUnverified,
      );
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat riwayat tugas');
  }
  return result.data!;
});

final tugasRingkasanProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final result = await ref.watch(tugasRepositoryProvider).summary();
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat ringkasan tugas');
  }
  return result.data!;
});

/// Riwayat pengerjaan tugas PKG lintas hari (`GET /tugas-pkg/history`)
/// beserta ringkasan (`GET /tugas-pkg/summary`).
///
/// Backend memakai token siswa maupun ortu: siswa melihat miliknya, ortu
/// melihat milik anaknya. Karena itu satu layar ini dipakai kedua peran, hanya
/// salinan teksnya yang menyesuaikan.
class TugasRiwayatScreen extends ConsumerWidget {
  const TugasRiwayatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOrtu =
        ref.watch(authControllerProvider).session?.actor == AuthActor.ortu;
    final onlyUnverified = ref.watch(tugasRiwayatFilterProvider);
    final riwayat = ref.watch(tugasRiwayatProvider);
    final ringkasan = ref.watch(tugasRingkasanProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isOrtu ? 'Riwayat tugas anak' : 'Riwayat tugas'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(tugasRingkasanProvider);
          ref.invalidate(tugasRiwayatProvider);
          await ref.read(tugasRiwayatProvider.future);
        },
        child: riwayat.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorPanel(
                message: '$e'.replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(tugasRiwayatProvider),
              ),
            ],
          ),
          data: (page) => ListView(
            padding: const EdgeInsets.all(12),
            children: [
              ringkasan.maybeWhen(
                data: (r) => _Ringkasan(data: r),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Semua'),
                    selected: !onlyUnverified,
                    onSelected: (_) {
                      ref.read(tugasRiwayatHalamanProvider.notifier).set(1);
                      ref.read(tugasRiwayatFilterProvider.notifier).set(false);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Belum diverifikasi'),
                    selected: onlyUnverified,
                    onSelected: (_) {
                      ref.read(tugasRiwayatHalamanProvider.notifier).set(1);
                      ref.read(tugasRiwayatFilterProvider.notifier).set(true);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (page.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text('Belum ada riwayat pengerjaan.')),
                )
              else
                ...page.items.asMap().entries.map(
                      (e) => FadeSlideIn(
                        index: e.key,
                        child: _KartuRiwayat(item: e.value),
                      ),
                    ),
              if (page.meta.lastPage > 1) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Sebelumnya',
                      onPressed: page.meta.currentPage > 1
                          ? () => ref
                              .read(tugasRiwayatHalamanProvider.notifier)
                              .set(page.meta.currentPage - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('Hal. ${page.meta.currentPage} '
                        'dari ${page.meta.lastPage}'),
                    IconButton(
                      tooltip: 'Berikutnya',
                      onPressed: page.meta.currentPage < page.meta.lastPage
                          ? () => ref
                              .read(tugasRiwayatHalamanProvider.notifier)
                              .set(page.meta.currentPage + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Ringkasan extends StatelessWidget {
  const _Ringkasan({required this.data});

  final Map<String, dynamic> data;

  int _int(String key) => (data[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final persen = (data['persentase_hari_ini'] as num?)?.toDouble() ?? 0;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Selesai hari ini',
                value: '${_int('selesai_hari_ini')}/${_int('tugas_hari_ini')}',
                icon: Icons.today_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'Menunggu verifikasi',
                value: '${_int('menunggu_verifikasi')}',
                icon: Icons.pending_actions_outlined,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Poin terverifikasi',
                value: '${_int('poin_terverifikasi')}',
                icon: Icons.stars_outlined,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'Progres hari ini',
                value: '${persen.toStringAsFixed(persen % 1 == 0 ? 0 : 1)}%',
                icon: Icons.donut_small_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KartuRiwayat extends StatelessWidget {
  const _KartuRiwayat({required this.item});

  final TugasChecklist item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tgl = item.checkedAt == null
        ? '-'
        : DateFormat('EEEE, d MMM yyyy · HH:mm', 'id').format(item.checkedAt!);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.karakterNama,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('${item.poin} poin'),
                ),
              ],
            ),
            Text(tgl, style: theme.textTheme.bodySmall),
            if (item.hasilTeks != null && item.hasilTeks!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(item.hasilTeks!, style: theme.textTheme.bodySmall),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  item.isVerified ? Icons.verified : Icons.hourglass_empty,
                  size: 16,
                  color: item.isVerified
                      ? Colors.green
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.isVerified
                        ? 'Diverifikasi ${item.verifiedBy ?? '-'}'
                            '${item.notes == null || item.notes!.isEmpty ? '' : ' — ${item.notes}'}'
                        : 'Menunggu verifikasi pamong',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            if (item.komentarOrtu.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...item.komentarOrtu.map(
                (k) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          k.comment,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (item.hasProofPhoto || item.hasProofVoice) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  if (item.hasProofPhoto)
                    const Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(Icons.photo_outlined, size: 16),
                      label: Text('Foto'),
                    ),
                  if (item.hasProofVoice)
                    const Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(Icons.mic_none, size: 16),
                      label: Text('Voice'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
