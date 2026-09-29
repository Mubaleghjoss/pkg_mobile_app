import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/storage/session_store.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/celebration.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/text_input_dialog.dart';
import '../../auth/application/auth_controller.dart';
import '../../gamifikasi/presentation/streak_card.dart';
import '../data/tugas_pkg.dart';

/// Tanggal yang sedang dilihat (default hari ini).
class TugasTanggalController extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void set(DateTime d) => state = d;
}

final tugasTanggalProvider = NotifierProvider<TugasTanggalController, DateTime>(
  TugasTanggalController.new,
);

final tugasHarianProvider = FutureProvider<TugasHarian>((ref) async {
  final tanggal = ref.watch(tugasTanggalProvider);
  final result = await ref
      .watch(tugasRepositoryProvider)
      .harian(date: DateFormat('yyyy-MM-dd').format(tanggal));
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat tugas');
  }
  return result.data!;
});

class TugasScreen extends ConsumerStatefulWidget {
  const TugasScreen({super.key});

  @override
  ConsumerState<TugasScreen> createState() => _TugasScreenState();
}

class _TugasScreenState extends ConsumerState<TugasScreen> {
  int? _mengirim;

  /// Cegah pemeriksaan ganda untuk data yang sama dalam satu build cycle.
  String? _terakhirDiperiksa;

  /// Bandingkan checklist terverifikasi dengan yang sudah pernah diberitahukan,
  /// lalu munculkan notifikasi lokal untuk yang baru.
  ///
  /// Dipanggil dari `build` (bukan `initState`) karena datanya asinkron; kunci
  /// [_terakhirDiperiksa] memastikan satu payload hanya diperiksa sekali.
  void _cekVerifikasiBaru(TugasHarian data) {
    final isOrtu =
        ref.read(authControllerProvider).session?.actor == AuthActor.ortu;
    // Notifikasi ditujukan ke siswa pemilik tugas, bukan ke akun pemantau.
    if (isOrtu || data.meta.readOnly) return;

    final terverifikasi = <({int id, String nama})>[];
    for (final t in data.items) {
      final c = t.checklist;
      if (c != null && c.isVerified && c.id > 0) {
        terverifikasi.add((id: c.id, nama: t.nama));
      }
    }
    // Daftar kosong tetap dikirim: VerifikasiWatcher memakainya untuk menetapkan
    // garis dasar, supaya verifikasi pertama yang datang nanti tidak dianggap
    // riwayat lama dan ikut ditelan.
    final kunci =
        '${data.meta.date}|'
        '${terverifikasi.map((e) => e.id).join(',')}';
    if (_terakhirDiperiksa == kunci) return;
    _terakhirDiperiksa = kunci;

    // Tidak ditunggu: notifikasi bersifat pelengkap, kegagalannya sudah
    // ditelan di lapisan NotifikasiLokal.
    ref.read(verifikasiWatcherProvider).periksa(terverifikasi);
  }

  Future<void> _kerjakan(TugasPkg t, TugasHarianMeta meta) async {
    if (meta.readOnly) return;

    String? hasilTeks;
    if (t.isTeks) {
      hasilTeks = await _tanyaTeks(t);
      if (hasilTeks == null) return;
    }

    setState(() => _mengirim = t.id);
    final result = await ref
        .read(tugasRepositoryProvider)
        .submit(
          t.id,
          hasilTeks: hasilTeks,
          clickCount: t.isKlik ? t.targetKlik : null,
        );
    if (!mounted) return;
    setState(() => _mengirim = null);

    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Gagal mengirim tugas')),
      );
      return;
    }

    ref.invalidate(tugasHarianProvider);

    final data = ref.read(tugasHarianProvider).value;
    final semuaSelesai = data != null && data.meta.sisa <= 1;
    if (semuaSelesai) {
      await showMateriSelesaiDialog(
        context,
        judul: 'Semua tugas hari ini tuntas',
        nextLabel: 'Siap',
        poin: data.meta.poinTerkumpul + t.poin,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${t.nama}" tercatat. +${t.poin} poin')),
      );
    }
  }

  /// Komentar orang tua pada satu pengerjaan.
  ///
  /// Backend hanya menerima ini dari token ortu (`POST
  /// /tugas-pkg/checklist/{id}/comment`), jadi tombolnya pun hanya muncul di
  /// mode ortu dan hanya untuk tugas yang sudah dikerjakan (checklist ada).
  Future<void> _komentari(TugasPkg t) async {
    final checklistId = t.checklist?.id;
    if (checklistId == null || checklistId <= 0) return;

    final teks = await tanyaTeksDialog(
      context,
      judul: 'Komentar untuk "${t.nama}"',
      pesan: 'Komentar akan terlihat oleh anak dan pamong.',
      labelField: 'Tulis komentar',
      tombol: 'Kirim',
      maxLines: 4,
      maxLength: 500,
      autofocus: true,
    );
    if (teks == null || teks.trim().isEmpty) return;

    setState(() => _mengirim = t.id);
    final result = await ref
        .read(tugasRepositoryProvider)
        .comment(checklistId, teks);
    if (!mounted) return;
    setState(() => _mengirim = null);

    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Gagal mengirim komentar')),
      );
      return;
    }
    ref.invalidate(tugasHarianProvider);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Komentar terkirim')));
  }

  Future<String?> _tanyaTeks(TugasPkg t) async {
    // Dialog + controller-nya dibungkus TextInputDialog agar controller tidak
    // di-dispose saat TextField masih hidup (crash `_dependents.isEmpty`).
    final hasil = await tanyaTeksDialog(
      context,
      judul: t.nama,
      pesan: t.targetTeks,
      labelField: 'Tulis hasilnya',
      tombol: 'Kirim',
      maxLines: 4,
      autofocus: true,
    );
    if (hasil == null || hasil.isEmpty) return null;
    return hasil;
  }

  Future<void> _pilihTanggal(TugasHarianMeta meta) async {
    final now = DateTime.now();
    final min =
        DateTime.tryParse(meta.minDate ?? '') ??
        now.subtract(const Duration(days: 30));
    final max = DateTime.tryParse(meta.maxDate ?? '') ?? now;
    final dipilih = await showDatePicker(
      context: context,
      initialDate: ref.read(tugasTanggalProvider),
      firstDate: min,
      lastDate: max.isBefore(min) ? min : max,
    );
    if (dipilih != null) {
      ref.read(tugasTanggalProvider.notifier).set(dipilih);
    }
  }

  @override
  Widget build(BuildContext context) {
    final harian = ref.watch(tugasHarianProvider);
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final isOrtu = auth.session?.actor == AuthActor.ortu;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(tugasHarianProvider);
        await ref.read(tugasHarianProvider.future);
      },
      child: harian.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorPanel(
          message: '$e'.replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(tugasHarianProvider),
        ),
        data: (data) {
          final meta = data.meta;
          _cekVerifikasiBaru(data);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Kartu streak: pelengkap motivasi, sembunyi sendiri bila data
              // gamifikasi belum tersedia.
              StreakCard(judul: isOrtu ? 'Streak anak' : 'Streak harian'),
              if (!isOrtu)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Card(
                    color: theme.colorScheme.primaryContainer,
                    child: ListTile(
                      leading: Icon(
                        Icons.face_retouching_natural_outlined,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      title: const Text('Presensi wajah'),
                      subtitle: const Text(
                        'Scan cepat dengan GPS sesuai radius lokasi admin.',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                      onTap: () => context.push('/presensi-wajah'),
                    ),
                  ),
                ),
              FadeSlideIn(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _labelTanggal(meta.date),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Pilih tanggal',
                              onPressed: () => _pilihTanggal(meta),
                              icon: const Icon(Icons.calendar_month_outlined),
                            ),
                          ],
                        ),
                        Text(
                          '${meta.selesai} dari ${meta.total} tugas selesai · '
                          '${meta.poinTerkumpul} poin',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        AnimatedBar(value: meta.progress),
                        if (isOrtu || meta.readOnly) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.visibility_outlined, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Mode orang tua: hanya memantau. Tugas '
                                    'dikerjakan oleh siswa.',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (data.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: ErrorPanel(
                    message: 'Tidak ada tugas untuk tanggal ini.',
                  ),
                ),
              ...List.generate(data.items.length, (i) {
                final t = data.items[i];
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: FadeSlideIn(
                    index: i,
                    child: _TugasCard(
                      tugas: t,
                      readOnly: meta.readOnly,
                      isOrtu: isOrtu,
                      mengirim: _mengirim == t.id,
                      onKerjakan: () => _kerjakan(t, meta),
                      onKomentar: () => _komentari(t),
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

  String _labelTanggal(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final hariIni = DateTime.now();
    final sama =
        d.year == hariIni.year &&
        d.month == hariIni.month &&
        d.day == hariIni.day;
    final teks = DateFormat('EEEE, d MMMM yyyy', 'id').format(d);
    return sama ? 'Hari ini · $teks' : teks;
  }
}

class _TugasCard extends StatelessWidget {
  const _TugasCard({
    required this.tugas,
    required this.readOnly,
    required this.isOrtu,
    required this.mengirim,
    required this.onKerjakan,
    required this.onKomentar,
  });

  final TugasPkg tugas;
  final bool readOnly;
  final bool isOrtu;
  final bool mengirim;
  final VoidCallback onKerjakan;
  final VoidCallback onKomentar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selesai = tugas.sudahDikerjakan;
    final terverifikasi = tugas.checklist?.isVerified ?? false;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selesai
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: Icon(
                    selesai ? Icons.check : _ikonJenis(tugas.jenisPenyelesaian),
                    size: 18,
                    color: selesai
                        ? Colors.white
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tugas.nama,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${tugas.kategoriLabel ?? tugas.kategori ?? 'Umum'}'
                        ' · ${tugas.poin} poin',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (terverifikasi)
                  Tooltip(
                    message: 'Sudah diverifikasi pamong',
                    child: Icon(
                      Icons.verified,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
            if (tugas.deskripsi != null) ...[
              const SizedBox(height: 8),
              Text(tugas.deskripsi!, style: theme.textTheme.bodySmall),
            ],
            if (tugas.checklist?.hasilTeks != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tugas.checklist!.hasilTeks!,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
            if ((tugas.checklist?.komentarOrtu ?? const []).isNotEmpty) ...[
              const SizedBox(height: 10),
              ...tugas.checklist!.komentarOrtu.map(
                (k) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
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
            if (tugas.blockedByWebProof) ...[
              const SizedBox(height: 10),
              Text(
                'Tugas ini wajib melampirkan bukti foto/suara — kerjakan lewat '
                'web karena unggah bukti belum tersedia di aplikasi.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (!readOnly && !selesai && !tugas.blockedByWebProof) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: mengirim ? null : onKerjakan,
                  icon: mengirim
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_ikonJenis(tugas.jenisPenyelesaian), size: 18),
                  label: Text(_labelAksi(tugas)),
                ),
              ),
            ],
            if (selesai) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    terverifikasi
                        ? 'Selesai & terverifikasi'
                        : 'Selesai, menunggu verifikasi pamong',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
            // Komentar hanya boleh dikirim akun ortu, dan hanya jika sudah ada
            // baris checklist di server (id > 0) — tanpa itu endpoint 404.
            if (isOrtu && (tugas.checklist?.id ?? 0) > 0) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: mengirim ? null : onKomentar,
                  icon: mengirim
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_comment_outlined, size: 18),
                  label: const Text('Beri komentar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static IconData _ikonJenis(String jenis) => switch (jenis) {
    'teks' => Icons.edit_note_outlined,
    'klik' => Icons.touch_app_outlined,
    _ => Icons.check_box_outlined,
  };

  static String _labelAksi(TugasPkg t) => switch (t.jenisPenyelesaian) {
    'teks' => 'Tulis & kirim',
    'klik' => 'Tandai ${t.targetKlik ?? 1}x selesai',
    _ => 'Tandai selesai',
  };
}
