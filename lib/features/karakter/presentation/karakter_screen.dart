import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../application/karakter_providers.dart';
import '../data/karakter_luhur.dart';

/// Daftar 29 Karakter Luhur — pintu masuk ke pembaca beranimasi.
class KarakterScreen extends ConsumerWidget {
  const KarakterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(karakterListProvider);
    final dibaca = ref.watch(bacaProgressProvider);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(karakterListProvider);
        await ref.read(karakterListProvider.future);
      },
      child: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorPanel(
          message: '$e'.replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(karakterListProvider),
        ),
        data: (items) {
          final selesai = items.where((k) => dibaca.contains(k.slug)).length;
          final progress = items.isEmpty ? 0.0 : selesai / items.length;

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
                            Icon(Icons.auto_awesome,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '29 Karakter Luhur',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            AnimatedCounter(
                              value: selesai,
                              suffix: '/${items.length}',
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          selesai == items.length && items.isNotEmpty
                              ? 'Semua materi sudah kamu baca. Luar biasa! '
                                  'Sekarang saatnya dipraktikkan.'
                              : 'Baca satu per satu, pahami dalilnya, lalu '
                                  'praktikkan dalam kehidupan sehari-hari.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        AnimatedBar(value: progress),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () async {
                              await ref
                                  .read(tutorialSelesaiProvider.notifier)
                                  .reset();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Tutorial akan muncul lagi saat membuka '
                                      'materi berikutnya.',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.help_outline, size: 18),
                            label: const Text('Tampilkan tutorial lagi'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(items.length, (i) {
                final k = items[i];
                final sudah = dibaca.contains(k.slug);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FadeSlideIn(
                    index: i,
                    child: PressableCard(
                      onTap: () => context.push('/karakter/${k.slug}'),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              _NomorBadge(nomor: k.nomor, selesai: sudah),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      k.nama,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600),
                                    ),
                                    if (k.namaArab != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        k.namaArab!,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                    if (k.ringkas != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        k.ringkas!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                sudah
                                    ? Icons.check_circle
                                    : Icons.chevron_right,
                                color: sudah
                                    ? theme.colorScheme.primary
                                    : theme.iconTheme.color,
                                size: sudah ? 22 : 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _NomorBadge extends StatelessWidget {
  const _NomorBadge({required this.nomor, required this.selesai});

  final int nomor;
  final bool selesai;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selesai ? scheme.primary : scheme.surfaceContainerHighest,
      ),
      child: Text(
        '$nomor',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: selesai ? Colors.white : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Dipakai router: judul dinamis untuk halaman detail.
String karakterTitle(KarakterLuhur k) => '${k.nomor}. ${k.nama}';
