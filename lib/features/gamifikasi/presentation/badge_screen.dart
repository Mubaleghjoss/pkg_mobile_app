import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../application/gamifikasi_providers.dart';
import '../data/gamifikasi_models.dart';

/// Koleksi badge siswa (halaman penuh).
///
/// Sumber data: `GET /api/v1/gamifikasi/badges` — sudah mengembalikan seluruh
/// badge yang dikonfigurasi sekolah beserta `sudah_didapat` dan
/// `progres_persen`, jadi layar ini murni presentasi tanpa endpoint baru.
///
/// Badge yang sudah didapat ditampilkan berwarna dengan tanggal perolehan;
/// yang belum tampil redup dengan bar progres.
class BadgeScreen extends ConsumerStatefulWidget {
  const BadgeScreen({super.key});

  @override
  ConsumerState<BadgeScreen> createState() => _BadgeScreenState();
}

class _BadgeScreenState extends ConsumerState<BadgeScreen> {
  /// null = semua, true = sudah didapat, false = belum.
  bool? _filterDidapat;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(badgesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Koleksi badge')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorPanel(
          message: '$e'.replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(badgesProvider),
        ),
        data: (semua) {
          if (semua.isEmpty) {
            return const ErrorPanel(
              message: 'Belum ada badge yang dikonfigurasi sekolah.',
            );
          }

          final didapat = semua.where((b) => b.sudahDidapat).length;
          final tampil = switch (_filterDidapat) {
            true => semua.where((b) => b.sudahDidapat).toList(),
            false => semua.where((b) => !b.sudahDidapat).toList(),
            null => semua,
          };

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(badgesProvider);
              await ref.read(badgesProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FadeSlideIn(
                  child: _KartuRingkas(
                    didapat: didapat,
                    total: semua.length,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final f in const <({bool? nilai, String label})>[
                      (nilai: null, label: 'Semua'),
                      (nilai: true, label: 'Sudah didapat'),
                      (nilai: false, label: 'Belum'),
                    ])
                      FilterChip(
                        label: Text(f.label),
                        selected: _filterDidapat == f.nilai,
                        onSelected: (_) =>
                            setState(() => _filterDidapat = f.nilai),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (tampil.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: ErrorPanel(
                      message: 'Tidak ada badge pada filter ini.',
                    ),
                  ),
                ...List.generate(tampil.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FadeSlideIn(
                      index: i,
                      child: _KartuBadgeBesar(badge: tampil[i]),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _KartuRingkas extends StatelessWidget {
  const _KartuRingkas({required this.didapat, required this.total});

  final int didapat;
  final int total;

  @override
  Widget build(BuildContext context) {
    final persen = total == 0 ? 0.0 : didapat / total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.emoji_events, size: 34, color: Colors.amber.shade700),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$didapat dari $total badge',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedBar(value: persen),
                  const SizedBox(height: 6),
                  Text(
                    '${(persen * 100).toStringAsFixed(0)}% koleksi lengkap',
                    style: Theme.of(context).textTheme.bodySmall,
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

class _KartuBadgeBesar extends StatelessWidget {
  const _KartuBadgeBesar({required this.badge});

  final BadgeItem badge;

  /// Warna dari backend berupa hex (`#RRGGBB`); jatuh ke amber bila tak valid.
  Color _warna(ColorScheme scheme) {
    final raw = badge.warna?.replaceAll('#', '');
    if (raw != null && (raw.length == 6 || raw.length == 8)) {
      final nilai = int.tryParse(raw.length == 6 ? 'FF$raw' : raw, radix: 16);
      if (nilai != null) return Color(nilai);
    }
    return Colors.amber.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final didapat = badge.sudahDidapat;
    final warna = didapat ? _warna(scheme) : scheme.outline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: warna.withValues(alpha: didapat ? 0.16 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                didapat ? Icons.emoji_events : Icons.lock_outline,
                color: warna,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          badge.nama,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: didapat ? null : scheme.outline,
                              ),
                        ),
                      ),
                      if (badge.poinReward > 0)
                        Text(
                          '+${badge.poinReward}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: didapat
                                    ? Colors.green.shade700
                                    : scheme.outline,
                              ),
                        ),
                    ],
                  ),
                  if (badge.deskripsi != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      badge.deskripsi!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (didapat)
                    Text(
                      badge.didapatPada == null
                          ? 'Sudah didapat'
                          : 'Didapat ${DateFormat('d MMM yyyy', 'id').format(badge.didapatPada!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                    )
                  else ...[
                    AnimatedBar(value: badge.progresPersen / 100, height: 6),
                    const SizedBox(height: 4),
                    Text(
                      'Progres ${badge.progresPersen}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
