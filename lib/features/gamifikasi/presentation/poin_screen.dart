import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../application/gamifikasi_providers.dart';
import '../data/gamifikasi_models.dart';

/// Layar "Poin": ringkasan + riwayat poin, papan peringkat, dan badge.
///
/// Sumber poin yang ditampilkan mengikuti backend: tugas PKG terverifikasi
/// (`character`), kehadiran tanpa keterlambatan (`attendance`), game (`game`),
/// badge, streak, dan penyesuaian manual.
class PoinScreen extends ConsumerStatefulWidget {
  const PoinScreen({super.key});

  @override
  ConsumerState<PoinScreen> createState() => _PoinScreenState();
}

class _PoinScreenState extends ConsumerState<PoinScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Poin & Peringkat'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Ringkasan'),
            Tab(text: 'Riwayat'),
            Tab(text: 'Peringkat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _RingkasanTab(),
          _RiwayatTab(),
          _PeringkatTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────── Ringkasan ───────────────────────────

class _RingkasanTab extends ConsumerWidget {
  const _RingkasanTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gamifikasiRingkasanProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorPanel(
        message: '$e'.replaceFirst('Exception: ', ''),
        onRetry: () => ref.invalidate(gamifikasiRingkasanProvider),
      ),
      data: (r) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(gamifikasiRingkasanProvider);
          ref.invalidate(badgesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _KartuLevel(ringkasan: r),
            const SizedBox(height: 12),
            _GridPoin(poin: r.poin, peringkat: r.peringkat),
            const SizedBox(height: 12),
            _KartuAktivitas(rekap: r.rekap),
            const SizedBox(height: 12),
            _KartuStreak(
              kehadiran: r.streakKehadiran,
              karakter: r.streakKarakter,
              poinPeriode: r.poinPeriodeAktif,
              namaPeriode: r.namaPeriodeAktif,
            ),
            const SizedBox(height: 12),
            const _KartuBadge(),
          ],
        ),
      ),
    );
  }
}

class _KartuLevel extends StatelessWidget {
  const _KartuLevel({required this.ringkasan});

  final GamifikasiRingkasan ringkasan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final level = ringkasan.level;

    return PopIn(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      '${level.angka}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onPrimaryContainer,
                          ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ringkasan.nama,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          level.nama ?? 'Level ${level.angka}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AnimatedCounter(
                        value: ringkasan.poin.total,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                      ),
                      Text('poin',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
              if (ringkasan.isOrtuView) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.visibility_outlined,
                        size: 14, color: scheme.outline),
                    const SizedBox(width: 6),
                    Text(
                      'Tampilan orang tua (hanya memantau)',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.outline),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              AnimatedBar(value: level.progresPersen / 100),
              const SizedBox(height: 6),
              Text(
                level.sudahMaksimal
                    ? 'Level tertinggi tercapai'
                    : 'Butuh ${level.poinKeBerikutnya} poin lagi menuju '
                        '${level.namaBerikutnya ?? 'level ${level.levelBerikutnya}'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridPoin extends StatelessWidget {
  const _GridPoin({required this.poin, required this.peringkat});

  final PoinRincian poin;
  final int peringkat;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      StatCard(
        label: 'Poin karakter (tugas PKG)',
        value: '${poin.karakter}',
        icon: Icons.checklist_rtl_outlined,
        color: Colors.indigo,
      ),
      StatCard(
        label: 'Poin kehadiran',
        value: '${poin.kehadiran}',
        icon: Icons.event_available_outlined,
        color: Colors.teal,
      ),
      StatCard(
        label: 'Bonus & lainnya',
        value: '${poin.bonus}',
        icon: Icons.card_giftcard_outlined,
        color: Colors.orange,
      ),
      StatCard(
        label: 'Peringkat sekolah',
        value: peringkat > 0 ? '#$peringkat' : '-',
        icon: Icons.leaderboard_outlined,
        color: Colors.deepPurple,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        for (var i = 0; i < items.length; i++)
          FadeSlideIn(index: i, child: items[i]),
      ],
    );
  }
}

class _KartuAktivitas extends StatelessWidget {
  const _KartuAktivitas({required this.rekap});

  final RekapSumber rekap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aktivitas berpoin',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Dihitung dari catatan aslinya (tugas & presensi), '
              'bukan dari transaksi poin.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.outline),
            ),
            const SizedBox(height: 12),
            _Baris(
              icon: Icons.verified_outlined,
              warna: Colors.indigo,
              label: 'Tugas PKG terverifikasi',
              nilai: '${rekap.tugasTerverifikasi}',
            ),
            _Baris(
              icon: Icons.schedule_outlined,
              warna: Colors.teal,
              label: 'Hadir tepat waktu',
              nilai: '${rekap.hadirTepatWaktu}',
            ),
            _Baris(
              icon: Icons.running_with_errors_outlined,
              warna: Colors.orange,
              label: 'Terlambat (poin lebih kecil)',
              nilai: '${rekap.terlambat}',
            ),
            _Baris(
              icon: Icons.event_busy_outlined,
              warna: Colors.blueGrey,
              label: 'Izin / sakit',
              nilai: '${rekap.izin + rekap.sakit}',
            ),
            if (rekap.alpha > 0)
              _Baris(
                icon: Icons.cancel_outlined,
                warna: scheme.error,
                label: 'Tanpa keterangan',
                nilai: '${rekap.alpha}',
              ),
          ],
        ),
      ),
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({
    required this.icon,
    required this.warna,
    required this.label,
    required this.nilai,
  });

  final IconData icon;
  final Color warna;
  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: warna),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            nilai,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _KartuStreak extends StatelessWidget {
  const _KartuStreak({
    required this.kehadiran,
    required this.karakter,
    required this.poinPeriode,
    required this.namaPeriode,
  });

  final int kehadiran;
  final int karakter;
  final int poinPeriode;
  final String? namaPeriode;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _Mini(
                icon: Icons.local_fire_department_outlined,
                warna: Colors.deepOrange,
                label: 'Streak hadir',
                nilai: '$kehadiran hari',
              ),
            ),
            Expanded(
              child: _Mini(
                icon: Icons.bolt_outlined,
                warna: Colors.amber,
                label: 'Streak karakter',
                nilai: '$karakter hari',
              ),
            ),
            Expanded(
              child: _Mini(
                icon: Icons.calendar_month_outlined,
                warna: Colors.blue,
                label: namaPeriode ?? 'Periode aktif',
                nilai: '$poinPeriode poin',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({
    required this.icon,
    required this.warna,
    required this.label,
    required this.nilai,
  });

  final IconData icon;
  final Color warna;
  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: warna),
        const SizedBox(height: 6),
        Text(
          nilai,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _KartuBadge extends ConsumerWidget {
  const _KartuBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(badgesProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Badge',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('$e'.replaceFirst('Exception: ', '')),
              data: (list) {
                if (list.isEmpty) {
                  return Text(
                    'Belum ada badge yang dikonfigurasi sekolah.',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                }
                return Column(
                  children: [
                    for (final b in list.take(6)) _BarisBadge(badge: b),
                    if (list.length > 6)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '+${list.length - 6} badge lainnya',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BarisBadge extends StatelessWidget {
  const _BarisBadge({required this.badge});

  final BadgeItem badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final didapat = badge.sudahDidapat;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            didapat ? Icons.emoji_events : Icons.emoji_events_outlined,
            color: didapat ? Colors.amber.shade700 : scheme.outline,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.nama,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            didapat ? FontWeight.w600 : FontWeight.normal,
                      ),
                ),
                if (!didapat) ...[
                  const SizedBox(height: 4),
                  AnimatedBar(value: badge.progresPersen / 100, height: 5),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            didapat ? 'Didapat' : '${badge.progresPersen}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: didapat ? Colors.green.shade700 : scheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Riwayat ───────────────────────────

class _RiwayatTab extends ConsumerStatefulWidget {
  const _RiwayatTab();

  @override
  ConsumerState<_RiwayatTab> createState() => _RiwayatTabState();
}

class _RiwayatTabState extends ConsumerState<_RiwayatTab> {
  final _scroll = ScrollController();

  static const _filter = <({String? kode, String label})>[
    (kode: null, label: 'Semua'),
    (kode: 'character', label: 'Tugas PKG'),
    (kode: 'attendance', label: 'Kehadiran'),
    (kode: 'game', label: 'Game'),
    (kode: 'badge', label: 'Badge'),
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >=
          _scroll.position.maxScrollExtent - 240) {
        ref.read(poinHistoryProvider.notifier).muatLagi();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(poinHistoryProvider);
    final aktif = ref.watch(historySumberProvider);

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              for (final f in _filter)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f.label),
                    selected: aktif == f.kode,
                    onSelected: (_) => ref
                        .read(historySumberProvider.notifier)
                        .pilih(f.kode),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Builder(
            builder: (context) {
              if (state.memuat) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.error != null && state.items.isEmpty) {
                return ErrorPanel(
                  message: state.error!,
                  onRetry: () =>
                      ref.read(poinHistoryProvider.notifier).muatUlang(),
                );
              }
              if (state.kosong) {
                return const _Kosong(
                  ikon: Icons.history_toggle_off_outlined,
                  pesan: 'Belum ada riwayat poin untuk filter ini.',
                );
              }
              return RefreshIndicator(
                onRefresh: () =>
                    ref.read(poinHistoryProvider.notifier).muatUlang(),
                child: ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: state.items.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    if (i == state.items.length) {
                      if (state.memuatLagi) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'Total ${state.meta.total} transaksi',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      );
                    }
                    return _KartuTransaksi(trx: state.items[i]);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _KartuTransaksi extends StatelessWidget {
  const _KartuTransaksi({required this.trx});

  final PoinTransaksi trx;

  static final _fmt = DateFormat('d MMM yyyy • HH:mm', 'id');

  IconData get _ikon => switch (trx.sumber) {
        'character' => Icons.checklist_rtl_outlined,
        'attendance' => Icons.event_available_outlined,
        'game' => Icons.sports_esports_outlined,
        'badge' => Icons.emoji_events_outlined,
        'streak' => Icons.local_fire_department_outlined,
        'perfect_month' => Icons.workspace_premium_outlined,
        _ => Icons.tune_outlined,
      };

  Color _warna(ColorScheme scheme) => switch (trx.sumber) {
        'character' => Colors.indigo,
        'attendance' => Colors.teal,
        'game' => Colors.deepPurple,
        'badge' => Colors.amber.shade800,
        'streak' => Colors.deepOrange,
        _ => scheme.outline,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = _warna(scheme);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_ikon, color: tone, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trx.keterangan?.isNotEmpty == true
                        ? trx.keterangan!
                        : trx.sumberLabel,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    trx.tanggal == null
                        ? trx.sumberLabel
                        : '${trx.sumberLabel} • ${_fmt.format(trx.tanggal!)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.outline),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${trx.bertambah ? '+' : ''}${trx.poin}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: trx.bertambah
                        ? Colors.green.shade700
                        : scheme.error,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Peringkat ───────────────────────────

class _PeringkatTab extends ConsumerWidget {
  const _PeringkatTab();

  static const _periode = <({String kode, String label})>[
    (kode: 'all', label: 'Semua waktu'),
    (kode: 'monthly', label: 'Bulan ini'),
    (kode: 'weekly', label: 'Minggu ini'),
    (kode: 'daily', label: 'Hari ini'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aktif = ref.watch(leaderboardPeriodeProvider);
    final async = ref.watch(leaderboardProvider);

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              for (final p in _periode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p.label),
                    selected: aktif == p.kode,
                    onSelected: (_) => ref
                        .read(leaderboardPeriodeProvider.notifier)
                        .pilih(p.kode),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorPanel(
              message: '$e'.replaceFirst('Exception: ', ''),
              onRetry: () => ref.invalidate(leaderboardProvider),
            ),
            data: (lb) {
              if (lb.entries.isEmpty) {
                return const _Kosong(
                  ikon: Icons.leaderboard_outlined,
                  pesan: 'Belum ada poin pada periode ini.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(leaderboardProvider),
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (!lb.masukDaftar && lb.peringkatSaya > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          child: ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text('Posisi Anda: #${lb.peringkatSaya}'),
                            subtitle: Text('${lb.poinSaya} poin'),
                          ),
                        ),
                      ),
                    for (var i = 0; i < lb.entries.length; i++)
                      FadeSlideIn(
                        index: i,
                        child: _BarisPeringkat(
                          entry: lb.entries[i],
                          periode: lb.periode,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BarisPeringkat extends StatelessWidget {
  const _BarisPeringkat({required this.entry, required this.periode});

  final LeaderboardEntry entry;
  final String periode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final medali = switch (entry.peringkat) {
      1 => Colors.amber.shade700,
      2 => Colors.blueGrey,
      3 => Colors.brown,
      _ => null,
    };
    final poinTampil =
        periode == 'all' ? entry.totalPoin : (entry.poinPeriode ?? 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: entry.isSaya ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: medali != null
                  ? Icon(Icons.emoji_events, color: medali)
                  : Text(
                      '${entry.peringkat}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.nama,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: entry.isSaya
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    [
                      if (entry.kelas != null) entry.kelas!,
                      'Lv ${entry.level}',
                      if (periode != 'all') 'total ${entry.totalPoin}',
                    ].join(' • '),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.outline),
                  ),
                ],
              ),
            ),
            Text(
              '$poinTampil',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong({required this.ikon, required this.pesan});

  final IconData ikon;
  final String pesan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(pesan, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
