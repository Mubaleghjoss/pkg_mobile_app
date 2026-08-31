import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/network/paginated.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../data/materi.dart';

/// Daftar materi pembinaan (halaman pertama; cukup untuk kebutuhan baca).
final materiListProvider =
    FutureProvider<Paginated<Materi>>((ref) async {
  final result = await ref.watch(materiRepositoryProvider).list(perPage: 50);
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat materi');
  }
  return result.data!;
});

final materiDetailProvider =
    FutureProvider.family<Materi, int>((ref, id) async {
  final result = await ref.watch(materiRepositoryProvider).detail(id);
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat materi');
  }
  return result.data!;
});

class MateriScreen extends ConsumerWidget {
  const MateriScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(materiListProvider);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(materiListProvider);
        await ref.read(materiListProvider.future);
      },
      child: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorPanel(
          message: '$e'.replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(materiListProvider),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return const ErrorPanel(
              message: 'Belum ada materi yang dipublikasikan.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: page.items.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return FadeSlideIn(
                  child: Card(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.menu_book_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${page.meta.total} materi tersedia. Materi '
                              'dibuat admin lewat web; di sini kamu membacanya.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final m = page.items[i - 1];
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: FadeSlideIn(
                  index: i,
                  child: PressableCard(
                    onTap: () => context.push('/materi/${m.id}'),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    m.judul,
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const Icon(Icons.chevron_right, size: 20),
                              ],
                            ),
                            if (m.deskripsi != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                m.deskripsi!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (m.folder != null)
                                  _Tag(
                                    icon: Icons.folder_outlined,
                                    label: m.folder!.name,
                                  ),
                                if (m.pdfCount > 0)
                                  _Tag(
                                    icon: Icons.picture_as_pdf_outlined,
                                    label: '${m.pdfCount} PDF',
                                  ),
                                if (m.videoCount > 0)
                                  _Tag(
                                    icon: Icons.play_circle_outline,
                                    label: '${m.videoCount} video',
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSecondaryContainer),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: scheme.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}
