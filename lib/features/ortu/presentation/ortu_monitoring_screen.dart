import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../data/ortu_models.dart';
import '../data/ortu_repository.dart';

final ortuRingkasanProvider = FutureProvider<OrtuRingkasan>((ref) async {
  final r = await ref.watch(ortuRepositoryProvider).ringkasan();
  if (!r.ok || r.data == null) {
    throw Exception(r.error ?? 'Gagal memuat ringkasan');
  }
  return r.data!;
});

final ortuTugasProvider = FutureProvider<OrtuTugasHalaman>((ref) async {
  final r = await ref.watch(ortuRepositoryProvider).tugas(perPage: 30);
  if (!r.ok || r.data == null) {
    throw Exception(r.error ?? 'Gagal memuat tugas anak');
  }
  return r.data!;
});

final ortuPresensiProvider = FutureProvider<OrtuPresensiHalaman>((ref) async {
  final r = await ref.watch(ortuRepositoryProvider).presensi(perPage: 30);
  if (!r.ok || r.data == null) {
    throw Exception(r.error ?? 'Gagal memuat presensi anak');
  }
  return r.data!;
});

/// Dasbor monitoring orang tua: satu layar, tiga bagian (tugas, presensi,
/// Quran) yang semuanya read-only. Orang tua tidak bisa mengerjakan tugas —
/// backend menolak dengan `ORTU_READ_ONLY`, jadi tidak ada tombol aksi di sini.
class OrtuMonitoringScreen extends ConsumerWidget {
  const OrtuMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ortuRingkasanProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(ortuRingkasanProvider);
        ref.invalidate(ortuTugasProvider);
        ref.invalidate(ortuPresensiProvider);
      },
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: 80),
            ErrorPanel(
              message: '$e'.replaceFirst('Exception: ', ''),
              onRetry: () => ref.invalidate(ortuRingkasanProvider),
            ),
          ],
        ),
        data: (r) => ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            FadeSlideIn(child: _kartuAnak(context, r.siswa)),
            const SizedBox(height: 12),
            FadeSlideIn(index: 1, child: _bagianTugas(context, r.tugas)),
            const SizedBox(height: 12),
            FadeSlideIn(index: 2, child: _bagianQuran(context, r.quran)),
            const SizedBox(height: 12),
            FadeSlideIn(index: 3, child: _bagianPresensi(context, r.presensi)),
            const SizedBox(height: 12),
            FadeSlideIn(index: 4, child: _daftarTugasTerbaru(context, ref)),
            const SizedBox(height: 12),
            FadeSlideIn(index: 5, child: _riwayatPresensi(context, ref)),
          ],
        ),
      ),
    );
  }

  Widget _kartuAnak(BuildContext context, OrtuSiswaInfo s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              child: Text(
                s.nama.isEmpty ? '?' : s.nama.characters.first.toUpperCase(),
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.nama,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'NIS ${s.nis}${s.kelas == null ? '' : ' • ${s.kelas}'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Mode orang tua — hanya memantau',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bagianTugas(BuildContext context, OrtuTugasRekap t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _judul(context, 'Tugas PKG', Icons.checklist_outlined),
            const SizedBox(height: 12),
            AnimatedBar(value: t.persentase / 100),
            const SizedBox(height: 8),
            Text(
              '${t.terverifikasi} dari ${t.totalTugasAktif} tugas aktif '
              'terverifikasi (${t.persentase.toStringAsFixed(1)}%)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _mini(context, 'Terverifikasi', '${t.terverifikasi}',
                    Colors.green),
                _mini(context, 'Menunggu', '${t.menungguVerifikasi}',
                    Colors.orange),
                _mini(context, 'Poin', '${t.poinTerverifikasi}',
                    Theme.of(context).colorScheme.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bagianQuran(BuildContext context, OrtuQuranRekap q) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _judul(context, 'Bacaan Al-Quran', Icons.menu_book_outlined),
            const SizedBox(height: 12),
            Row(
              children: [
                _mini(context, 'Terverifikasi', '${q.terverifikasiTotal}',
                    Colors.green),
                _mini(context, 'Bulan ini', '${q.terverifikasiBulanIni}',
                    Theme.of(context).colorScheme.primary),
                _mini(context, 'Menunggu', '${q.menungguVerifikasi}',
                    Colors.orange),
                if (q.ditolak > 0)
                  _mini(context, 'Ditolak', '${q.ditolak}', Colors.red),
              ],
            ),
            if (q.terakhirMembaca != null) ...[
              const SizedBox(height: 10),
              Text('Terakhir membaca: ${q.terakhirMembaca}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bagianPresensi(BuildContext context, PresensiTotals p) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _judul(context, 'Kehadiran', Icons.fact_check_outlined),
            const SizedBox(height: 12),
            AnimatedBar(value: p.persentaseKehadiran / 100),
            const SizedBox(height: 8),
            Text(
              '${p.persentaseKehadiran.toStringAsFixed(1)}% kehadiran '
              'dari ${p.total} catatan',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            // Terlambat tetap dihitung hadir (anak memang datang), tetapi
            // angkanya ditampilkan eksplisit supaya 100% tidak menyamarkan
            // keterlambatan.
            if (p.adaKeterlambatan) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 14,
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Termasuk ${p.jumlahTerlambat} kali terlambat · '
                      'tepat waktu ${p.persentaseTepatWaktu.toStringAsFixed(1)}%',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _pil('Hadir ${p.hadir}', Colors.green),
                _pil('Terlambat ${p.terlambat}', Colors.orange),
                _pil('Izin ${p.izin}', Colors.blue),
                _pil('Sakit ${p.sakit}', Colors.purple),
                _pil('Alpha ${p.alpha}', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _daftarTugasTerbaru(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ortuTugasProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _judul(context, 'Tugas terbaru anak', Icons.history),
            const SizedBox(height: 8),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('$e'.replaceFirst('Exception: ', '')),
              data: (h) {
                final items = h.page.items.take(8).toList(growable: false);
                if (items.isEmpty) {
                  return const Text('Belum ada tugas yang dikerjakan.');
                }
                return Column(
                  children: items
                      .map((t) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              t.isVerified
                                  ? Icons.verified
                                  : Icons.hourglass_empty,
                              color:
                                  t.isVerified ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                            title: Text(t.karakterNama),
                            subtitle: Text(
                              [
                                if (t.checkedAt != null)
                                  DateFormat('d MMM HH:mm', 'id')
                                      .format(t.checkedAt!),
                                if (t.isVerified && t.verifiedBy != null)
                                  'oleh ${t.verifiedBy}'
                                else if (!t.isVerified)
                                  'menunggu verifikasi pamong',
                                if (t.notes != null && t.notes!.isNotEmpty)
                                  '“${t.notes}”',
                              ].join(' • '),
                            ),
                            trailing: Text('${t.poin}'),
                          ))
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _riwayatPresensi(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ortuPresensiProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _judul(context, 'Riwayat kehadiran', Icons.calendar_month_outlined),
            const SizedBox(height: 8),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('$e'.replaceFirst('Exception: ', '')),
              data: (h) {
                if (h.page.items.isEmpty) {
                  return const Text('Belum ada catatan presensi.');
                }
                return Column(
                  children: [
                    if (h.bulanan.isNotEmpty) ...[
                      ...h.bulanan.take(3).map(
                            (b) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Expanded(child: Text(b.periode)),
                                  Text(
                                    'H${b.totals.hadir} T${b.totals.terlambat} '
                                    'I${b.totals.izin} S${b.totals.sakit} '
                                    'A${b.totals.alpha}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      const Divider(),
                    ],
                    ...h.page.items.take(8).map(
                          (p) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              p.isVerified
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 20,
                              color: p.isVerified ? Colors.green : null,
                            ),
                            title: Text(
                              p.tanggal == null
                                  ? '-'
                                  : DateFormat('EEEE, d MMM yyyy', 'id')
                                      .format(p.tanggal!),
                            ),
                            subtitle: Text(
                              [
                                p.status,
                                if (p.jamMasuk != null)
                                  'masuk ${DateFormat('HH:mm').format(p.jamMasuk!)}',
                                if (p.jamKeluar != null)
                                  'keluar ${DateFormat('HH:mm').format(p.jamKeluar!)}',
                                if (p.keterangan != null &&
                                    p.keterangan!.isNotEmpty)
                                  p.keterangan!,
                              ].join(' • '),
                            ),
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

  Widget _judul(BuildContext context, String teks, IconData icon) => Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            teks,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      );

  Widget _mini(BuildContext context, String label, String nilai, Color warna) =>
      Expanded(
        child: Column(
          children: [
            Text(
              nilai,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: warna, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _pil(String teks, Color warna) => Chip(
        visualDensity: VisualDensity.compact,
        label: Text(teks),
        side: BorderSide(color: warna.withValues(alpha: 0.5)),
      );
}
