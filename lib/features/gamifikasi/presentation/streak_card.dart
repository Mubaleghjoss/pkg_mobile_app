import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/animations.dart';
import '../application/gamifikasi_providers.dart';

/// Kartu streak harian untuk beranda.
///
/// Sumber datanya `GET /gamifikasi/ringkasan` (`streak.kehadiran` dan
/// `streak.karakter`) — endpoint yang sama dipakai layar Poin, jadi kartu ini
/// tidak menambah panggilan jaringan baru saat keduanya dibuka.
///
/// Kartu sengaja *diam* saat data gagal/masih dimuat: streak adalah pelengkap
/// motivasi, bukan informasi utama beranda, sehingga error-nya tidak boleh
/// menutupi daftar tugas.
class StreakCard extends ConsumerWidget {
  const StreakCard({super.key, this.judul = 'Streak harian'});

  final String judul;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ringkasan = ref.watch(gamifikasiRingkasanProvider);
    final data = ringkasan.asData?.value;
    if (data == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final hadir = data.streakKehadiran;
    final karakter = data.streakKarakter;

    // Tanpa streak sama sekali: tampilkan dorongan singkat, bukan angka nol
    // yang terasa seperti hukuman.
    final belumMulai = hadir <= 0 && karakter <= 0;

    return FadeSlideIn(
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: belumMulai
                        ? theme.colorScheme.outline
                        : Colors.deepOrange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      judul,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (data.totalBadge > 0)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.emoji_events_outlined, size: 16),
                      label: Text('${data.totalBadge} badge'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                belumMulai
                    ? 'Mulai hari ini: hadir dan kerjakan tugas untuk '
                        'menyalakan streak.'
                    : 'Jaga jangan sampai putus.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StreakPetak(
                      label: 'Kehadiran',
                      hari: hadir,
                      icon: Icons.event_available_outlined,
                      warna: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StreakPetak(
                      label: 'Karakter',
                      hari: karakter,
                      icon: Icons.auto_awesome_outlined,
                      warna: Colors.indigo,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakPetak extends StatelessWidget {
  const _StreakPetak({
    required this.label,
    required this.hari,
    required this.icon,
    required this.warna,
  });

  final String label;
  final int hari;
  final IconData icon;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aktif = hari > 0;
    final dasar = aktif ? warna : theme.colorScheme.outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: dasar.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dasar.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: dasar),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$hari',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: dasar,
                ),
              ),
              const SizedBox(width: 4),
              Text('hari', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          // Tujuh petak = satu minggu; petak menyala mengikuti panjang streak.
          Row(
            children: List.generate(7, (i) {
              final nyala = i < hari.clamp(0, 7);
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: i == 6 ? 0 : 3),
                  decoration: BoxDecoration(
                    color: nyala ? dasar : dasar.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
