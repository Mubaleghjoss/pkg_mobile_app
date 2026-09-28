import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/network/paginated.dart';
import '../../../core/storage/session_store.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../data/quran_models.dart';
import 'quran_reader_screen.dart';

final quranProgressProvider = FutureProvider<QuranProgress>((ref) async {
  final result = await ref.watch(quranRepositoryProvider).progress();
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat progres bacaan');
  }
  return result.data!;
});

final quranEntriesProvider = FutureProvider<Paginated<QuranEntry>>((ref) async {
  final result = await ref.watch(quranRepositoryProvider).entries(perPage: 30);
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat catatan bacaan');
  }
  return result.data!;
});

final quranSurahProvider = FutureProvider<List<QuranSurah>>((ref) async {
  final result = await ref.watch(quranRepositoryProvider).surahs();
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat daftar surah');
  }
  return result.data!;
});

/// Tracer bacaan Al-Quran: progres khatam + riwayat catatan.
class QuranScreen extends ConsumerWidget {
  const QuranScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(quranProgressProvider);
    final entries = ref.watch(quranEntriesProvider);
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final isOrtu = auth.session?.actor == AuthActor.ortu;
    final isSiswa = auth.session?.actor == AuthActor.siswa;

    final lastRead = ref.watch(quranPositionProvider).value;
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(
              lastRead == null ? 'Baca Al-Quran' : 'Lanjutkan membaca',
            ),
            subtitle: lastRead == null
                ? const Text('114 surah tersedia offline')
                : Text('Surah ${lastRead.surah}, ayat ${lastRead.ayah}'),
            trailing: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  tooltip: 'Buka mushaf Utsmani',
                  icon: const Icon(Icons.auto_stories_outlined),
                  onPressed: () => context.push('/quran/mushaf'),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => lastRead == null
                ? context.push('/quran/baca')
                : context.push(
                    '/quran/baca/${lastRead.surah}',
                    extra: lastRead.ayah,
                  ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(quranProgressProvider);
              ref.invalidate(quranEntriesProvider);
              await ref.read(quranProgressProvider.future);
            },
            child: progress.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorPanel(
                message: '$e'.replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(quranProgressProvider),
              ),
              data: (p) => ListView(
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
                                Icon(
                                  Icons.auto_stories_outlined,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    p.siklus == null
                                        ? 'Belum ada siklus khatam'
                                        : 'Khatam ke-${p.siklus!.nomor}',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (p.siklus != null)
                                  AnimatedCounter(
                                    value: p.siklus!.persentase,
                                    suffix: '%',
                                    decimals: 0,
                                    style: theme.textTheme.titleMedium,
                                  ),
                              ],
                            ),
                            if (p.siklus != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                '${p.siklus!.surahSelesai} dari '
                                '${p.siklus!.surahTotal} surah selesai',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              AnimatedBar(value: p.siklus!.persentase / 100),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    index: 1,
                    child: Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Halaman terverifikasi',
                            value: '${p.totalHalamanTerverifikasi}',
                            icon: Icons.verified_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            label: 'Menunggu verifikasi',
                            value: '${p.entriPending}',
                            icon: Icons.hourglass_bottom_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    index: 2,
                    child: Card(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOrtu
                                  ? 'Mode orang tua: memantau bacaan anak. Entri baru '
                                        'dicatat oleh siswa atau pamong.'
                                  : isSiswa
                                  ? 'Catat bacaan manual atau scan QR lembar '
                                        'tracer milikmu. Hasil scan menunggu '
                                        'verifikasi pamong.'
                                  : 'Scan QR lembar siswa binaan untuk mencatat '
                                        'bacaan terverifikasi.',
                              style: theme.textTheme.bodySmall,
                            ),
                            if (isSiswa) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: () =>
                                          context.push('/quran/baca'),
                                      icon: const Icon(
                                        Icons.menu_book_outlined,
                                      ),
                                      label: const Text('Baca Al-Quran'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filledTonal(
                                    tooltip: 'Scan lembar',
                                    onPressed: () =>
                                        context.push('/quran/tracer'),
                                    icon: const Icon(
                                      Icons.qr_code_scanner_outlined,
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
                  const SizedBox(height: 18),
                  Text(
                    'Riwayat catatan',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  entries.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => ErrorPanel(
                      message: '$e'.replaceFirst('Exception: ', ''),
                      onRetry: () => ref.invalidate(quranEntriesProvider),
                    ),
                    data: (page) => page.items.isEmpty
                        ? Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Belum ada catatan bacaan.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          )
                        : Column(
                            children: List.generate(page.items.length, (i) {
                              final e = page.items[i];
                              return FadeSlideIn(
                                index: i,
                                child: _EntryTile(entry: e, readOnly: isOrtu),
                              );
                            }),
                          ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry, required this.readOnly});

  final QuranEntry entry;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (ikon, warna, label) = switch (entry.status) {
      'verified' => (
        Icons.verified,
        theme.colorScheme.primary,
        'Terverifikasi',
      ),
      'rejected' => (Icons.cancel_outlined, theme.colorScheme.error, 'Ditolak'),
      _ => (
        Icons.hourglass_empty,
        theme.colorScheme.onSurfaceVariant,
        'Menunggu verifikasi',
      ),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ikon, size: 18, color: warna),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.readingDate == null
                        ? '-'
                        : DateFormat(
                            'EEEE, d MMM yyyy',
                            'id',
                          ).format(entry.readingDate!),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (entry.canDelete && !readOnly)
                  IconButton(
                    tooltip: 'Hapus catatan',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _hapus(context, ref),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (entry.pageRangeLabel != null)
              Text(entry.pageRangeLabel!, style: theme.textTheme.bodyMedium),
            if (entry.surahRangeLabel != null)
              Text(
                entry.surahRangeLabel!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            if (entry.notes != null) ...[
              const SizedBox(height: 6),
              Text(entry.notes!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 6),
            Text(
              '$label · sumber ${entry.source == 'sheet' ? 'lembar' : 'manual'}',
              style: theme.textTheme.labelSmall?.copyWith(color: warna),
            ),
            if (entry.verificationNotes != null) ...[
              const SizedBox(height: 4),
              Text(
                'Catatan pamong: ${entry.verificationNotes}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _hapus(BuildContext context, WidgetRef ref) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus catatan?'),
        content: const Text(
          'Catatan yang belum diverifikasi akan dihapus permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (!(yakin ?? false)) return;

    final result = await ref.read(quranRepositoryProvider).destroy(entry.id);
    if (!context.mounted) return;
    if (result.ok) {
      ref.invalidate(quranEntriesProvider);
      ref.invalidate(quranProgressProvider);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Gagal menghapus catatan')),
      );
    }
  }
}
